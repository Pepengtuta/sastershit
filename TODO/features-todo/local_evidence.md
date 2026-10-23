# Local Evidence Storage (Running Without Cloudinary)

The system uploads incident evidence (photos/videos) through one helper,
`cloudinary_upload()` in `config/cloudinary.php`. It supports **two backends**
and picks one automatically:

1. **Cloudinary** — used when a Cloudinary key is configured.
2. **Local disk** — the built-in fallback when no Cloudinary key is present.

**You do not need to change any code to switch between them.** Local storage
works out of the box; it is simply what happens when Cloudinary is not
configured.

---

## How the backend is chosen

`config/cloudinary.php` resolves the key in this order:

1. The `CLOUDINARY_URL` environment variable (production / Railway).
2. The file `config/cloudinary.local.php` (local dev only, git-ignored).
3. Neither found → **local-disk fallback**.

```
if no CLOUDINARY_URL and no cloudinary.local.php
    → save to public/uploads/<folder>/<file>   (local storage)
else
    → upload to Cloudinary, store the https URL
```

So: **to use local storage, just make sure neither Cloudinary source is set.**

---

## Enabling local storage

1. **Do not set `CLOUDINARY_URL`**
   - On Railway: remove the `CLOUDINARY_URL` variable from the service (Variables tab).
   - Locally: leave it out of your `.env` file.

2. **Remove the local Cloudinary file if it exists**
   - Delete or rename `config/cloudinary.local.php`.
   - This file is git-ignored, so it only exists if someone created it locally.

3. **Make sure the uploads folder is writable**
   - The fallback writes to `public/uploads/`.
   - On Linux hosts: `chmod -R 775 public/uploads` (and ensure the web user owns it).

That's it. New uploads now save to local disk.

---

## Where files go, and what the database stores

The caller passes a folder like `Ugyon/upload_incident_evidence/report_<id>`
(see `api/upload_incident_evidence.php:186`, `app/reports/save-report.php:282`,
`app/reports/update-report.php:325`).

- **File on disk:**
  `public/uploads/Ugyon/upload_incident_evidence/report_<id>/photo_<date>_<random>.jpg`

- **Value stored in `incident_attachments.file_path`** (a relative path):
  `uploads/Ugyon/upload_incident_evidence/report_<id>/photo_<date>_<random>.jpg`

Display handles both storage types already:

| Viewer | How the URL is produced |
|--------|-------------------------|
| Web pages (`app/includes/functions.php:606`) | Uses `file_path` as-is (relative to `/public/`), so local paths resolve correctly. |
| Mobile API (`api/get_report_attachments.php:36`, `api/upload_incident_evidence.php:33`) | `public_file_url()` turns a relative path into a full `https://host/.../public/uploads/...` URL; a full `https://` path (Cloudinary) is returned unchanged. |

So a report can safely contain a mix of old Cloudinary URLs and new local
paths — both render fine.

---

## Verifying it works

1. Upload a photo through the web form or the app.
2. Check the file exists:
   `public/uploads/Ugyon/upload_incident_evidence/report_<id>/`
3. Check the database row:
   ```sql
   SELECT file_path FROM incident_attachments ORDER BY id DESC LIMIT 1;
   ```
   It should start with `uploads/` (local) — not `https://res.cloudinary.com/...`.
4. Open the incident report page; the thumbnail should load.

---

## Important caveats

- **Ephemeral disks lose files.** On Railway (and most container hosts) the
  filesystem is **wiped on every deploy**. Any evidence saved locally will
  disappear. Local storage is only reliable on a host with a **persistent
  disk** (VPS, dedicated server, shared hosting like cPanel, or your own XAMPP
  machine). On Railway, use Cloudinary — or attach a persistent volume.
- **Backups.** With local storage, uploads live only on the server. Include
  `public/uploads/` in your backup routine (the database holds only paths).
- **Don't commit user evidence.** `public/uploads/` is not git-ignored. When
  using local storage, consider adding it to `.gitignore` so real evidence
  isn't pushed to the repository.
- **Prevent script execution in uploads.** The uploads folder is served
  directly. Add a `.htaccess` in `public/uploads/` to block execution, e.g.:
  ```apache
  <FilesMatch "\.(php|phtml|phar)$">
      Require all denied
  </FilesMatch>
  ```
- **Mixed history is fine.** Switching backends does not break old records;
  stored URLs keep working. Only *new* uploads use the new backend.

---

## Switching back to Cloudinary

Do the opposite of the steps above — configure either:

- Environment variable: `CLOUDINARY_URL=cloudinary://KEY:SECRET@CLOUD_NAME`, or
- File: `config/cloudinary.local.php` returning that same string.

New uploads go to Cloudinary immediately; existing local files stay where they are.

---

## Upload limits (both backends)

Set in `config/app_config.php`:

| Setting | Value |
|---------|-------|
| `UPLOAD_MAX_PHOTO_MB` | 10 |
| `UPLOAD_MAX_VIDEO_MB` | 50 |
| `UPLOAD_MAX_PHOTOS` per report | 1 |
| `UPLOAD_MAX_VIDEOS` per report | 1 |

For local storage, your PHP must also accept the file size — set in `php.ini`:

```ini
upload_max_filesize = 50M
post_max_size       = 55M
```

(Cloudinary has its own limits: ~10 MB per image, 100 MB per video on the free plan.)

---

## Files involved (reference)

| File | Role |
|------|------|
| `config/cloudinary.php` | `cloudinary_upload()` — Cloudinary or local-disk fallback. |
| `config/cloudinary.local.php` | Optional local key (git-ignored). Delete to force local storage. |
| `api/upload_incident_evidence.php` | App upload endpoint; calls `cloudinary_upload()`. |
| `app/reports/save-report.php`, `app/reports/update-report.php` | Web form uploads. |
| `api/get_report_attachments.php`, `app/includes/functions.php` | Build display URLs for both storage types. |
| `config/app_config.php` | Upload size/count limits. |
