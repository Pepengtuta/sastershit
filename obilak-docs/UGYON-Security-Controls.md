# UGYON — Security Controls (with code evidence)

> **Project:** UGYON  — disaster reporting & coordination system
> **Source verified:** commit `34583dcc` — 2026-11-25
> **Scope:** web app (PHP + MySQL) and mobile API (Flutter)
> **Convention:** `file:line` points to the exact code that implements the control.

## How to read this document

Each control has three parts:

- **How it works :** what the code actually does.
- **What does it do?:** one sentence a  reader can follow.
- **Evidence:** the `file:line` where it lives in the source.

---

## Quick map

| # | Control | Protects against | Evidence |
|---|---------|------------------|-------|
| 1 | Password hashing + safe login | Stolen/leaked passwords | `app/users/save-user.php:130` |
| 2 | CSRF tokens | Forged form submissions | `app/includes/csrf.php:18` |
| 3 | Prepared statements | SQL injection | `app/auth/login_process.php:21` |
| 4 | Output escaping | Cross-site scripting (XSS) | `app/includes/functions.php:2` |
| 5 | Role-based access control | Unauthorized actions | `app/includes/functions.php:995` |
| 6 | File-upload validation | Malicious uploads | `api/upload_incident_evidence.php:127` |
| 7 | Secret management + safe errors | Leaked credentials / info disclosure | `config/env.php:11` |
| 8 | Audit logging | Repudiation / untraceable changes | `api/create_incident.php:290` |

---

## 1. Login and passwords

**How it works  :**
Passwords are stored only as one-way hashes using PHP's `password_hash()` with `PASSWORD_DEFAULT` (bcrypt). When a user logs in, `password_verify()` compares the typed password against the stored hash — the real password is never saved or compared as plain text. On a successful login the session ID is regenerated with `session_regenerate_id(true)` so an old session identifier cannot be reused. Pages that require login include `app/auth/check_session.php` at the very top.

**What does it do?:**
The system never keeps the actual password — it keeps a scrambled version — and it gives the user a fresh session ID after logging in so an old one can't be hijacked.

**Evidence:**
- Hash on create: `app/users/save-user.php:130`, `api/save_user.php:154`
- Hash on password reset: `app/users/reset-password.php:76`, `api/reset_user_password.php:59`
- Verify on login: `app/auth/login_process.php:33`, `api/login.php:26`
- Regenerate session ID: `app/auth/login_process.php:47`
- Logged-in guard: `app/auth/check_session.php` (included at `public/dashboard.php:3`, `public/manage-users.php:3`, and 18 other pages)

---

## 2. CSRF protection

**How it works  :**
Each session gets a random token (`bin2hex(random_bytes(32))`). `csrf_field()` places it in a hidden form input. Every state-changing handler calls `csrf_verify()`, which compares the submitted token to the session token using `hash_equals()` (a constant-time comparison). If they don't match, the request is rejected.

**What does it do?:**
Every form carries a secret one-time code, so a fake page can't trick a logged-in user into submitting an action they didn't intend.

**Evidence:**
- Token generation: `app/includes/csrf.php:6`
- Hidden form field: `app/includes/csrf.php:13`
- Verification (constant-time): `app/includes/csrf.php:18`, `app/includes/csrf.php:25`
- Enforced in 22 handlers, e.g. `app/auth/login_process.php:3-4`, `app/reports/save-report.php:3-4`, `app/users/save-user.php:3-4`
- Token placed in forms, e.g. `public/login.php:248`, `public/create-incident-report.php:67`

---

## 3. SQL injection protection

**How it works  :**
Database queries use prepared statements: `mysqli_prepare()` builds the query, and `mysqli_stmt_bind_param()` attaches user values separately as typed parameters, so input is never interpreted as SQL. For a few dynamic filters (such as the municipality filter) the value is passed through `mysqli_real_escape_string()` before being interpolated.

**What does it do?:**
User input is handed to the database as data, never as part of the command, so a malicious entry can't change the query.

**Evidence:**
- Prepared statements, e.g. `app/auth/login_process.php:21`, `api/create_incident.php:261`, `app/users/save-user.php:112`
- Bound parameters, e.g. `api/create_incident.php:266`, `api/confirm_assistance_received.php:75`, `api/delete_hotline.php:32`
- Escaped dynamic filters, e.g. `api/get_map_data.php:41`, `public/dashboard.php:47`

---

## 4. Output escaping (XSS protection)

**How it works  :**
The helper `h()` wraps `htmlspecialchars($value, ENT_QUOTES, 'UTF-8')`. Output written into HTML pages is passed through `h()` so characters like `<`, `>`, and quotes are rendered as text instead of being executed as markup or script.

**What does it do?:**
Anything shown on a page is displayed as plain text, so a user can't sneak in a script that runs in someone else's browser.

**Evidence:**
- Definition: `app/includes/functions.php:2`

---

## 5. Role-based access control

**How it works  :**
Central helper functions decide what each role may do — for example `can_manage_users()`, `is_readonly_role()`, and `is_admin_role()`. The API equivalent `is_readonly_role_api()` mirrors this for JSON endpoints. Sensitive API actions additionally verify the acting account server-side with `verify_actor()` / `verify_superadmin()`, and `count_active_superadmins()` prevents removing the last administrator.

**What does it do?:**
The system checks who you are before letting you do something, and it won't allow the last admin to be deleted.

**Evidence:**
- Helpers: `app/includes/functions.php:995` (`can_manage_users`), `:1041` (`is_readonly_role`), `:1102` (`is_admin_role`), `:1086` (`count_active_superadmins`)
- API role check: `api/api_helper.php:38`
- API actor verification: `api/user_audit.php:40` (`verify_superadmin`), `:53` (`count_active_superadmins`), `:65` (`verify_actor`)

---

## 6. Safe file uploads

**How it works  :**
Uploads are checked in layers: the file extension must be on an allowlist; the size must be within the configured photo/video limit; the real content type is read with `finfo_file()` and must match the expected photo/video type; and the stored name is randomized (`bin2hex(random_bytes(6))`) so it cannot be guessed or overwrite another file.

**What does it do?:**
Before a file is accepted, the system checks what it really is (not just its name), how big it is, and renames it so it can't be guessed.

**Evidence:**
- Real content-type check: `api/upload_incident_evidence.php:127`, `:173-181`
- Extension check: `api/upload_incident_evidence.php:144`, allowlist at `:147`
- Size limit: `api/upload_incident_evidence.php:167`
- Randomized filename: `api/upload_incident_evidence.php:184`

---

## 7. Secret management and safe error messages

**How it works  :**
Configuration (database credentials, API keys) is read from process environment variables or a local `.env` file through `env_load()` / `env()`, rather than being hard-coded. In `config/app_config.php`, `DEBUG_MODE` is `false`, so real error details are written to the server log while users see a clean message produced by `fail_message()`.

**What does it do?:**
Passwords and keys are kept out of the code, and when something breaks, the user sees a friendly message while the technical details stay in the server's private log.

**Evidence:**
- Env loader: `config/env.php:11` (`env_load`), `:55` (`env`)
- Debug control and logging: `config/app_config.php:11`, `:25-27`
- Clean user message: `config/app_config.php:31` (`fail_message`)

---

## 8. Audit logging (accountability)

**How it works  :**
Significant actions write an audit record: incident creation inserts an entry into `incident_status_logs`, and status changes are written to the same log with who changed what and when. User management actions are recorded in `user_activity_logs`. Because these rows reference the acting user, actions can be traced back to an account.

**What does it do?:**
The system keeps a history of who did what, so changes can be traced and denied actions can be proven.

**Evidence:**
- Incident status log on create: `api/create_incident.php:290`
- Status-change log: `app/reports/update-status.php:127`

---

## Known limitations

These are stated honestly, with evidence. They are potential improvements, not hidden claims.

1. **CORS is fully open on the API.** Every endpoint sends `Access-Control-Allow-Origin: *` — e.g. `api/api_helper.php:3`.
2. **No explicit cookie security flags / security headers.** No use of `session_set_cookie_params()`, `httponly`, `samesite`, `X-Frame-Options`, or `Content-Security-Policy` was found in the codebase.
3. **Some dynamic SQL uses escaping instead of parameters.** Filter values are passed through `mysqli_real_escape_string()` rather than bound — e.g. `api/get_map_data.php:41`.
4. **No rate limiting or multi-factor authentication** is implemented.

---

## Mapping to ISO/IEC 25010 (Security)

| Sub-characteristic | Where it is addressed |
|--------------------|-----------------------|
| **Confidentiality** | Password hashing, safe error messages, secrets in env (Sections 1, 7) |
| **Integrity** | Prepared statements, CSRF, upload validation (Sections 2, 3, 6) |
| **Non-repudiation** | Audit logs of actions (Section 8) |
| **Accountability** | Role checks + activity logs (Sections 5, 8) |
| **Authenticity** | Password verification + session handling (Section 1) |

---

> **Note:** Line numbers were verified against commit `34583dcc`. If the code is edited later, re-check the referenced line before presenting, since numbers can shift.
