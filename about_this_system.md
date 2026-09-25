# OBILAK / SasterGPT — System Architecture and Coding-Agent Guide

> **Canonical codebase briefing.** Give this file to a coding agent before asking it to modify the project.
> It describes the current source snapshot, not an idealized design. When this document conflicts with executable code, the executable code and `database/capstone.sql` win.

**Snapshot reviewed:** 2026-09-21  
**Project root:** `sastergpt/`  
**Product name in the UI:** **Ugyon**  
**System/domain name in documentation:** **OBILAK**  
**Scale reviewed:** 443 files; about 39,785 lines across PHP, Dart, SQL, CSS, JavaScript, and Markdown source areas.

---

## 0. Read this first

### What the system is

OBILAK is a disaster reporting, coordination, evacuation-center, assistance, alerting, mapping, and audit system for barangays and government response offices in Aklan. The checked-in data and role logic currently cover **Kalibo and Ibajay**, not only the original 16 Kalibo barangays.

It has two clients sharing one MySQL database:

1. **Server-rendered web application** for operational and administrative use.
2. **Flutter application** for Barangay, PCF/MDR, PHO/PDRRMO, observers, and Superadmin.

### The most important architecture fact

The web and Flutter clients do **not** use the backend in the same way:

- Web pages under `public/` and form handlers under `app/` use PHP sessions and access MySQL directly with `mysqli`.
- Flutter calls JSON endpoints under `api/`.
- Therefore, most business rules exist twice: once in the web path and once in the API/mobile path.

When changing permissions, status transitions, validation, scoping, or calculations, inspect and update **both paths**.

### Recommended reading order for a new agent

1. `about_this_system.md` — this document.
2. `app/includes/functions.php` — web permission, labels, incident-detail rendering, municipality, map-boundary, and assistance helpers.
3. `api/api_helper.php` and `api/user_audit.php` — common API helpers and API actor verification.
4. `database/capstone.sql` — canonical consolidated schema and seed snapshot.
5. The specific web page + handler pair and Flutter screen + service + API endpoint for the requested feature.
6. Relevant files in `Minor_changes/` when touching evacuation assistance, observer roles, or road status.

### Sources of truth

| Concern | Primary source of truth |
|---|---|
| Current consolidated schema | `database/capstone.sql` |
| Web role/scoping helpers | `app/includes/functions.php` |
| Web authentication | `app/auth/login_process.php`, `app/auth/check_session.php` |
| API response envelope/common setup | `api/api_helper.php` |
| Flutter session/role mirrors | `flutter/flutter_saster/lib/services/auth_service.dart` |
| Flutter API URL | `flutter/flutter_saster/lib/constants/api_config.dart` |
| Incident API transition checks | `api/update_status.php` |
| Incident web transition checks | `app/reports/update-status.php` |
| Assistance calculations/policy | `Minor_changes/01_...` through `05_...`, plus current code |
| Upload limits | `config/app_config.php` and Flutter `incident_service.dart` |

---

## 1. High-level architecture

```text
┌───────────────────────────────────────────────────────────────────┐
│                           CLIENTS                                 │
│                                                                   │
│  Server-rendered web                         Flutter application   │
│  public/*.php                                lib/screens/*         │
│       │                                             │              │
│       │ HTML forms + PHP session                    │ JSON/multipart│
│       ▼                                             ▼              │
│  app/* mutation handlers                       api/*.php           │
│       │                                             │              │
│       └──────────────────┬──────────────────────────┘              │
│                          ▼                                         │
│                    MySQL/MariaDB                                   │
│                    database: capstone                              │
└───────────────────────────────────────────────────────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          ▼                                   ▼
  Open-Meteo weather                   Map tiles / map links
  cached by PHP                        OSM/Leaflet/flutter_map
```

### Technology stack

| Area | Technology |
|---|---|
| Web/backend | Procedural PHP 8-style code, `mysqli`, PHP sessions |
| Database | MySQL/MariaDB, database name `capstone`, utf8mb4 |
| Web UI | Server-rendered HTML, local Bootstrap assets, custom CSS/JS |
| Web maps | Leaflet; GeoJSON overlays; OpenStreetMap tiles |
| Mobile/web app | Flutter/Dart, Material 3, vanilla `setState` |
| Mobile networking | `http` package; JSON and multipart requests |
| Mobile persistence | `shared_preferences` |
| Mobile maps | `flutter_map`, `latlong2`, `geolocator` |
| Media | `image_picker`, `video_player`, `chewie`, `flutter_svg` |
| External weather | Open-Meteo, cached by `weather_helper.php` |

### Internet/offline reality

The core PHP/MySQL system can run on a LAN, but the complete experience is not fully offline:

- Open-Meteo requires internet when cache refreshes.
- OSM map tiles require internet unless an offline tile solution is wired in.
- Web `map.php` loads Leaflet from a public CDN in the current source.
- Google Maps links in Flutter report details require internet/external app access.
- `.mbtiles` files exist under `TODO/`, but they are not integrated into the active clients.

---

## 2. Repository layout

```text
sastergpt/
├── api/                         JSON/multipart endpoints used by Flutter
├── app/
│   ├── alerts/                  Web alert mutations
│   ├── auth/                    Web session login/filter logic
│   ├── evacuation-centers/      Web center, needs, pledge, receipt mutations
│   ├── hotlines/                Web hotline mutations
│   ├── includes/                Shared web helpers/layout/CSRF/weather
│   ├── reports/                 Web incident create/edit/status handlers
│   └── users/                   Web account/population mutations
├── config/
│   ├── app_config.php           Debug switch and upload limits
│   ├── db_connection.php        MySQL connection
│   └── test_remote.php          Remote diagnostic script; contains credentials
├── database/
│   ├── capstone.sql             Consolidated schema + current seed snapshot
│   ├── migrations/              Incremental historical migrations
│   └── backups/                 Historical SQL snapshots; not application code
├── public/                       Browser entry points and rendered pages
│   ├── asset/                   CSS, JS, Bootstrap, fonts, logos, GeoJSON
│   └── uploads/incidents/       Web-served incident evidence
├── flutter/flutter_saster/
│   ├── lib/                     Active Dart application source
│   ├── assets/                  Flutter GeoJSON, logos, app icon
│   ├── test/                    Two Flutter widget test files
│   ├── android|ios|web|...      Platform wrappers/generated integration files
│   └── pubspec.yaml             Flutter dependencies and assets
├── Minor_changes/               Detailed implemented-change specifications
├── TODO/                        Plans, source data, offline-map experiments
├── obilak-docs/                 Older developer documentation
├── brief.md                     Product/presentation brief
├── About_this_system.md         Older architecture summary
└── about_this_system.md         Current coding-agent guide (this file)
```

### Active source versus reference/generated content

Agents should normally modify:

- `api/`, `app/`, `public/`
- `config/` only with care
- `database/capstone.sql` and/or a new migration
- `flutter/flutter_saster/lib/`, `assets/`, `test/`, `pubspec.yaml`

Agents should not treat these as active runtime source unless the task specifically requires them:

- `database/backups/`
- `obilak-docs/obilak-docs.zip`
- `.gradle`, IDE metadata, platform build files, lock files
- `TODO/*.mbtiles`
- sample uploaded incident photos

---

## 3. Runtime flows

### Web request flow

```text
Browser → public/<page>.php
        → app/auth/check_session.php
        → config/db_connection.php
        → app/includes/header.php + sidebar.php
        → direct SELECT queries

Form POST → app/<feature>/<handler>.php
          → session + CSRF verification
          → permission/scope checks
          → prepared INSERT/UPDATE/DELETE
          → redirect back to public page
```

The web application is not a thin client. Large pages such as `dashboard.php`, `map.php`, `incident-reports.php`, and `manage-users.php` contain substantial query and presentation logic.

### Flutter request flow

```text
Screen/widget
  → lib/services/<feature>_service.dart
  → ApiService.postJson/getJson or MultipartRequest
  → api/<endpoint>.php
  → MySQL
  → { success, message, data }
  → screen setState()
```

There is no Provider, Riverpod, BLoC, Redux, dependency injection framework, or generated routing layer. State is local and imperative.

### API envelope

Most endpoints return:

```json
{
  "success": true,
  "message": "Human-readable result",
  "data": {}
}
```

Some endpoints add metadata such as `scope`, but the three envelope keys are the norm.

---

## 4. Roles, sub-roles, scope, and permissions

### Database roles

`users.role` is one of:

- `superadmin`
- `barangay`
- `pcf`
- `pho`

### Sub-roles

| Parent role | Sub-role | Meaning and effective scope |
|---|---|---|
| Barangay | `captain` | Barangay Chairman; own barangay; can manage users and operational data |
| Barangay | `secretary` | Own barangay; can manage BHERT users and center-related data |
| Barangay | `tanod` | BHERT/field reporter; reports are commonly scoped to own submissions |
| PCF | `mdr_admin` | Municipal coordination administrator; can manage PCF users |
| PCF | `mdr_kalibo` | Operational MDR account forced to Kalibo |
| PCF | `mdr_ibajay` | Operational MDR account forced to Ibajay |
| PCF | `mayor_kalibo` | Kalibo Mayor observer; read-only except assistance pledges |
| PCF | `mayor_ibajay` | Ibajay Mayor observer; read-only except assistance pledges |
| PHO | `NULL`/empty | Provincial/PHO Admin; broad operational and account-management rights |
| PHO | `pdrrmo` | Province-level operational response account |
| PHO | `governor` | Province-wide observer; read-only except assistance pledges |

### Important helper behavior

Web canonical helpers are in `app/includes/functions.php`:

- `is_readonly_role()` → Mayors and Governor.
- `mdr_municipality()` → fixed town for `mdr_kalibo`/`mdr_ibajay`.
- `mayor_municipality()` → fixed town for Mayor observers.
- `get_effective_municipality()` → forced town first, otherwise selected session filter.
- `can_manage_status()` and `can_review_reports()` → PCF, excluding read-only observers.
- `can_manage_evacuation_centers()` → Superadmin, PCF, PHO, Barangay Captain/Secretary, excluding observers.
- `can_manage_hotlines()` → Superadmin, PCF, PHO, excluding observers.
- `can_publish_alerts()` → PCF and PHO, excluding observers.
- `can_view_assistance()` / `can_pledge_assistance()` → Superadmin, PCF, PHO; this intentionally permits Mayor/Governor pledges.
- `can_manage_users()` → Superadmin, Barangay Captain/Secretary, PCF `mdr_admin`, and PHO Admin.

Flutter mirrors many of these decisions in `AuthService`. Do not change only one copy.

### Municipality filter behavior

- MDR Kalibo/Ibajay and Mayor Kalibo/Ibajay are forced to their respective municipality.
- Other admin roles may select a municipality or all municipalities.
- PHO accounts currently default to **Ibajay** on fresh web and Flutter login. This is current behavior, not a universal architectural requirement.
- Governor views are province-wide in evidence/report flows and use month/year windows.
- Mayor evidence/report flows use municipality plus month/year windows.

### Permission caveat

UI visibility is not a security boundary. A mutation must enforce permissions in the PHP handler/endpoint. Several areas already do this, but authorization is not centralized and parity must be reviewed for every change.

---

## 5. Incident-report domain

### Stored incident fields

An incident may contain:

- Reporter and barangay
- Disaster type
- Incident date/time and exact location
- GPS latitude/longitude
- Soft `pin_outside_area` boundary flag
- Road accessibility: `Passable`, `Partially Passable`, `Obstructed`
- Road blockage causes and road/bridge location
- Evacuation required and selected center
- Evacuation household/adult/child/member counts
- Description and assistance requested
- Affected, injured, dead, missing counts
- Workflow status and `referred_to_pho`
- Photo/video attachments
- Status timeline records

### Creation/edit rules

- Only active Barangay accounts create reports.
- New reports are `Pending` and receive an initial status-log entry.
- A report can be edited only while `Pending`.
- The reporter or Barangay Chairman can edit within the actor's registered barangay.
- Coordinates are range-validated; a pin outside the selected barangay is a warning/soft flag, not a blocker.
- Natural-disaster forms can prefill affected population from `barangays.population`, but the number remains editable.

### Current status vocabulary

Canonical active values used by handlers:

```text
Pending
Reviewed
Forwarded to PCF            (displayed as Forwarded to MDR/Municipal)
Under MDR Review
Verified
Responding
Referred to PHO             (legacy input "Forwarded to PHO" is normalized)
Under PHO Review
Resolved
Dismissed
```

Other legacy/display strings such as `Under Review`, `Returned`, `Ongoing Response`, and `Forwarded to PHO` still appear in compatibility/display code. Avoid introducing new stored values without updating every filter, badge, query, API, and client.

### Workflow and acknowledgment gates

```text
Barangay submit
  Pending
    ├─ Chairman → Reviewed
    ├─ Chairman → Dismissed
    └─ Chairman → Forwarded to PCF

Municipal/MDR receives
  Forwarded to PCF
    → Under MDR Review          required acknowledgment
    → Verified / Responding / Referred to PHO / Resolved / Dismissed

Provincial receives
  Referred to PHO
    → Under PHO Review          required acknowledgment
    → Responding / Resolved / Dismissed as exposed by the PHO UI
```

The backend currently enforces acknowledgment of `Forwarded to PCF` before further PCF action and acknowledgment of `Referred to PHO` before further PHO action. It does not implement a single explicit transition matrix for all possible old/new combinations, so agents should not assume every non-ack transition is strictly constrained.

Every status mutation should append `incident_status_logs`.

### Evidence uploads

Configuration in `config/app_config.php`:

- Photos: up to 15 MB each
- Videos: up to 50 MB each
- Maximum 5 photos
- Maximum 2 videos

Flutter duplicates these checks in `incident_service.dart`; keep both sides synchronized. Files are stored below `public/uploads/incidents/report_<id>/` and indexed in `incident_attachments`.

---

## 6. Evacuation centers and assistance

### Center directory

`evacuation_centers` stores municipality, barangay, name/type, capacity, current evacuees, status, contacts, coordinates, and demo flag.

Status allow-list:

- `Available`
- `Open`
- `Full`
- `Closed`
- `Needs Supplies`

### Center needs model

The feature uses three related structures:

1. `evac_center_profile` — who is inside: evacuees, families, pregnant people, lactating mothers, infants, children, older persons, PWD, sick, injured.
2. `evac_center_needs` — declared item/unit/quantity needs.
3. `evac_assistance` — donor pledge and delivery ledger.

### Assistance lifecycle

```text
Pledged → Sent → Delivered → Barangay confirms receipt
```

Receipt is not a fourth status. Receipt is represented by `received_at` and `qty_received` while the status remains `Delivered`.

### Quantity semantics

There are two intentionally different concepts:

- **Committed/pending supply** can include pledge stages for forecasting.
- **Actually fulfilled supply** should be based on confirmed received quantity where the receiving workflow requires confirmation.

The `Minor_changes/` documents explain the historical distinctions. Before changing unmet/progress math, inspect:

- `get_assistance_board.php`
- `get_center_needs.php`
- `functions.php`
- `dashboard.php` and `get_dashboard_summary.php`
- Flutter `need_progress_bar.dart`, `assistance_board_screen.dart`, `center_needs_screen.dart`

### Pledge ownership

- Ordinary donors, Mayors, and Governor may advance only their own pledge status.
- Superadmin, PHO Admin, and PDRRMO have broader status override rights.
- Governor is explicitly excluded from the PHO override.
- Barangay Captain/Secretary confirms delivered quantities for centers in the actor's own barangay.

### Known parity hotspot

The API generally hard-checks Mayor/MDR municipality scope. Some web assistance handlers historically relied on the already-scoped board UI and may not perform the same Mayor-specific direct-POST scope check. When hardening, copy the stricter API behavior to the web handler.

---

## 7. Alerts, hotlines, maps, dashboard, and users

### Alerts

- Alerts have title, type, severity, message, instructions, status, start/end times, target type, creator.
- `alert_barangays` stores selected targets.
- `alert_reads` stores per-user read receipts used for unread badges.
- PCF/PHO publish; Barangay accounts consume targeted alerts.
- Mayor/Governor observers are blocked from publishing.
- `api/delete_alert.php` is currently a stub/reserved endpoint.

### Hotlines

- Municipal or Barangay scope.
- Multiple phone fields exist: telephone, cellphone, and legacy/general hotline number.
- Web and API CRUD are implemented.
- Superadmin/PCF/PHO manage; read-only observers are blocked by API and intended UI gates.

### Maps

Map data combines:

- Barangay boundary GeoJSON
- Barangay hall coordinates
- Evacuation center markers
- Incident markers
- Primary care facility markers

Relevant code:

- Web: `public/map.php`
- Flutter: `shared/map_view_screen.dart`
- API: `api/get_map_data.php`
- Boundary validation: bottom section of `app/includes/functions.php`
- GeoJSON: `public/asset/data/`, Flutter `assets/data/`

Kalibo boundaries are GeoJSON polygons. Ibajay uses a separate barangay/purok asset and custom matching logic. Name normalization is important; avoid changing barangay names without checking boundary matching.

### Dashboard

Both web and API dashboards compute:

- Total/status counts
- Disaster-type breakdown
- Human-impact totals
- Daily trend
- Recent reports
- Evacuation-center count/status
- Weather
- Role-specific evidence summaries
- Assistance summary for admin roles

The web implementation is in the very large `public/dashboard.php`; mobile uses `api/get_dashboard_summary.php` plus `dashboard_summary_view.dart` and `evidence_card.dart`.

`api/get_dashboard_counts.php` is a stub and is not the active dashboard endpoint.

### User management

The system supports scoped account management:

- Superadmin can manage all roles.
- Barangay Captain/Secretary manage users in their own barangay, with Secretary restrictions around Chairman accounts.
- PCF `mdr_admin` manages PCF accounts; municipality MDR accounts have narrower sub-role scope.
- PHO Admin manages PDRRMO/Governor accounts.
- Last-active-Superadmin protections exist.
- User actions are recorded in `user_activity_logs`.
- Barangay population editing is integrated into Manage Users.

---

## 8. Database reference

### Canonical database

- Name: `capstone`
- Connection: `config/db_connection.php`
- Charset: utf8mb4
- Canonical consolidated dump: `database/capstone.sql`

### Tables

| Table | Purpose and important links |
|---|---|
| `users` | Accounts, role/sub-role, barangay, active status, user-management flag |
| `barangays` | Municipality, province, coordinates, status, population |
| `disaster_types` | Active disaster category lookup |
| `incident_reports` | Core reports and workflow state |
| `incident_attachments` | Evidence metadata; child of incident report |
| `incident_status_logs` | Incident audit timeline; child of incident report |
| `evacuation_centers` | Center directory and operational status |
| `evac_center_profile` | Center demographics/vulnerable sectors; one row per center |
| `evac_center_needs` | Declared center needs |
| `evac_assistance` | Pledge/sent/delivered/received ledger |
| `emergency_hotlines` | Municipal/barangay contacts |
| `alerts` | Alert content and schedule |
| `alert_barangays` | Selected alert targets |
| `alert_reads` | Per-user alert read receipts |
| `pcf_facilities` | Primary care facility map pins |
| `user_activity_logs` | Account-management audit entries |

### Important relationships

```text
barangays 1 ── * users
barangays 1 ── * incident_reports
users     1 ── * incident_reports
incident_reports 1 ── * incident_attachments      (cascade delete)
incident_reports 1 ── * incident_status_logs      (cascade delete)

evacuation_centers 1 ── 0..1 evac_center_profile
evacuation_centers 1 ── * evac_center_needs
evacuation_centers 1 ── * evac_assistance
evac_center_needs  1 ── * evac_assistance (nullable need_id)

alerts 1 ── * alert_barangays
alerts 1 ── * alert_reads
```

Some logical links are not enforced uniformly with foreign keys in every historical migration/dump. Code must handle missing/deleted linked rows defensively.

### Current seed scope

The consolidated dump contains Kalibo plus Ibajay data, including 35 Ibajay barangays added by migration. Default/demo accounts and sample operational records are present. Treat all default credentials as development-only and change them before deployment.

### Migration strategy

For a fresh environment, prefer importing the latest `database/capstone.sql`; it already includes the consolidated schema. Do **not** blindly replay every historical migration after importing it.

For upgrading an older database, inspect which columns/tables/indexes already exist, back up first, then apply only missing migrations in dependency order. The main historical dependency chain is:

1. Barangay sub-roles and population
2. PCF MDR sub-roles
3. PHO/PDRRMO sub-role
4. Mayor sub-roles
5. Governor role, which restores the complete final enum
6. Evacuation headcount and road-access columns
7. Assistance tables and receipt columns
8. Pin-outside/demo flags
9. Performance indexes
10. Optional demo seeds

Several migrations are not fully idempotent. `add_performance_indexes.sql` explicitly fails if repeated.

---

## 9. API endpoint map

All paths below are relative to `api/`.

### Authentication and lookup

| Endpoint | Status | Purpose |
|---|---|---|
| `login.php` | Implemented | Password login; returns user/role/sub-role/scope data; no token issued |
| `get_barangays.php` | Implemented | Active barangays with population; can derive PCF scope from acting user |
| `get_municipalities.php` | Implemented | Distinct municipality list |
| `get_disaster_types.php` | Implemented | Active disaster types |

### Incidents

| Endpoint | Status | Purpose |
|---|---|---|
| `create_incident.php` | Implemented | Create Barangay incident and initial log |
| `update_incident.php` | Implemented | Edit Pending report in actor's barangay |
| `get_reports.php` | Implemented | Role/sub-role/municipality/month scoped reports |
| `update_status.php` | Implemented | Incident status mutation and timeline entry |
| `upload_incident_evidence.php` | Implemented | Multipart evidence upload |
| `get_report_attachments.php` | Implemented | Evidence metadata and public URLs |
| `get_report_logs.php` | Implemented | Status timeline |

### Dashboard and map

| Endpoint | Status | Purpose |
|---|---|---|
| `get_dashboard_summary.php` | Implemented | Main mobile dashboard payload, weather, evidence, assistance summary |
| `get_dashboard_counts.php` | Stub | Reserved; do not build new work on it |
| `get_map_data.php` | Implemented | Hall/center/facility/incident map data |

### Evacuation centers and assistance

| Endpoint | Status | Purpose |
|---|---|---|
| `get_evacuation_centers.php` | Implemented | Scoped center list |
| `save_evacuation_center.php` | Implemented | Create center with authorization/scope checks |
| `update_evacuation_center.php` | Implemented | Update center |
| `delete_evacuation_center.php` | Implemented | Delete center |
| `get_center_needs.php` | Implemented | Profile, needs, ledger, receipt capabilities |
| `save_center_needs.php` | Implemented | Upsert profile and synchronize needs |
| `get_assistance_board.php` | Implemented | Admin/observer assistance board payload |
| `pledge_assistance.php` | Implemented | Create pledge and over-pledge flag |
| `update_assistance_status.php` | Implemented | Pledged→Sent→Delivered with ownership/override rules |
| `confirm_assistance_received.php` | Implemented | Barangay confirms actual received quantity |

### Alerts and hotlines

| Endpoint | Status | Purpose |
|---|---|---|
| `get_alerts.php` | Implemented | Scoped alerts and creator/read metadata |
| `save_alert.php` | Implemented | Publish targeted alert |
| `delete_alert.php` | Stub | Reserved |
| `get_unread_alert_count.php` | Implemented | Barangay unread badge count |
| `mark_alerts_read.php` | Implemented | Insert read receipts |
| `get_hotlines.php` | Implemented | Scoped hotline list |
| `save_hotline.php` | Implemented | Create hotline |
| `update_hotline.php` | Implemented | Update hotline |
| `delete_hotline.php` | Implemented | Delete hotline |

### Users and audit

| Endpoint | Status | Purpose |
|---|---|---|
| `get_users.php` | Implemented | Actor-scoped account list |
| `save_user.php` | Implemented | Scoped account creation |
| `update_user.php` | Implemented | Scoped account update |
| `reset_user_password.php` | Implemented | Scoped password reset |
| `toggle_user_status.php` | Implemented | Activate/deactivate with self/last-admin protections |
| `update_barangay_population.php` | Implemented | Superadmin-any or Barangay-own population update |
| `get_user_activity.php` | Implemented | Superadmin/PHO-scoped audit list |
| `user_audit.php` | Helper | Actor verification and audit helper; not a client endpoint |

### API caveats

- CORS is `*` in common and many standalone endpoints.
- There is no bearer token, API key, signed session, or JWT.
- The Flutter session is a cached user JSON object in `SharedPreferences`.
- Many write endpoints re-read the actor by `acting_user_id` or `user_id`, which is better than trusting a client role, but possession of an ID is still not authentication.
- Some read endpoints accept a role/scope directly from the request.
- Helpers are duplicated across many endpoint files instead of consistently using `api_helper.php`.

Before internet/public deployment, add real API authentication and centrally enforced authorization.

---

## 10. Web page map

| Page | Main responsibility |
|---|---|
| `index.php` | Redirect to login or dashboard |
| `login.php` / `logout.php` | Web session entry/exit |
| `dashboard.php` | Role-scoped analytics, weather, evidence, recent reports, assistance summary |
| `incident-reports.php` | Barangay/PCF/Superadmin report listing and PCF workflow actions |
| `health-reports.php` | PHO referred-report workflow |
| `review-reports.php` | Legacy redirect to `incident-reports.php` |
| `create-incident-report.php` | Web report form with map, boundary warning, impact and evidence |
| `edit-incident-report.php` | Pending report edit form |
| `map.php` | Full role-scoped map and marker controls |
| `evacuation-centers.php` | Center list and CRUD entry points |
| `center-needs.php` | Center profile, declared needs, ledger, receipt confirmation |
| `assistance.php` | Cross-center needs and assistance board |
| `hotlines.php` | Hotline directory/CRUD |
| `alert.php` | PCF/PHO alert list |
| `barangay-alerts.php` | Barangay-targeted alerts |
| `manage-users.php` | Scoped user administration and population editing |
| `user-activity.php` | Role-scoped account audit trail |

Shared web files:

- `header.php` opens the document and loads local Bootstrap/custom styles.
- `sidebar.php` controls role-aware navigation and municipality filtering.
- `footer.php` loads local JS/Bootstrap and closes layout.
- `csrf.php` issues and verifies web form tokens.
- `functions.php` is a large shared policy/presentation utility file.
- `weather_helper.php` calls/caches Open-Meteo and classifies weather alerts.

---

## 11. Flutter architecture and screen map

### Application boot/session

- `main.dart` builds `SasterApp` and `SessionGate`.
- `AuthService.restoreSession()` loads cached user JSON.
- The role selects one of four shell screens: Barangay, PCF, PHO, Superadmin.
- Navigation uses `Navigator.push` and `MaterialPageRoute`; shell tabs use `NavigationBar` plus drawers.

### Constants

| File | Responsibility |
|---|---|
| `api_config.dart` | Base API/file URLs and optional ngrok header |
| `app_colors.dart` | Shared UI palette and evacuation-status color mapping |
| `disaster_type_config.dart` | Disaster labels/colors/type normalization |
| `status_labels.dart` | Display renames for stored status values |

### Models

Models exist for alerts, API envelope, evacuation centers, hotlines, incidents, and users. However, many screens/services still pass `Map<String,dynamic>` rather than consistently using typed models.

### Services

| Service | Backend area |
|---|---|
| `api_service.dart` | Generic JSON GET/POST, timeout/network handling |
| `auth_service.dart` | Login, cached session, role helpers, municipality filter |
| `incident_service.dart` | Incident CRUD, status, evidence, logs |
| `dashboard_service.dart` | Dashboard summary |
| `map_data_service.dart` | Map payload |
| `alert_service.dart` | Alerts and read receipts |
| `evacuation_center_service.dart` | Center CRUD/list |
| `assistance_service.dart` | Needs, board, pledge, delivery, receipt |
| `hotline_service.dart` | Hotline CRUD/list |
| `barangay_service.dart` | Barangay list/population |
| `user_service.dart` | Accounts and activity log |

### Role shells and screens

**Barangay**

- Dashboard
- Reports and create/edit incident
- Alerts
- Emergency hotlines
- Drawer: map, evacuation centers, profile, and scoped user management
- Tanod/BHERT report lists are scoped to the current reporter
- Secretary does not receive the create-report floating action button in the current shell

**PCF/MDR/Mayor**

- Dashboard
- Review reports
- Map
- Alerts/hotlines/centers/assistance via shell and drawer
- Municipality selection for unrestricted roles
- MDR Kalibo/Ibajay forced scope
- Mayor shells hide mutation actions except assistance pledge capability
- `pcf_main_screen.dart` contains embedded PCF user-management UI and is large

**PHO/PDRRMO/Governor**

- Dashboard
- Health reports
- Map
- Alerts/hotlines/centers/assistance
- PHO Admin user/activity management
- Governor evidence drill-down and read-only observer behavior

**Superadmin**

- Dashboard, map, centers, hotlines
- User management and activity log
- Municipality filter
- Operational incident status is generally observational rather than a Superadmin responsibility

### Large/high-coupling Dart files

These are frequent regression hotspots:

- `dashboard_summary_view.dart` (~1269 lines)
- `create_incident_screen.dart` (~1077)
- `edit_incident_screen.dart` (~1143)
- `assistance_board_screen.dart` (~984)
- `center_needs_screen.dart` (~952)
- `map_view_screen.dart` (~915)
- `report_details_sheet.dart` (~862)
- role shell files with embedded account management

Prefer targeted edits and extract reusable logic when making larger feature changes.

---

## 12. Configuration, setup, and commands

### Local backend setup

1. Install/start XAMPP Apache and MySQL.
2. Put the project below the expected web root, commonly `htdocs/vsp/sastergpt`.
3. Create/import MySQL database `capstone` from `database/capstone.sql`.
4. Confirm `config/db_connection.php` matches the local database.
5. Open `http://localhost/vsp/sastergpt/public/`.

### Flutter setup

```bash
cd flutter/flutter_saster
flutter clean
flutter pub get
flutter run -d chrome
```

For a physical device, change `ApiConfig.baseUrl` and `fileBaseUrl` to a reachable LAN or tunnel URL. Keep the `/api` and project-root path distinction.

### Debug/upload configuration

`config/app_config.php` currently has `DEBUG_MODE = true`. Set it to false for demos/normal deployment so technical errors are not displayed.

Keep server and Flutter upload limits aligned.

### Testing

Current automated coverage is very small:

- `test/need_progress_bar_test.dart`
- `test/widget_test.dart`

Recommended checks after a change:

```bash
flutter analyze
flutter test
php -l path/to/changed-file.php
```

Also run the role/scope workflow manually against a test database. There is no comprehensive PHP test suite.

---

## 13. Security and deployment warnings

### Critical

1. **`config/test_remote.php` contains hard-coded remote database credentials.** Remove it from deployable/public code, rotate the exposed credentials, and use environment variables or server-side secrets. This document intentionally does not reproduce those values.
2. **The JSON API has no real authenticated session/token.** An actor ID is not proof of identity.
3. **Open CORS** allows any origin to call the API.
4. `DEBUG_MODE` is currently true and may disclose technical details.
5. Default/demo accounts share known development passwords and must not remain active in production.

### Important

- Evidence URLs are public web paths; there is no private signed-download layer.
- Upload checks are custom and duplicated. Validate MIME content, extension, size, and ownership on the server.
- Web authorization is spread across helper functions and individual handlers.
- API authorization is spread across endpoints; several files define their own `send_response`, table helpers, and role checks.
- Read endpoints may trust client-supplied role/scope.
- No rate limiting, lockout, MFA, password policy service, or server-side mobile session revocation exists.
- Weather/map external requests need timeouts, fallback behavior, and deployment connectivity planning.

---

## 14. Known architecture risks and likely bug hotspots

1. **Duplicated business rules:** web and API/mobile can drift.
2. **Duplicated role logic:** PHP helpers, standalone endpoint checks, and Flutter `AuthService` mirrors.
3. **Stringly typed statuses:** many queries and UI branches depend on exact strings.
4. **Legacy status aliases:** `Forwarded to PHO`, `Under Review`, and other compatibility labels can confuse new code.
5. **Large files:** dashboard, map, incident forms, and assistance screens combine data, policy, and UI.
6. **Schema compatibility branches:** endpoints dynamically check columns/tables for older databases, which can hide partially migrated environments.
7. **Name-based joins:** some center/barangay scoping joins on barangay text names rather than IDs.
8. **Web/API permission parity:** observers and municipality scope need deliberate direct-request testing.
9. **Default PHO Ibajay filter:** surprising behavior can look like missing data.
10. **Minimal tests:** regressions are likely unless a role matrix is tested manually.
11. **Generated/reference clutter:** agents can waste time on platform wrappers, backups, TODO files, and old docs.
12. **Sensitive diagnostic file:** `config/test_remote.php` should not remain in normal distributions.

---

## 15. Change playbooks for coding agents

### Adding a database field

1. Add a guarded migration when practical.
2. Update `database/capstone.sql` so fresh installs receive it.
3. Update web create/edit/read queries.
4. Update API create/edit/read endpoints.
5. Update Flutter service request/response mapping.
6. Update model or map consumers and all detail/list UI.
7. Add indexes if used in filters/joins.
8. Test old database compatibility only if that remains a requirement.

### Changing incident statuses

Search the entire project for every status string. At minimum update:

- DB/sample data/migrations
- Web handler `app/reports/update-status.php`
- API `api/update_status.php`
- Web report/health/dashboard/map filters and actions
- `functions.php` labels/badges/credited status list
- Flutter `status_labels.dart`, badges, filters, role action builders
- Dashboard and map API conditions
- Tests and documentation

### Changing role permissions

Update and verify:

- `app/includes/functions.php`
- Web page gates and mutation handlers
- API endpoint actor verification and scope checks
- `api/user_audit.php`
- Flutter `AuthService`
- Shell navigation/FAB visibility
- Direct-request tests; do not test only hidden buttons

### Adding a new API endpoint

- Prefer including `api_helper.php` instead of re-declaring common functions.
- Require the correct HTTP method.
- Authenticate the actor; do not trust a posted role.
- Derive municipality/barangay scope from the database actor.
- Use prepared statements.
- Return the standard envelope.
- Add a service method, loading/error handling, and tests.

### Modifying assistance calculations

Read all six `Minor_changes/` documents first. Define whether a number means pledged, incoming, sent/delivered, or confirmed received. Update web, API, dashboard, Flutter, and progress widgets together.

### Modifying maps/boundaries

- Preserve coordinate order: GeoJSON uses `[longitude, latitude]`; map objects use latitude/longitude objects.
- Check Kalibo and Ibajay assets separately.
- Test Polygon and MultiPolygon.
- Test barangay name normalization.
- Keep pin-outside validation a soft warning unless product requirements explicitly change.

---

## 16. Documentation status

The repository already contains `About_this_system.md` and `obilak-docs/*`, but parts are outdated. Notable corrections captured here:

- The web application accesses MySQL directly; it does not route all reads/writes through the REST API.
- The current schema has 16 tables, including assistance/profile/facility tables, not the older 12-table description.
- Update/delete endpoints for centers and hotlines are implemented; only certain endpoints such as `delete_alert.php` and `get_dashboard_counts.php` remain stubs.
- The system now contains Ibajay scope, MDR/PDRRMO sub-roles, Mayor/Governor observers, assistance ledger/receipt flows, road-access fields, population autofill, and pin-boundary flags.
- The full product is not entirely offline because weather and map tiles depend on external services in the current implementation.

Use this file as the current orientation guide, but always verify feature-specific claims against the named files before changing behavior.

---

## 17. Compact file-to-feature index

### Incidents

- Web pages: `public/create-incident-report.php`, `edit-incident-report.php`, `incident-reports.php`, `health-reports.php`
- Web handlers: `app/reports/*`
- API: `create_incident.php`, `update_incident.php`, `get_reports.php`, `update_status.php`, attachment/log endpoints
- Flutter: Barangay create/edit/reports; PCF review; PHO health reports; shared report widgets

### Dashboard/evidence/weather

- Web: `public/dashboard.php`
- API: `get_dashboard_summary.php`
- PHP weather: `app/includes/weather_helper.php`
- Flutter: dashboard role wrappers, `dashboard_summary_view.dart`, `evidence_card.dart`

### Maps

- Web: `public/map.php`
- API: `get_map_data.php`
- PHP boundary logic: lower part of `app/includes/functions.php`
- Flutter: `shared/map_view_screen.dart`, report coordinate map, create/edit forms

### Evacuation/assistance

- Web: center pages, `center-needs.php`, `assistance.php`
- Web handlers: `app/evacuation-centers/*`
- API: center CRUD, needs, board, pledge, status, receipt endpoints
- Flutter: role center screens and shared assistance/needs/add/edit screens
- Design specs: `Minor_changes/01` to `05`

### Alerts

- Web: `add-alert.php`, `alert.php`, `barangay-alerts.php`
- Web handler: `app/alerts/save-alert.php`
- API: alert save/list/read endpoints
- Flutter: Barangay alerts, PCF alerts/add alert, role shells

### Users/audit

- Web: `manage-users.php`, `user-activity.php`, `app/users/*`
- API: user CRUD/status/password/activity/population and `user_audit.php`
- Flutter: Superadmin Manage Users; embedded Barangay/PCF/PHO account-management screens

### UI/theme

- Web: `public/asset/css/style.css`, `app/includes/header.php`, `sidebar.php`
- Flutter: `main.dart`, `constants/app_colors.dart`, reusable widgets

---

## 18. Glossary

- **Barangay** — local reporting unit.
- **Chairman/Captain** — Barangay operational approver.
- **Secretary** — Barangay administrator with user/center duties.
- **BHERT/Tanod** — field reporter.
- **MDR/MDRRMO** — municipal disaster-risk reduction/coordination role; represented under `pcf`.
- **PCF** — legacy/internal role identifier for municipal coordination; code also contains old `pfc` compatibility aliases.
- **PHO** — provincial health/admin parent role.
- **PDRRMO** — provincial operational response sub-role under `pho`.
- **Mayor/Governor** — observer sub-roles; generally read-only but allowed to pledge assistance.
- **Evidence** — incident attachments and, in some dashboards, role-scoped monthly situational summaries.
- **Credited incident** — status qualifies an incident for center-related operational calculations.
- **Unmet need** — declared quantity not yet fulfilled according to the specific assistance calculation context.

---

## 19. Final agent checklist

Before coding:

- [ ] Identify whether the feature exists in web, API, and Flutter.
- [ ] Identify all affected roles and municipality scopes.
- [ ] Check the canonical schema and historical compatibility branches.
- [ ] Search exact status/sub-role strings repository-wide.
- [ ] Read the relevant `Minor_changes/` document.

Before finishing:

- [ ] Update both web and API/mobile implementations where applicable.
- [ ] Enforce authorization server-side, not only in UI.
- [ ] Use prepared SQL and preserve CSRF for web forms.
- [ ] Update `capstone.sql` plus a migration for schema changes.
- [ ] Run PHP syntax checks on changed PHP files.
- [ ] Run `flutter analyze` and `flutter test` for Flutter changes.
- [ ] Test at least one allowed and one forbidden actor per changed permission.
- [ ] Test Kalibo, Ibajay, and all-municipality behavior when relevant.
- [ ] Update this file when architecture, roles, schema, or workflows materially change.
