# Cloudinary Upload Hosting — Execution Plan

**Status:** PLANNED · LOCKED 2026-10-07 · Option 1
**Goal:** Host incident evidence (photos/videos) on Cloudinary instead of local disk, with a local-disk fallback so XAMPP dev works with zero config.
**Scope decision:** 1 new file + ~5 changed lines in each of the 3 upload files. Zero changes to readers, Flutter, validation, or DB schema.
**Upload limits decision:** set to **1 photo / 1 video** as part of implementation (Step 3).
**Backfill of old rows:** DEFERRED (see Deferred section).

---

## 0. How to activate (do this FIRST)

You provide the key in chat (format below), and it gets wired to **both** environments:

```
cloudinary://API_KEY:API_SECRET@CLOUD_NAME
```

1. **Local (XAMPP):** create `config/cloudinary.local.php` containing exactly:
   ```php
   <?php return 'cloudinary://API_KEY:API_SECRET@CLOUD_NAME';
   ```
2. **Git safety:** create/append a root `.gitignore` with:
   ```
   config/cloudinary.local.php
   ```
   (The repo currently has NO root .gitignore — without this the key WILL be committed.)
3. **Railway (prod):** Dashboard → your service → **Variables** → add `CLOUDINARY_URL` = the same string. Never commit it.

Without any key present, the helper falls back to the existing local-disk behavior — code is safe to commit before the key exists.

---

## 1. CREATE `config/cloudinary.php` (new file)

```php
<?php
// Uploads one file to Cloudinary, returns its secure URL.
// Returns '' on failure → the caller's EXISTING error path handles it.
// Resolution order for the key:
//   1) CLOUDINARY_URL env var (Railway)
//   2) config/cloudinary.local.php (untracked, local dev)
//   3) neither → local-disk fallback = today's exact behavior

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
        // ── Local fallback: today's behavior, moved here ──
        $abs_dir = __DIR__ . '/../public/uploads/' . $relative_folder;
        if (!is_dir($abs_dir)) @mkdir($abs_dir, 0755, true);
        $abs = $abs_dir . '/' . $filename;
        $ok  = is_uploaded_file($tmp_path)
             ? move_uploaded_file($tmp_path, $abs)
             : rename($tmp_path, $abs);
        return $ok ? 'uploads/' . $relative_folder . '/' . $filename : '';
    }

    // ── Cloudinary: cloudinary://KEY:SECRET@CLOUD_NAME ──
    $p      = parse_url($cloudinary_url);
    $cloud  = $p['host'] ?? '';
    $key    = $p['user'] ?? '';
    $secret = $p['pass'] ?? '';
    if (!$cloud || !$key || !$secret) return '';

    // public_id keeps folder + filename → Flutter's basename dedup
    // (offline_report_sync.dart:386-387) still matches.
    $public_id = $relative_folder . '/' . $filename;
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
            'overwrite'     => 'false',
            'resource_type' => 'auto',
        ],
    ]);
    $res  = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $json = json_decode((string) $res, true);
    return ($code === 200 && !empty($json['secure_url'])) ? $json['secure_url'] : '';
}
```

---

## 2. THE 3 SWAPS (all validation / INSERT / response blocks stay UNCHANGED)

### ① `app/reports/save-report.php`
- **Add at top** (after the existing requires, near line 6):
  ```php
  require_once __DIR__ . "/../../config/cloudinary.php";
  ```
- **DELETE folder preamble** (:236-241):
  ```php
  $V_folder = __DIR__ . "/../../public/uploads/incidents/report_" . $V_incident_id . "/";
  $V_db_folder = "uploads/incidents/report_" . $V_incident_id . "/";
  if (!is_dir($V_folder)) { mkdir($V_folder, 0755, true); }
  ```
- **REPLACE** (:288-291):
  ```php
  // BEFORE
  $V_target_path = $V_folder . $V_new_name;
  $V_db_path = $V_db_folder . $V_new_name;
  if (move_uploaded_file($V_tmp_name, $V_target_path)) {
  // AFTER
  $V_db_path = cloudinary_upload($V_tmp_name, 'incidents/report_' . $V_incident_id, $V_new_name);
  if ($V_db_path !== '') {
  ```
- Everything below (INSERT :292-299, counters, errors) **unchanged**.

### ② `app/reports/update-report.php`
- **Add at top** (near line 6): `require_once __DIR__ . "/../../config/cloudinary.php";`
- **DELETE folder preamble** (:279-284, mirror of ①).
- **REPLACE** (move at :334, same shape as ①):
  ```php
  $V_db_path = cloudinary_upload($V_tmp_name, 'incidents/report_' . $V_incident_id, $V_new_name);
  if ($V_db_path !== '') {
  ```
- INSERT (:335+) **unchanged**.

### ③ `api/upload_incident_evidence.php`
- **Add at top** (near line 12): `require_once __DIR__ . '/../config/cloudinary.php';`
- **DELETE** mkdir block (:126-132, `$base_dir` + `mkdir` + FIX comment).
- **REPLACE** (:192-196):
  ```php
  // BEFORE
  $target = $base_dir . '/' . $filename;
  if (move_uploaded_file($files['tmp_name'][$i], $target)) {
      @chmod($target, 0644);
      $db_path = 'uploads/incidents/report_' . $incident_report_id . '/' . $filename;
  // AFTER
  $db_path = cloudinary_upload($files['tmp_name'][$i], 'incidents/report_' . $incident_report_id, $filename);
  if ($db_path !== '') {
  ```
- INSERT (:198-215) and `$uploaded[]` (:217-223) **unchanged** — `public_file_url()` passes `https://` URLs through untouched (verified :36-38).

---

## 3. LIMITS → 1 photo / 1 video

In `config/app_config.php`:
```php
const UPLOAD_MAX_PHOTOS   = 1;   // was 5  (line 20)
const UPLOAD_MAX_VIDEOS   = 1;   // was 2  (line 21)
```
`UPLOAD_MAX_PHOTO_MB = 15` / `UPLOAD_MAX_VIDEO_MB = 50` **stay as-is**.

Also fix two **hardcoded** messages in `api/upload_incident_evidence.php` (counts use the constants, strings don't):
- :163 `"Maximum 5 photos per report."` → `"Maximum " . UPLOAD_MAX_PHOTOS . " photos per report."`
- :169 `"Maximum 2 videos per report."` → `"Maximum " . UPLOAD_MAX_VIDEOS . " videos per report."`

Effect (automatic everywhere): web form labels (`create-incident-report.php:282`, `edit-incident-report.php:364`), web validation (`save-report.php:234/266`, `update-report.php:277/311`), and API counts all read these constants.

---

## 4. DO NOT TOUCH (verified compatible)

| Area | Why it already works |
|---|---|
| `functions.php::render_incident_attachments()` :596-606 | echoes `file_path` directly → absolute URL renders as-is |
| `api/get_report_attachments.php::public_file_url()` :41-43 | explicit pass-through for `http(s)://` |
| `api/upload_incident_evidence.php::public_file_url()` :36-38 | same pass-through |
| Flutter `report_details_sheet.dart` :690/:762/:788 | consumes API `file_url` |
| Flutter `offline_report_sync.dart` :386-387 | dedups by basename — kept by `public_id` = folder + filename |
| Validation (ext/size/count/mime) | lives in the 3 call sites, untouched |
| DB schema | `file_path` TEXT holds both relative paths and absolute URLs |

---

## 5. DEPLOY CHECKLIST (Railway)

- [ ] `ext-curl` available (standard in Railway PHP images — verify `phpinfo` or a test upload)
- [ ] `php.ini`: `upload_max_filesize` / `post_max_size` ≥ **50 MB** (video limit unchanged)
- [ ] Variable `CLOUDINARY_URL` set (Step 0)
- [ ] Root `.gitignore` contains `config/cloudinary.local.php`
- [ ] `config/cloudinary.local.php` exists locally, is untracked (`git status` must not list it)

---

## 6. TEST CHECKLIST (1 photo + 1 video)

1. **Web create** — new report, attach **1 photo + 1 video** → submit.
   - [ ] No upload warnings banner
   - [ ] `incident_attachments.file_path` is a `https://res.cloudinary.com/...` URL
   - [ ] Photo thumbnail + video render on the report detail / incident list
2. **Web edit** — add **1 photo** to an existing report → renders.
3. **Flutter offline** — airplane mode, file 1 photo + 1 video, submit; reconnect.
   - [ ] Evidence syncs, appears in report details
   - [ ] **Basename check:** Cloudinary URL ends with the generated filename (dedup depends on it — if Cloudinary appends format twice, fix `public_id` in the helper, NOT in Flutter)
4. **Limits** — attempt 2 photos → rejected with "Maximum 1 photos per report."
5. **Fallback** — remove local key + Railway var → upload lands in `public/uploads/...`, DB row is a relative path.
6. **Railway end-to-end** — one real production upload after deploy.

---

## 7. ROLLBACK

- **Soft (no code):** unset `CLOUDINARY_URL` / delete `config/cloudinary.local.php` → helper falls back to disk immediately. Already-stored Cloudinary URLs keep rendering (readers are URL-agnostic).
- **Hard:** revert the 3 swaps + delete `config/cloudinary.php` (all in git).

---

## 8. DEFERRED (out of scope, recorded for later)

- **Backfill old rows:** existing relative-path rows (local XAMPP copies still render there; Railway copies were already gone — ephemeral FS, only 17 upload files tracked in git). Future script: push local files → rewrite rows to absolute URLs.
- **Driver abstraction (SFTP/S3 "file server"):** the helper is the single seam — a future `storage_store_xxx()` replaces `cloudinary_upload()`'s body, call sites never change.
- **Bandwidth/credits:** Cloudinary free tier ≈ 25 GB storage/delivery; consider `quality:auto` transformations if videos grow.
