# Ugyon

**Ibajay Emergency Response Network** — a disaster reporting and response
coordination system for barangays and government response offices.

Ugyon gives barangays a fast, structured way to report incidents during
typhoons, floods, and other disasters, and gives municipal and provincial
offices one live view of what is happening across their area. It ships as two
clients over one shared database: a **Flutter mobile app** for field reporting
and a **web dashboard** for monitoring, verification, and response.

Current coverage: the municipalities of **Kalibo** (16 barangays) and
**Ibajay** (35 barangays) — **51 barangays** total.

---

## Overview

When a disaster hits, the people on the ground know what is happening but have
no fast, structured way to report it upward. Reports arrive by SMS, phone call,
radio, or paper, each one true but scattered, and no single record exists. Without
that record, responders act on stale information and officials cannot make
timely decisions such as declaring a state of calamity.

Ugyon replaces that fragmented process with **one shared incident record**:

- **Barangays** submit incident reports from their phones — disaster type,
  location pin, people affected/injured/dead/missing, road and evacuation
  conditions, photos/videos, and notes.
- **Municipal / provincial offices** see reports the moment they arrive, verify
  them, move them through a clear status workflow, and coordinate response.
- **Everyone** works from the same live picture: a map of incidents and
  evacuation centers, a hotline directory, broadcast alerts, a
  needs-and-assistance board, and a dashboard of charts and weather.

---

## What it does (MVP scope)

- **Incident reporting** — mobile + web forms with disaster type, GPS pin,
  impact counts, road accessibility, evacuation needs, and photo/video evidence.
- **Offline-tolerant mobile queue** — reports are saved on the device and sent
  when the connection returns.
- **Status workflow** — `Pending → Reviewed → Forwarded to PCF → Under MDR
  Review → Verified / Responding / Referred to PHO → Under PHO Review →
  Resolved / Dismissed`, with a full audit timeline on every report.
- **Live map** — barangay boundaries, barangay halls, evacuation centers,
  primary care facilities, and incident pins.
- **Evacuation centers** — directory with capacity, current evacuees, and status
  (Available / Open / Full / Closed / Needs Supplies).
- **Needs & Assistance** — centers declare their needs and vulnerable-sector
  profiles; donors pledge assistance; barangays confirm receipt
  (`Pledged → Sent → Delivered → Received`).
- **Alerts / broadcasts** — advisories sent to all or selected barangays with
  severity levels and per-user read receipts.
- **Emergency hotlines** — municipal and barangay contact directory.
- **Dashboard analytics** — status breakdown, daily trend, human-impact tally,
  and disaster-type chart, filterable by month/year.
- **Weather card** — current conditions, multi-day outlook, and a heavy-rain /
  strong-wind heads-up (Open-Meteo, cached on the server).
- **User management + audit trail** — scoped account administration and a log of
  administrative actions.

---

## Roles

Every account has a **role** and most also have a **sub-role** that narrows what
it can see and do. Municipality-scoped roles only ever see their own municipality.

| Role | Sub-role(s) | Who they are | What they mainly do |
|------|-------------|--------------|---------------------|
| **superadmin** | — | System administrator | Manage all accounts, view the audit trail, full access |
| **barangay** | `captain` | Barangay chairman | Submit/approve reports, manage the barangay account |
| **barangay** | `secretary` | Barangay secretary | Manage lower accounts and operational data |
| **barangay** | `tanod` | BHERT / field reporter | Submit incident reports |
| **pcf** | `mdr_admin` | Municipal coordination admin | Monitor & coordinate reports |
| **pcf** | `mdr_kalibo` / `mdr_ibajay` | Municipal MDR officer | Same, scoped to one municipality |
| **pcf** | `mayor_kalibo` / `mayor_ibajay` | Municipal mayor | Read-only observer (may pledge assistance) |
| **pho** | *(empty / admin)* | Provincial Health Office admin | Handle reports referred to PHO, manage PDRRMO/Governor accounts |
| **pho** | `pdrrmo` | Provincial DRRM officer | Provincial operational response |
| **pho** | `governor` | Provincial governor | Read-only, province-wide observer (may pledge assistance) |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Backend / API** | PHP 8.2+ (procedural, `mysqli`, PHP sessions), `vlucas/phpdotenv`, `curl` |
| **Database** | MySQL / MariaDB, `utf8mb4` |
| **Web dashboard** | Server-rendered PHP + HTML/CSS/JS, local Bootstrap assets, hand-built charts |
| **Mobile app** | Flutter / Dart (SDK `^3.12.0`), Material 3 |
| **Mobile networking** | `http` (JSON + multipart) |
| **Mobile storage** | `shared_preferences`, `sqflite` / `sqlite3` (offline queue) |
| **Maps** | Leaflet (web) and `flutter_map` + `latlong2` + `geolocator`; OpenStreetMap tiles, MBTiles vector tiles |
| **Media** | `image_picker`, `video_player`, `chewie`, `flutter_svg` |
| **Weather** | Open-Meteo public API (no key), cached server-side |
| **Evidence hosting** | Cloudinary, with a local-disk fallback |
| **Local server** | XAMPP (Apache + MySQL/MariaDB + PHP) |
| **Production host** | Railway (`railpack.json` → PHP provider) |

Design principle: keep it **simple, free, and self-contained** — no paid services
and no heavy front-end framework, so the whole system can run on one machine.

---

## Architecture

```mermaid
flowchart LR
    subgraph Clients
      W["Web dashboard<br/>PHP + HTML/CSS/JS"]
      M["Flutter mobile app"]
    end
    M -->|"JSON: api/*.php"| API["PHP REST API"]
    W -->|"direct mysqli (server-side)"| DB[("MySQL / MariaDB<br/>16 tables")]
    API --> DB
    API -->|evidence upload| CL["Cloudinary"]
    W -->|forecast| OM["Open-Meteo"]
    API -->|forecast| OM
```

**One thing worth knowing:** the two clients do **not** use the backend the same
way. The web pages (`public/`) access MySQL **directly** through PHP sessions,
while the Flutter app calls the JSON endpoints under `api/`. Many business rules
therefore live in two places (web and API), so changes to permissions, statuses,
or calculations must be kept in sync across both.

Every API response uses the same envelope:

```json
{ "success": true, "message": "...", "data": {} }
```

---

## Repository Structure

```text
Ugyon/
├─ api/                        JSON/multipart endpoints used by the mobile app
│  ├─ api_helper.php           Shared helpers (envelope, DB, validation)
│  └─ user_audit.php           Actor verification + audit helper
├─ app/                        Web dashboard server-side handlers & includes
│  ├─ includes/                header, sidebar, csrf, functions, weather_helper
│  └─ alerts/ auth/ evacuation-centers/ hotlines/ reports/ users/
├─ config/
│  ├─ db_connection.php        DB connection (reads DB_* env vars)
│  ├─ env.php                  Small .env loader
│  ├─ app_config.php           DEBUG_MODE + upload limits
│  └─ cloudinary.php           Evidence uploads (Cloudinary or local fallback)
├─ public/                     Browser entry points & rendered pages
│  ├─ asset/                   CSS, JS, Bootstrap, fonts, GeoJSON
│  └─ uploads/                 Local evidence fallback
├─ database/
│  ├─ capstone.sql             Consolidated schema + seed data (import this)
│  ├─ Railway/                 Production dump
│  ├─ migrations/ backups/
├─ flutter/flutter_saster/     Flutter mobile app (lib/, assets/, test/, pubspec.yaml)
├─ obilak-docs/                API.md, DATABASE.md, README.md
├─ Minor_changes/              Detailed change specifications
├─ TODO/                       Plans, source data, offline-map experiments
├─ composer.json               PHP deps (PHP >=8.2, mysqli, curl, phpdotenv)
├─ railpack.json               Railway PHP provider
├─ README1.md                  Railway deployment guide
└─ about_this_system.md        Coding-agent / architecture guide
```

---

## Getting Started

### A. Backend (web + API + database)

1. Install **XAMPP** (Apache + MySQL/MariaDB + PHP 8.2+).
2. Put the project folder under your XAMPP `htdocs` directory.
3. Start **Apache** and **MySQL** from the XAMPP control panel.
4. Create a database named **`capstone`** in phpMyAdmin
   (`http://localhost/phpmyadmin`) and import **`database/capstone.sql`** — this
   builds all 16 tables and loads the seed data.
5. Copy **`.env.example`** to **`.env`** and confirm the values
   (defaults below). Optionally set `CLOUDINARY_URL`.
6. Open **`http://localhost/<your-folder>/public/`** in a browser.

### B. Mobile app (Flutter)

```bash
cd flutter/flutter_saster
flutter clean
flutter pub get
flutter run -d chrome
```

For a physical phone, point the app at a reachable host (your LAN IP or a tunnel)
at build time — no file edit needed:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-server-ip>/<your-folder>
```

With no `--dart-define`, the app defaults to the current Railway deployment
(`flutter/flutter_saster/lib/constants/api_config.dart`).

---

## Configuration

Backend settings come from environment variables, loaded by
`config/env.php` + `config/db_connection.php`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DB_HOST` | `localhost` | Database host |
| `DB_USER` | `root` | Database user |
| `DB_PASS` | *(empty)* | Database password |
| `DB_NAME` | `capstone` | Database name (prod uses `railway`) |
| `DB_PORT` | `3306` | Database port |
| `CLOUDINARY_URL` | *(unset)* | `cloudinary://KEY:SECRET@CLOUD`; when unset, evidence is stored on local disk |

Additional settings in **`config/app_config.php`**:

- `DEBUG_MODE` — `true` shows real errors (development), `false` shows a clean
  message (demo/production). Currently **`false`**.
- Upload limits — **10 MB** per photo, **50 MB** per video, **1 photo + 1 video**
  per report.

---

## Default Accounts

The seed data creates the following logins. **All use the password `admin123`.**

| Username | Role | Sub-role |
|----------|------|----------|
| `superadmin` | superadmin | — |
| `pcfadmin` | pcf | mdr_admin |
| `phoadmin` | pho | — |

Barangay, MDR, mayor, PDRRMO, and governor accounts are provisioned from the
**Manage Users** screen (or the seed) and also default to `admin123`.

> ⚠️ **Development/demo credentials only.** This project is still in
> development. Change every password before any real or public deployment.

---

## Deployment

The app deploys to **Railway**, which detects PHP from `composer.json` and
`railpack.json`. Set the environment variables from the Configuration section as
service variables (`DB_*` and, for persistent evidence uploads, `CLOUDINARY_URL`).

> Note: on the current live deployment the application database is named
> **`railway`** (`DB_NAME=railway`), not `capstone`. Without Cloudinary, uploaded
> evidence is lost on every redeploy because the container disk is ephemeral.

See **[README1.md](README1.md)** for the step-by-step Railway guide.

---

## Known Limitations

- **No token-based authentication yet** — the API identifies the caller through
  values passed in the request (e.g. `user_id`, `acting_user_id`) rather than a
  session token. Add real authentication before public use.
- **Open CORS** (`Access-Control-Allow-Origin: *`) for development.
- No rate limiting, lockout, MFA, or password-policy service.
- The **weather** card and **map tiles** need internet access in the current
  implementation (offline MBTiles exist but are not fully wired in).
- A couple of endpoints remain **stubs** (`api/delete_alert.php`,
  `api/get_dashboard_counts.php`).
- Automated test coverage is minimal (a few Flutter widget tests; no PHP suite).

---

## Documentation

- **[obilak-docs/API.md](obilak-docs/API.md)** — every API endpoint.
- **[obilak-docs/DATABASE.md](obilak-docs/DATABASE.md)** — schema, tables, and
  local-vs-production differences.
- **[obilak-docs/README.md](obilak-docs/README.md)** — detailed system overview.
- **[about_this_system.md](about_this_system.md)** — architecture and coding guide.
- **[README1.md](README1.md)** — Railway deployment walkthrough.

---

## Credits

- Capstone project — **&lt;ASU STUDENTS&gt;**
- Weather data: [Open-Meteo](https://open-meteo.com) (free, no API key)
- Maps: OpenStreetMap via Leaflet and flutter_map
- Evidence hosting: [Cloudinary](https://cloudinary.com)
