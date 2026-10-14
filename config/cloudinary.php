<?php
// Uploads one file to Cloudinary, returns its secure URL.
// Returns '' on failure -> the caller's EXISTING error path handles it.
// Resolution order for the key:
//   1) CLOUDINARY_URL env var (Railway)
//   2) config/cloudinary.local.php (untracked, local dev)
//   3) neither -> local-disk fallback = today's exact behavior

function cloudinary_key() {
    $url = getenv('CLOUDINARY_URL');
    if (!$url && is_file(__DIR__ . '/cloudinary.local.php')) {
        $url = trim((string) require __DIR__ . '/cloudinary.local.php');
    }
    return trim((string) $url);
}

function cloudinary_upload($tmp_path, $relative_folder, $filename) {
    $cloudinary_url = cloudinary_key();

    if (!$cloudinary_url) {
        // Local fallback: today's behavior, moved here.
        $abs_dir = __DIR__ . '/../public/uploads/' . $relative_folder;
        if (!is_dir($abs_dir)) @mkdir($abs_dir, 0755, true);
        $abs = $abs_dir . '/' . $filename;
        $ok  = is_uploaded_file($tmp_path)
             ? move_uploaded_file($tmp_path, $abs)
             : rename($tmp_path, $abs);
        return $ok ? 'uploads/' . $relative_folder . '/' . $filename : '';
    }

    // Cloudinary: cloudinary://KEY:SECRET@CLOUD_NAME
    $p      = parse_url($cloudinary_url);
    $cloud  = $p['host'] ?? '';
    $key    = $p['user'] ?? '';
    $secret = $p['pass'] ?? '';
    if (!$cloud || !$key || !$secret) return '';

    // public_id omits the extension: Cloudinary derives the format and appends
    // it, so the stored URL stays clean (name.jpg, not name.jpg.jpg).
    $public_id = $relative_folder . '/' . pathinfo($filename, PATHINFO_FILENAME);
    $timestamp = time();
    $signature = sha1('public_id=' . $public_id . '&timestamp=' . $timestamp . $secret);

    $ch = curl_init('https://api.cloudinary.com/v1_1/' . $cloud . '/auto/upload');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_TIMEOUT        => 120,
        CURLOPT_POSTFIELDS     => [
            'file'          => new CURLFile($tmp_path),
            'api_key'       => $key,
            'timestamp'     => $timestamp,
            'signature'     => $signature,
            'public_id'     => $public_id,
        ],
    ]);
    $res  = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $json = json_decode((string) $res, true);
    return ($code === 200 && !empty($json['secure_url'])) ? $json['secure_url'] : '';
}
