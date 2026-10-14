# OBILAK — API Reference

The web dashboard and the Flutter mobile app both talk to this PHP REST API
under `api/`. That directory holds **40 endpoint files** plus two shared helper
files (`api_helper.php`, `user_audit.php`). Every path below is relative to the
project root (e.g. `https://<host>/api/login.php`).

## Conventions

- **Base URL:** `https://<host>/api` (on XAMPP: `http://<server>/<project-folder>/api`).
- **Format:** requests send **JSON** in the body; responses are **JSON**. The one
  exception is `upload_incident_evidence.php`, which uses `multipart/form-data`.
- **Methods:** almost every endpoint is `POST`. `get_barangays.php` and
  `get_disaster_types.php` also accept `GET`.
- **CORS / preflight:** every endpoint answers `OPTIONS` with `200` and sends
  `Access-Control-Allow-Origin: *`. The only allowed request header is
  `Content-Type`.
- **Standard response envelope** (every endpoint):

```json
{
  "success": true,
  "message": "Human-readable message.",
  "data": {}
}
```

  On any error `success` is `false`, `message` explains why, and `data` is
  usually `[]`. Technical detail is only shown when `DEBUG_MODE` is `true`
  (`config/app_config.php`); otherwise it goes to the PHP error log.

- **Authentication:** there is **no token or session**. The caller's identity is
  passed in the request body (`user_id`, `acting_user_id`, `role`, …). Endpoints
  that matter re-derive the caller's real `role`/`sub_role`/`barangay_id` from
  the `users` table and never trust a client-supplied role. See *Known
  Limitations* in the README.
- **Two code styles:** some endpoints include `api_helper.php` and use its shared
  helpers (`db()`, `send_response()`, `read_json_input()`, `require_post()`,
  `table_exists()`, `column_exists()`, `is_readonly_role_api()`); others declare
  a local `send_response()` and their own header block. Behaviour is identical.
- **Shared helpers:** `api_helper.php` (response/DB/\JSON helpers) and
  `user_audit.php` (`valid_username()`, `username_rule_message()`,
  `is_readonly_role_api()`, `log_user_action()`, `verify_actor()`,
  `verify_superadmin()`, `count_active_superadmins()`). Neither is an endpoint.

## Roles & sub-roles

`users.role` is one of: `superadmin`, `pcf` (municipal / PCF), `pho`
(provincial / PHO), `barangay`. `users.sub_role` refines it:

| role | sub_role values | notes |
|------|-----------------|-------|
| `superadmin` | *(none)* | full access; manages all accounts |
| `barangay` | `captain`, `secretary`, `tanod` | `tanod` = BHERT field reporter |
| `pcf` | `mdr_admin`, `mdr_kalibo`, `mdr_ibajay`, `mayor_kalibo`, `mayor_ibajay` | `mayor_*` are **read-only observers** |
| `pho` | `pdrrmo`, `governor`, *(empty = PHO Admin)* | `governor` is a **read-only observer** |

**Read-only observers** are `mayor_kalibo` / `mayor_ibajay` (PCF) and
`governor` (PHO). They may view dashboards, alerts, reports and the assistance
board, but they cannot change report statuses, manage evacuation centers,
hotlines, needs or users, or publish alerts. On the assistance board they *can*
record pledges but cannot gain the provincial status override.

---

## Contents

1. [Authentication](#1-authentication)
2. [Incidents & Reports](#2-incidents--reports)
3. [Dashboard & Map](#3-dashboard--map)
4. [Evacuation Centers](#4-evacuation-centers)
5. [Hotlines](#5-hotlines)
6. [Alerts](#6-alerts)
7. [Needs & Assistance](#7-needs--assistance)
8. [Users & Admin](#8-users--admin)
9. [Municipalities & Population](#9-municipalities--population)
10. [Lookups](#10-lookups)
11. [Reserved (next phase)](#11-reserved-next-phase)

---

## 1. Authentication

### `POST /login.php`
Log a user in. Role `pfc` is normalised to `pcf` in the response.

**Request**
```json
{ "username": "andagaw", "password": "admin123" }
```

**Response**
```json
{
  "success": true,
  "message": "Login successful.",
  "data": {
    "id": 4,
    "name": "Andagaw Barangay Account",
    "username": "andagaw",
    "role": "barangay",
    "sub_role": "captain",
    "can_manage_users": true,
    "barangay_id": 1,
    "barangay_name": "Andagaw",
    "municipality": "Ibajay",
    "population": 1200
  }
}
```
- Only **bcrypt-verified** passwords are accepted (the old plain-text fallback
  was removed).
- Inactive accounts return `success: false` ("This account is inactive."); wrong
  credentials return the generic "Invalid username or password." (no DB error is
  leaked).
- `barangay_id`, `barangay_name`, `municipality` are `null` and `population` is
  `0` for non-barangay accounts.

---

## 2. Incidents & Reports

### `POST /create_incident.php`
Submit a new incident report. **Active `barangay` accounts only.**

**Request**
```json
{
  "user_id": 4,
  "barangay_id": 1,
  "disaster_type": "Fire",
  "incident_datetime": "2026-06-02 20:57:00",
  "evacuation_needed": "Yes",
  "evacuation_center_id": 7,
  "description": "House fire near the market.",
  "exact_location": "Purok 2, near the plaza",
  "assistance_needed": "Ambulance, Food Packs",
  "latitude": 11.7042760,
  "longitude": 122.3756190,
  "affected_people": 1,
  "injured": 1,
  "dead": 0,
  "missing": 0,
  "evac_households": 3,
  "evac_adults": 5,
  "evac_children": 2,
  "evac_members": 7,
  "road_status": "Partially Passable",
  "road_blockage_causes": "Fallen tree",
  "road_location": "National Road, Purok 15",
  "client_uuid": "3f1b0c8e-1c2a-4c3b-9c8e-2f7a6d5b1a90"
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `user_id`, `barangay_id` | yes | active barangay account |
| `disaster_type`, `description` | yes | |
| `incident_datetime` | no | defaults to now |
| `evacuation_needed` | no | `Yes`/`No`; clears `evacuation_center_id` when not `Yes` |
| `evacuation_center_id` | no | numeric |
| `latitude` / `longitude` | no | numeric and in range when present |
| `affected_people`, `injured`, `dead`, `missing`, `evac_*` | no | non-negative integers |
| `road_status` | no | `Passable` (default), `Partially Passable`, `Obstructed` |
| `road_blockage_causes`, `road_location` | no | causes are only stored when status ≠ `Passable` |
| `client_uuid` | no | RFC-4122 UUID; enables safe offline retries |

**Response**
```json
{
  "success": true,
  "message": "Incident report created successfully.",
  "data": {
    "incident_id": 39,
    "status": "Pending",
    "latitude": 11.7042760,
    "longitude": 122.3756190,
    "exact_location": "Purok 2, near the plaza",
    "assistance_needed": "Ambulance, Food Packs",
    "pin_outside_area": 0
  }
}
```
- New reports always start as `Pending`; an initial `Pending` row is written to
  `incident_status_logs`.
- **Idempotency:** if `client_uuid` was already accepted, the endpoint returns
  the existing report with `"already_exists": true` instead of inserting a
  duplicate (and a duplicate log). A UUID already claimed by *another* account is
  rejected.
- `pin_outside_area` is a soft flag (`1` when the saved pin falls outside the
  reporting barangay's boundary).

---

### `POST /get_reports.php`
List incident reports, scoped by role. Also powers the Governor/Mayor evidence
drill-downs.

**Request**
```json
{ "role": "barangay", "barangay_id": 1,
  "month": 6, "year": 2026, "disaster_type": "", "municipality": "" }
```

| Field | Notes |
|-------|-------|
| `role` | `barangay`, `pcf`, `pho`, `superadmin` |
| `barangay_id` | required for `barangay`; optional per-barangay drill within Mayor scope |
| `user_id` | used to derive sub-role scope from the DB |
| `municipality` | admin filter; **overridden** by MDR/Mayor sub-role |
| `month`, `year` | required when `governor_scope`/`mayor_scope` is set |
| `disaster_type` | used with evidence scopes; `Others` is the catch-all bucket |
| `governor_scope` | `true` → province-wide, all non-dismissed (Governor only) |
| `mayor_scope` | `true` → own municipality, all non-dismissed (Mayor only) |

- `barangay` → only that barangay's reports; when `user_id` is supplied it also
  filters to that reporter (BHERT "My Reports").
- `pcf` → the municipal workflow statuses (`Forwarded to PCF`,
  `Under MDR Review`, `Verified`, `Responding`, `Referred to PHO`,
  `Under PHO Review`, `Resolved`, `Dismissed`).
- `pho` → referred reports (`referred_to_pho = 1` or status `Referred to PHO`,
  `Under PHO Review`, `Forwarded to PHO`).
- MDR/Mayor sub-roles force `municipality` to Kalibo/Ibajay (DB-derived, never
  trusted from the client).

**Response** (`data` is an array)
```json
{
  "success": true,
  "message": "Reports loaded successfully.",
  "data": [
    {
      "id": 38, "user_id": 4, "barangay_id": 1, "barangay_name": "Andagaw",
      "municipality": "Ibajay", "creator_name": "Andagaw Barangay Account",
      "disaster_type": "Fire", "evacuation_needed": "Yes",
      "evacuation_center_id": 7, "evacuation_center_name": "Aklan State University",
      "evac_households": 3, "evac_adults": 5, "evac_children": 2, "evac_members": 7,
      "incident_datetime": "2026-06-02 20:57:00",
      "assistance_needed": "Ambulance, Food Packs",
      "description": "...", "exact_location": "Purok 2",
      "latitude": "11.7042760", "longitude": "122.3756190",
      "road_status": "Partially Passable", "road_blockage_causes": "Fallen tree",
      "road_location": "National Road",
      "affected_people": 1, "injured": 1, "dead": 0, "missing": 0,
      "status": "Pending", "referred_to_pho": 0, "created_at": "2026-06-02 12:57:49"
    }
  ]
}
```

---

### `POST /update_incident.php`
Edit an existing report. **Active `barangay` accounts only**, and only while the
report is still `Pending` and belongs to the actor's own barangay. Only the
report's original reporter or the Barangay Chairman may edit it.

**Request** — the same fields as `create_incident.php` plus `report_id`.
`barangay_id` is accepted for compatibility but **ignored**; ownership is taken
from the actor's registered barangay.
```json
{ "report_id": 38, "user_id": 4, "disaster_type": "Fire",
  "description": "Updated details", "...": "…" }
```

**Response**
```json
{ "success": true, "message": "Incident report updated successfully.",
  "data": { "report_id": 38, "status": "Pending", "pin_outside_area": 0 } }
```
Returns an error if the report is already being processed.

---

### `POST /update_status.php`
Move a report through its workflow and log the change in
`incident_status_logs`. The real role is looked up from `user_id`; a
client-supplied role is ignored.

**Request**
```json
{
  "report_id": 38,
  "user_id": 3,
  "status": "Verified",
  "remarks": "Confirmed with barangay.",
  "referred_to_pho": 0
}
```

**Allowed statuses** (legacy `Forwarded to PHO` is normalised to
`Referred to PHO`):

`Pending`, `Reviewed`, `Forwarded to PCF`, `Under MDR Review`, `Verified`,
`Responding`, `Referred to PHO`, `Under PHO Review`, `Resolved`, `Dismissed`.

**Role rules**
- Roles that may change status: `pcf`, `pho`, `barangay`. Read-only observers
  (mayors, Governor) are blocked.
- `barangay` → **only `captain`**, and only to `Reviewed`, `Forwarded to PCF`,
  or `Dismissed`.
- `pcf` review gate: a report at `Forwarded to PCF` must first be acknowledged
  as `Under MDR Review` before any other municipal action.
- `pho` review gate: mirrors it — a `Referred to PHO` report must first become
  `Under PHO Review`.
- Setting `Referred to PHO` also sets `referred_to_pho = 1`.

**Response**
```json
{ "success": true, "message": "Report status updated successfully.",
  "data": { "report_id": 38, "status": "Verified", "referred_to_pho": 0 } }
```

---

### `POST /get_report_attachments.php`
List photo/video evidence for a report.

**Request**
```json
{ "report_id": 38 }
```

**Response** (`data` is an array)
```json
{
  "success": true, "message": "Evidence loaded successfully.",
  "data": [
    {
      "id": 5, "file_name": "photo.jpg",
      "file_path": "https://res.cloudinary.com/dhaszqaju/image/upload/.../photo.jpg",
      "file_url": "https://res.cloudinary.com/dhaszqaju/image/upload/.../photo.jpg",
      "file_type": "photo", "file_size": 581522,
      "created_at": "2026-06-02 12:57:49"
    }
  ]
}
```
- `file_path` is either a full **Cloudinary URL** (production) or a
  project-relative `uploads/...` path (local-disk fallback). `file_url` passes
  full URLs through unchanged; otherwise it builds an absolute URL.

---

### `POST /get_report_logs.php`
Get the status-change timeline for a report.

**Request**
```json
{ "report_id": 38 }
```

**Response** (`data` is an array)
```json
{
  "success": true, "message": "Status timeline loaded.",
  "data": [
    {
      "id": 72, "old_status": null, "new_status": "Pending",
      "remarks": "Report submitted from mobile app.",
      "user_id": 4, "user_name": "Andagaw Barangay Account",
      "user_role": "barangay", "created_at": "2026-06-02 12:57:49"
    }
  ]
}
```

---

### `POST /upload_incident_evidence.php`
Upload evidence for a report. **This endpoint uses `multipart/form-data`, not
JSON.** Files are stored via Cloudinary, falling back to local disk when
Cloudinary is not configured.

**Form fields**
| Field | Type | Notes |
|-------|------|-------|
| `incident_report_id` | text | Required |
| `uploaded_by` | text | Required user id |
| `evidence_files[]` | file(s) | Photos / videos |

**Rules**
- Accepted extensions: `jpg`, `jpeg`, `png`, `gif`, `webp`, `heic` → photo;
  `mp4`, `mov`, `avi`, `mkv`, `webm`, `3gp` → video. The real content type is
  verified too, not just the extension.
- Limits come from `config/app_config.php`: **max 10 MB per photo, 50 MB per
  video, and 1 photo + 1 video per report**.
- Files are stored under the folder
  `Ugyon/upload_incident_evidence/report_<id>/` with an unpredictable filename.
- There is no session check; `uploaded_by` must be an existing user and the
  report must exist.

**Response**
```json
{
  "success": true, "message": "Evidence upload completed.",
  "data": {
    "uploaded": [
      { "file_name": "photo.jpg", "file_path": "https://res.cloudinary.com/.../photo.jpg",
        "file_url": "https://res.cloudinary.com/.../photo.jpg",
        "file_type": "photo", "file_size": 12345 }
    ],
    "rejected": [
      { "file_name": "big.mov", "reason": "File is too large (max 50 MB)." }
    ]
  }
}
```

---

## 3. Dashboard & Map

### `POST /get_dashboard_summary.php`
All dashboard numbers and charts for a scope and month/year, plus role-specific
extras.

**Request**
```json
{ "role": "pho", "barangay_id": null, "month": 6, "year": 2026,
  "sub_role": "governor", "user_id": 3, "municipality": "" }
```
- `barangay_id` is required for the `barangay` role; others see their scope.
- `sub_role`/`user_id`/`municipality` refine the scope (BHERT self-scope,
  Secretary evac list, MDR/Mayor municipality override, Governor province-wide).

**Response (`data`)** — key fields:
```json
{
  "scope_label": "All Barangays", "month": 6, "year": 2026,
  "note": "Dismissed reports are excluded.",
  "total_reports": 1, "pending": 1, "forwarded_to_pho": 0, "evacuation_centers": 7,
  "status_summary": [ { "label": "Pending", "count": 1 } ],
  "impact": { "affected": 1, "injured": 1, "dead": 0, "missing": 0 },
  "daily_trend": [ { "day": 1, "count": 0 }, { "day": 2, "count": 1 } ],
  "disaster_summary": [ { "label": "Fire", "abbr": "FIRE", "count": 1 } ],
  "sub_role": "governor",
  "evac_centers_list": [ { "name": "…", "status": "Open", "capacity": 500 } ],
  "my_reports": 0,
  "unmet_needs": 0, "incoming_pledges": 0, "my_pledges": 0, "zero_pledge_count": 0,
  "province_evidence": null, "municipality_evidence": null,
  "weather": {
    "available": true, "stale": false, "updated_at": "2026-06-16 18:30",
    "current": { "temp": 30, "feels_like": 34, "humidity": 78,
                 "wind": 12, "condition": "Partly cloudy", "emoji": "⛅" },
    "days": [ { "date": "2026-06-16", "label": "Today", "emoji": "🌦️",
                "condition": "Light rain", "temp_max": 31, "temp_min": 25,
                "rain_chance": 60 } ],
    "alert": { "level": "watch", "message": "Rainy and windy today." }
  }
}
```
- `daily_trend[].day` is a **day number**; `status_summary[].label` and
  `disaster_summary[].label`/`.abbr` carry the display text.
- `evac_centers_list` is populated for Secretary accounts, `my_reports` for
  BHERT (`tanod`), and the needs/pledge counters plus
  `province_evidence`/`municipality_evidence` for PHO/PCF/superadmin.
- Weather comes from Open-Meteo; `weather.available` is `false` (or
  `stale: true` with the last saved reading) when the server is offline.

---

### `POST /get_map_data.php`
Everything the map needs: barangay halls, evacuation centers, primary-care
facilities, and incident pins.

**Request**
```json
{ "role": "pho", "barangay_id": null, "user_id": null, "municipality": "" }
```

**Response (`data`)**
```json
{
  "barangay_halls": [ { "id": 1, "name": "Andagaw", "municipality": "Ibajay",
      "latitude": 11.704, "longitude": 122.375 } ],
  "evacuation_centers": [ { "id": 1, "barangay": "Buswang Old",
      "center_name": "Saint Gabriel College", "center_type": "School / Institution",
      "status": "Available", "latitude": 11.715, "longitude": 122.375 } ],
  "pcf_facilities": [ { "id": 1, "name": "Kalibo RHU", "municipality": "Kalibo",
      "latitude": 11.706, "longitude": 122.368 } ],
  "incidents": [ { "id": 38, "barangay_id": 1, "barangay_name": "Andagaw",
      "municipality": "Ibajay", "disaster_type": "Fire", "status": "Pending",
      "referred_to_pho": 0, "latitude": 11.704, "longitude": 122.375,
      "created_at": "2026-06-02 12:57:49" } ]
}
```
- Incident pins are scoped by role; MDR sub-roles force their municipality from
  the DB.

---

## 4. Evacuation Centers

### `POST /get_evacuation_centers.php`
List evacuation centers, optionally filtered.

**Request**
```json
{ "role": "barangay", "barangay_name": "Poblacion", "barangay_id": 0,
  "search": "", "municipality": "" }
```
- The `barangay` role filters by `barangay_name` (scoped to `barangay_id`'s
  municipality); admin roles may filter by `municipality`; `search` matches
  name / barangay / status / type.

**Response:** `data` is an array of center objects with columns `id, barangay,
municipality, center_name, center_type, capacity, current_evacuees, status,
contact_person, contact_number, latitude, longitude, created_at`.

### `POST /save_evacuation_center.php`
Create a new evacuation center. **superadmin / pho / pcf**, plus `barangay`
**captain/secretary** for their own barangay. Read-only mayors/Governor are
blocked.

**Request**
```json
{
  "acting_user_id": 4, "barangay": "Andagaw", "barangay_id": 1,
  "center_name": "Aklan State University", "center_type": "School",
  "capacity": 500, "current_evacuees": 0, "status": "Available",
  "contact_person": "Juan Dela Cruz", "contact_number": "09171234567",
  "latitude": 11.702677021, "longitude": 122.375857875
}
```
- `capacity`/`current_evacuees` must be non-negative numbers; `contact_number`
  must contain a digit; lat/lng must be in range when present. MDR sub-roles may
  only add centers in their municipality.

**Response**
```json
{ "success": true, "message": "Evacuation center saved successfully.",
  "data": { "id": 8 } }
```

### `POST /update_evacuation_center.php`
Update a center. Same role rules as `save_evacuation_center.php`. `status` is
coerced to `Available` if it is not one of `Available`, `Open`, `Full`,
`Closed`, `Needs Supplies`.

**Request** — `id` plus the same fields as save.
**Response** — `{ "data": { "id": 8 } }`

### `POST /delete_evacuation_center.php`
Delete a center. Same role rules; barangay captain/secretary are scoped to their
own barangay, MDR to their municipality.

**Request**
```json
{ "acting_user_id": 1, "id": 8 }
```
**Response** — `{ "message": "Evacuation center deleted successfully." }`

---

## 5. Hotlines

### `POST /get_hotlines.php`
List active emergency hotlines, optionally filtered.

**Request**
```json
{ "role": "barangay", "barangay_id": 13, "category": "", "search": "", "municipality": "" }
```
- The `barangay` role sees municipal-scope hotlines plus its own barangay's;
  admin roles may filter by `municipality`; `category` may be a scope
  (`barangay`/`municipal`) or a category substring.

**Response:** `data` is an array with `id, hotline_scope, barangay_id,
barangay_name, office_name, municipality, category, telephone_numbers,
cellphone_numbers, hotline_number, remarks, status`.

### `POST /save_hotline.php`
Create a new hotline. **superadmin / pcf / pho**; read-only mayors/Governor are
blocked.

**Request**
```json
{
  "acting_user_id": 1, "hotline_scope": "Barangay", "barangay_id": 13,
  "office_name": "Kalibo PNP", "municipality": "Kalibo", "category": "PNP",
  "telephone_numbers": "268-2166", "cellphone_numbers": "0939-916-7066",
  "hotline_number": "166", "remarks": "", "status": "Active"
}
```
- `office_name` is required; at least one of the three number fields is
  required; `barangay_id` is nulled unless `hotline_scope` is `Barangay`.

**Response** — `{ "data": { "id": 22 } }`

### `POST /update_hotline.php`
Update a hotline. Same roles as save.

**Request** — `id` plus the same fields as save.
**Response** — `{ "data": { "id": 22 } }`

### `POST /delete_hotline.php`
Delete a hotline. Same roles as save.

**Request**
```json
{ "acting_user_id": 1, "id": 22 }
```
**Response** — `{ "message": "Hotline deleted successfully." }`

---

## 6. Alerts

### `POST /get_alerts.php`
List alerts visible to the caller.

**Request**
```json
{ "role": "barangay", "barangay_id": 1, "user_id": 4, "search": "" }
```

**Response** — `data` is an array of alert objects:
```json
{
  "id": 15, "title": "Flood Advisory", "alert_type": "Flood", "severity": "Moderate",
  "message": "Rising water along the river.", "instructions": "Prepare to evacuate.",
  "status": "Active", "start_datetime": "2026-06-02 20:21:00",
  "end_datetime": "2026-06-05 20:21:00", "validity_status": "Active",
  "created_by": 1, "created_by_name": "PDRRMO Admin", "created_by_role": "pho",
  "target_type": "all", "target_label": "All Barangays", "is_read": 0,
  "created_at": "2026-06-02 20:21:00"
}
```
- `validity_status` is `Active`, `Upcoming`, or `Expired` (computed from the
  start/end datetimes); `is_read` is per-user when `user_id` is supplied.

### `POST /save_alert.php`
Create (broadcast) a new alert. **Only an Active `pcf` or `pho` account may
publish** — read-only mayors/Governor are blocked, and `superadmin` is not
permitted by this endpoint either.

**Request**
```json
{
  "title": "Flood Advisory", "alert_type": "Flood", "severity": "Moderate",
  "message": "Rising water along the river.", "instructions": "Prepare to evacuate.",
  "start_datetime": "2026-06-02 20:21:00", "end_datetime": "2026-06-05 20:21:00",
  "target_type": "selected", "barangay_ids": [1, 2], "created_by": 1
}
```
- `target_type`: `all` (every barangay) or `selected` (use `barangay_ids`).
  Sending any `barangay_ids` forces `selected`; an empty `selected` set is
  rejected.
- MDR/mayor sub-roles may only target barangays in their own municipality
  (DB-derived).

**Response**
```json
{ "success": true, "message": "Alert created successfully.",
  "data": { "alert_id": 15, "target_type": "selected",
            "barangay_ids": [1, 2], "created_by": 1 } }
```

### `POST /get_unread_alert_count.php`
Unread alert count for a user (notification badge).

**Request** — `{ "user_id": 4, "barangay_id": 1 }`
**Response** — `{ "data": { "count": 2 } }`

### `POST /mark_alerts_read.php`
Mark one or more alerts as read for a user.

**Request** — `{ "user_id": 4, "barangay_id": 1, "alert_ids": [15, 16] }`
**Response** — `{ "data": { "count": 2 } }`

---

## 7. Needs & Assistance

The relief-coordination module. Supply only counts toward a need once the
receiving barangay **confirms receipt** (`received_at` set); `Pledged`, `Sent`
and `Delivered` are shown as incoming / awaiting confirmation.

### `POST /get_assistance_board.php`
The whole board: centers with occupant profiles, needs, the pledge ledger, and a
summary.

**Request** — `{ "acting_user_id": 1, "municipality": "" }`
- **superadmin / pho / pcf** may view — all sub-roles, including read-only
  mayors/Governor — and all of them may pledge (`can_pledge: true`).
- MDR/mayor sub-roles are forced to their municipality.

**Response (`data`)** — `scope_label`, `can_pledge`, `zero_pledge_centers[]`,
`centers[]` (each with `profile`, `types`, `needs[]`, `ledger[]`, `incident`),
and `summary` (`unmet_total`, `incoming_total`, `pending_confirmation_total`,
`pledge_count`, `my_pledges`, `zero_pledge_count`).
- Each `need` has `id`, `item`, `unit`, `qty_needed`, `received_qty`,
  `pending_qty`, `incoming_qty`, `unmet`, `fulfilled`.
- Each `ledger` row has `id`, `donor_label`, `item`, `unit`, `qty`,
  `qty_received`, `status`, `can_manage_status`, `over_pledge`, and the
  `pledged_at`/`sent_at`/`delivered_at`/`received_at` timestamps.

### `POST /get_center_needs.php`
Full detail for one center.

**Request** — `{ "acting_user_id": 1, "evac_center_id": 7 }`
- **superadmin / pho / pcf**, plus `barangay` **captain/secretary** for their own
  barangay. MDR scoped to their municipality.

**Response (`data`)** — `center`, `profile`, `computed_headcount`, `needs[]`,
`fulfillment[]`, `ledger[]`, `incident`.

### `POST /save_center_needs.php`
Upsert a center's occupant profile and needed-supplies list. **superadmin / pho /
pcf**, plus `barangay` **captain/secretary** for their own barangay; read-only
observers are blocked.

**Request**
```json
{
  "acting_user_id": 4, "evac_center_id": 7, "profile_source": "manual",
  "total_evacuees": 120, "families": 30, "pregnant": 2, "lactating_mothers": 4,
  "infants": 6, "children": 40, "older_persons": 10, "pwd": 3, "sick": 2, "injured": 0,
  "items": [ { "item": "Rice", "qty": 50, "unit": "sacks" },
             { "item": "Water", "qty": 100, "unit": "liters" } ]
}
```
- `profile_source` is `manual` (default) or `computed` (only when the user
  explicitly used the reported totals).
- Units: `packs`, `sacks`, `boxes`, `liters`, `pcs`, `kits` (default `pcs`).
  Items with no name or qty ≤ 0 are skipped. Items are upserted by name so
  existing pledge links are preserved; only genuinely removed items are deleted.

**Response** — `{ "data": { "evac_center_id": 7 } }`

### `POST /pledge_assistance.php`
Record a pledge. **superadmin / pho / pcf** (read-only mayors/Governor included —
they may pledge).

**Request**
```json
{ "acting_user_id": 1, "evac_center_id": 7, "need_id": 12,
  "item": "Rice", "unit": "sacks", "qty": 20, "remarks": "From PDRRMO stock" }
```
- `need_id` must belong to the center, otherwise it is cleared. Over-pledging is
  allowed but flagged (`over_pledge`).
- MDR/mayor sub-roles may only pledge to centers in their own municipality.

**Response** — `{ "data": { "id": 45, "over_pledge": false } }`

### `POST /update_assistance_status.php`
Advance a donation. **superadmin / pho / pcf**; only the donor, or a provincial
override (superadmin or PHO Admin/PDRRMO — **not** the Governor), may act.

**Request** — `{ "acting_user_id": 1, "assistance_id": 45, "action": "send" }`
- `action`: `send` (Pledged → Sent) or `deliver` (→ Delivered). Timestamps are
  set once so a re-submit cannot rewrite history.
- MDR/mayor sub-roles are scoped to their municipality.

**Response** — `{ "data": { "id": 45 } }`

### `POST /confirm_assistance_received.php`
The receiving barangay confirms delivery. **Only `barangay` captain/secretary**,
and only for their own barangay.

**Request** — `{ "acting_user_id": 4, "assistance_id": 45, "qty_received": 18 }`
- The donation must be `Delivered` and not yet confirmed; `qty_received` must be
  between 1 and the donor's declared qty. Double-confirm is guarded at the SQL
  level.

**Response** — `{ "data": { "id": 45, "qty_received": 18 } }`

---

## 8. Users & Admin

Manage accounts and read the audit trail. The acting admin is identified by
`acting_user_id`; every change is written to `user_activity_logs`. Scope is
enforced per role (superadmin sees all; PHO Admin sees PHO accounts; PCF MDR sees
its sub-scope; barangay admins see their own barangay).

> Usernames must match `^[A-Za-z0-9._-]{3,50}$` (letters, numbers, dot,
> underscore, hyphen — no spaces). Passwords must be at least 6 characters.

### `POST /get_users.php`
List user accounts (no password hashes returned). Requires a valid
`acting_user_id` (`verify_actor`).

```json
{ "acting_user_id": 1, "search": "" }
```
`data` is an array of users: `id, name, username, role, sub_role,
can_manage_users, status, barangay_id, barangay_name, created_at`.

### `POST /save_user.php`
Create a new account. Requires a valid admin actor; read-only mayors/Governor are
blocked.

```json
{ "acting_user_id": 1, "name": "Pook Barangay Account", "username": "pook",
  "password": "admin123", "role": "barangay", "barangay_id": 14, "sub_role": "secretary" }
```
- **superadmin** may create any role; validates role/sub-role, requires a
  barangay for `barangay`, and defaults new PHO accounts to PHO Admin.
- **pcf (MDR Admin)** creates PCF accounts and may create mayors; MDR-Kalibo and
  MDR-Ibajay may only create their own sub-role.
- **pho (PHO Admin)** creates `pdrrmo`/`governor` accounts.
- **barangay** creates its own barangay's `captain`/`secretary`/`tanod`;
  secretaries may only create `tanod`; only one Chairman per barangay.

**Response** — `{ "data": { "id": 20 } }`

### `POST /update_user.php`
Edit an account (no password change here). Same actor/scope rules.

```json
{ "acting_user_id": 1, "user_id": 20, "name": "Pook BLGU",
  "username": "pook", "role": "barangay", "barangay_id": 14, "sub_role": "secretary" }
```
- Guards: cannot change your own role/sub-role; cannot remove the last active
  Super Admin; secretaries cannot edit Chairman accounts; only the MDR Admin
  manages Mayor accounts.

**Response** — `{ "message": "User updated successfully." }`

### `POST /reset_user_password.php`
Set a new password (≥ 6 characters). Same scope rules.

```json
{ "acting_user_id": 1, "user_id": 20, "password": "newPass123" }
```
**Response** — `{ "message": "Password reset successfully." }`

### `POST /toggle_user_status.php`
Activate / deactivate an account (flips the current status).

```json
{ "acting_user_id": 1, "user_id": 20 }
```
- Guards: cannot deactivate your own account; cannot deactivate the last active
  Super Admin.

**Response** — `{ "message": "Account is now Inactive.", "data": { "status": "Inactive" } }`

### `POST /get_user_activity.php`
Read the audit trail. **superadmin or PHO** (PHO sees only provincial activity).
Returns the latest 300 entries.

```json
{ "acting_user_id": 1 }
```
`data` is an array of `user_activity_logs`: `id, actor_name, action,
target_username, details, created_at`.

### `user_audit.php` *(helper — not an endpoint)*
Shared helpers for user management: `valid_username()`,
`username_rule_message()`, `is_readonly_role_api()`, `log_user_action()`,
`verify_actor()`, `verify_superadmin()`, `count_active_superadmins()`.

---

## 9. Municipalities & Population

### `POST /get_municipalities.php`
List the distinct municipalities (for dropdowns). No JSON input required.

**Response** — `data` is an array of strings:
```json
{ "success": true, "message": "Municipalities loaded.",
  "data": ["Ibajay", "Kalibo", "Malay"] }
```

### `POST /update_barangay_population.php`
Set a barangay's population. Uses `verify_actor` (`user_audit.php`).

```json
{ "acting_user_id": 1, "barangay_id": 17, "population": 1200 }
```
- **superadmin** may target any barangay; `barangay` **captain/secretary** only
  their own.
- `population` must be a whole number (digits only) ≤ 5,000,000.

**Response** — `{ "data": { "barangay_id": 17, "population": 1200 } }`

---

## 10. Lookups

### `GET|POST /get_barangays.php`
List active barangays (for dropdowns). Optional `acting_user_id` scopes the list
to the acting MDR/Mayor account's municipality (`mdr_kalibo`/`mayor_kalibo` →
Kalibo, `mdr_ibajay`/`mayor_ibajay` → Ibajay). The response echoes the resolved
scope (`null` = all).
```json
{ "success": true, "message": "Barangays loaded successfully.", "scope": "Ibajay",
  "data": [ { "id": 17, "name": "Andagaw", "municipality": "Ibajay", "population": 1200 } ] }
```

### `GET|POST /get_disaster_types.php`
List active disaster types (for dropdowns), including the `is_natural` flag.
```json
{ "success": true, "message": "Disaster types loaded successfully.",
  "data": [ { "id": 1, "name": "Typhoon", "status": "Active", "is_natural": 1 } ] }
```

---

## 11. Reserved (next phase)

These endpoint files exist as placeholders and currently return
`success: false` with the message *"This endpoint is reserved for the next
phase."* They are **not implemented yet**:

- `get_dashboard_counts.php`
- `delete_alert.php`
