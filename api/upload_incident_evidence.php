<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once "../config/db_connection.php";

function send_response($success, $message, $data = []) {
    echo json_encode(["success" => $success, "message" => $message, "data" => $data]);
    exit;
}

function table_exists($connection, $table) {
    $table = mysqli_real_escape_string($connection, $table);
    $result = mysqli_query($connection, "SHOW TABLES LIKE '$table'");
    return $result && mysqli_num_rows($result) > 0;
}

function column_exists($connection, $table, $column) {
    $table = mysqli_real_escape_string($connection, $table);
    $column = mysqli_real_escape_string($connection, $column);
    $result = mysqli_query($connection, "SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $result && mysqli_num_rows($result) > 0;
}

function public_file_url($relative_path) {
    $relative_path = trim((string)$relative_path);
    if ($relative_path === '') return '';

    if (preg_match('/^https?:\/\//i', $relative_path)) {
        return $relative_path;
    }

    $relative_path = str_replace('\\', '/', $relative_path);
    $relative_path = ltrim($relative_path, '/');

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    if (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') $scheme = 'https';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';

    $base_path = dirname(dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    $base_path = rtrim(str_replace('\\', '/', $base_path), '/');

    if (stripos($relative_path, 'public/') === 0) {
        return $scheme . '://' . $host . $base_path . '/' . $relative_path;
    }
    return $scheme . '://' . $host . $base_path . '/public/' . $relative_path;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_response(false, "Invalid request method. Use POST.");
}

$incident_report_id = (int)($_POST['incident_report_id'] ?? 0);
$uploaded_by = (int)($_POST['uploaded_by'] ?? 0);

if ($incident_report_id <= 0 || $uploaded_by <= 0) {
    send_response(false, "Incident ID and uploaded by are required.");
}

if (!isset($_FILES['evidence_files'])) {
    send_response(true, "No evidence uploaded.", []);
}

$check = mysqli_prepare($connection, "SELECT id FROM users WHERE id = ?");
mysqli_stmt_bind_param($check, "i", $uploaded_by);
mysqli_stmt_execute($check);
$user_exists = mysqli_stmt_get_result($check);
if (!$user_exists || mysqli_num_rows($user_exists) === 0) {
    send_response(false, "Invalid user.");
}
mysqli_stmt_close($check);

$check2 = mysqli_prepare($connection, "SELECT id FROM incident_reports WHERE id = ?");
mysqli_stmt_bind_param($check2, "i", $incident_report_id);
mysqli_stmt_execute($check2);
$report_exists = mysqli_stmt_get_result($check2);
if (!$report_exists || mysqli_num_rows($report_exists) === 0) {
    send_response(false, "Incident report not found.");
}
mysqli_stmt_close($check2);

// FIX: only accept known file types. Unknown extensions are rejected instead of
// being silently saved and labelled as 'photo'.
$allowed_types = [
    'jpg' => 'photo', 'jpeg' => 'photo', 'png' => 'photo', 'gif' => 'photo', 'webp' => 'photo', 'heic' => 'photo',
    'mp4' => 'video', 'mov' => 'video', 'avi' => 'video', 'mkv' => 'video', 'webm' => 'video', '3gp' => 'video',
];
$max_photo_bytes = UPLOAD_MAX_PHOTO_MB * 1024 * 1024;
$max_video_bytes = UPLOAD_MAX_VIDEO_MB * 1024 * 1024;
$max_photo_count = UPLOAD_MAX_PHOTOS;
$max_video_count = UPLOAD_MAX_VIDEOS;

if (!table_exists($connection, 'incident_attachments')) {
    mysqli_query($connection, "
        CREATE TABLE IF NOT EXISTS incident_attachments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            incident_report_id INT NOT NULL,
            uploaded_by INT NULL,
            file_name VARCHAR(255) NULL,
            file_path TEXT NOT NULL,
            file_type VARCHAR(50) NULL,
            file_size INT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ");
}

$attachment_incident_column = column_exists($connection, 'incident_attachments', 'incident_report_id')
    ? 'incident_report_id'
    : (column_exists($connection, 'incident_attachments', 'incident_id') ? 'incident_id' : 'incident_report_id');

$has_uploaded_by = column_exists($connection, 'incident_attachments', 'uploaded_by');
$has_file_name = column_exists($connection, 'incident_attachments', 'file_name');
$has_file_type = column_exists($connection, 'incident_attachments', 'file_type');
$has_file_size = column_exists($connection, 'incident_attachments', 'file_size');
$has_created_at = column_exists($connection, 'incident_attachments', 'created_at');
$has_uploaded_at = column_exists($connection, 'incident_attachments', 'uploaded_at');

$base_dir = "../public/uploads/incidents/report_" . $incident_report_id;
if (!is_dir($base_dir)) {
    // FIX: 0755 instead of world-writable 0777.
    if (!mkdir($base_dir, 0755, true) && !is_dir($base_dir)) {
        send_response(false, "Failed to create upload folder.");
    }
}

$finfo = function_exists('finfo_open') ? finfo_open(FILEINFO_MIME_TYPE) : false;

$uploaded = [];
$rejected = [];
$files = $_FILES['evidence_files'];
$count = is_array($files['name']) ? count($files['name']) : 0;
$photo_count = 0;
$video_count = 0;

for ($i = 0; $i < $count; $i++) {
    if ($files['error'][$i] !== UPLOAD_ERR_OK) {
        $rejected[] = ["file_name" => basename($files['name'][$i] ?? 'unknown'), "reason" => "Upload error."];
        continue;
    }

    $original = basename($files['name'][$i]);
    $safe = preg_replace('/[^A-Za-z0-9._-]/', '_', $original);
    $ext = strtolower(pathinfo($safe, PATHINFO_EXTENSION));
    $size = (int)$files['size'][$i];

    if (!isset($allowed_types[$ext])) {
        $rejected[] = ["file_name" => $original, "reason" => "File type not allowed."];
        continue;
    }
    $type = $allowed_types[$ext];

    if ($type === 'photo') {
        $max_bytes = $max_photo_bytes;
        if ($photo_count >= $max_photo_count) {
            $rejected[] = ["file_name" => $original, "reason" => "Maximum 5 photos per report."];
            continue;
        }
    } else {
        $max_bytes = $max_video_bytes;
        if ($video_count >= $max_video_count) {
            $rejected[] = ["file_name" => $original, "reason" => "Maximum 2 videos per report."];
            continue;
        }
    }

    if ($size <= 0 || $size > $max_bytes) {
        $rejected[] = ["file_name" => $original, "reason" => "File is too large (max " . ($type === 'photo' ? '15 MB' : '50 MB') . ")."];
        continue;
    }

    // FIX: confirm the real content type, not just the extension.
    if ($finfo) {
        $mime = finfo_file($finfo, $files['tmp_name'][$i]);
        $mime_ok = ($type === 'photo' && strpos((string)$mime, 'image/') === 0)
                || ($type === 'video' && strpos((string)$mime, 'video/') === 0);
        if (!$mime_ok) {
            $rejected[] = ["file_name" => $original, "reason" => "File contents do not match its type."];
            continue;
        }
    }

    // FIX: unpredictable filename (avoids guessable URLs and overwrites).
    $filename = $type . '_' . date('YmdHis') . '_' . bin2hex(random_bytes(6)) . '.' . $ext;
    $target = $base_dir . '/' . $filename;

    if (move_uploaded_file($files['tmp_name'][$i], $target)) {
        @chmod($target, 0644);
        $db_path = 'uploads/incidents/report_' . $incident_report_id . '/' . $filename;

        $columns = ["`$attachment_incident_column`", "`file_path`"];
        $placeholders = ["?", "?"];
        $types = "is";
        $values = [$incident_report_id, $db_path];

        if ($has_uploaded_by) { $columns[] = "`uploaded_by`"; $placeholders[] = "?"; $types .= "i"; $values[] = $uploaded_by; }
        if ($has_file_name) { $columns[] = "`file_name`"; $placeholders[] = "?"; $types .= "s"; $values[] = $original; }
        if ($has_file_type) { $columns[] = "`file_type`"; $placeholders[] = "?"; $types .= "s"; $values[] = $type; }
        if ($has_file_size) { $columns[] = "`file_size`"; $placeholders[] = "?"; $types .= "i"; $values[] = $size; }
        if ($has_created_at) { $columns[] = "`created_at`"; $placeholders[] = "NOW()"; }
        if (!$has_created_at && $has_uploaded_at) { $columns[] = "`uploaded_at`"; $placeholders[] = "NOW()"; }

        $query = "INSERT INTO incident_attachments (" . implode(', ', $columns) . ") VALUES (" . implode(', ', $placeholders) . ")";
        $stmt = mysqli_prepare($connection, $query);
        if ($stmt) {
            mysqli_stmt_bind_param($stmt, $types, ...$values);
            mysqli_stmt_execute($stmt);
        }

        $uploaded[] = [
            "file_name" => $original,
            "file_path" => $db_path,
            "file_url" => public_file_url($db_path),
            "file_type" => $type,
            "file_size" => $size
        ];
        if ($type === 'photo') { $photo_count++; } else { $video_count++; }
    } else {
        $rejected[] = ["file_name" => $original, "reason" => "Could not save file."];
    }
}

if ($finfo) finfo_close($finfo);

send_response(true, "Evidence upload completed.", ["uploaded" => $uploaded, "rejected" => $rejected]);
?>
