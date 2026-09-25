# OBILAK — API Reference

The web dashboard and mobile app both talk to this PHP REST API
(`web/api/*.php`).

## Conventions

- **Base URL:** `http://<server>/<project-folder>/api`
- **Format:** requests send **JSON** in the body; responses are **JSON**.
- **Methods:** most endpoints are `POST`. An `OPTIONS` preflight is always
  answered with `200` (CORS is open: `Access-Control-Allow-Origin: *`).
- **Standard response envelope** (every endpoint):

```json
{
  "success": true,
  "message": "Human-readable message.",
  "data": {}
}
```

- On any error, `success` is `false`, `message` explains why, and `data` is
  usually `[]`.
- **Authentication:** there is no token yet. The caller's identity is passed in
  the request body (`user_id`, `role`, `acting_user_id`, etc.). See *Known
  Limitations* in the README.
- **Shared helper:** `api_helper.php` provides the JSON headers, DB connection,
  `send_response()`, `read_json_input()`, and table/column checks. It is
  included by the endpoints — it is **not** an endpoint itself.

---

## Contents

1. [Authentication](#1-authentication)
2. [Incidents & Reports](#2-incidents--reports)
3. [Dashboard & Map](#3-dashboard--map)
4. [Evacuation Centers](#4-evacuation-centers)
5. [Hotlines](#5-hotlines)
6. [Alerts](#6-alerts)
7. [Users & Admin](#7-users--admin)
8. [Lookups](#8-lookups)
9. [Reserved (next phase)](#9-reserved-next-phase)

---

## 1. Authentication

### `POST /login.php`
Log a user in.

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
    "barangay_id": 1,
    "barangay_name": "Andagaw"
  }
}
```

Inactive accounts and wrong credentials return `success: false`.

---

## 2. Incidents & Reports

### `POST /create_incident.php`
Submit a new incident report (barangay accounts).

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
  "assistance_needed": "Ambulance, Food Packs",
  "latitude": 11.7042760,
  "longitude": 122.3756190,
  "affected_people": 1,
  "injured": 1,
  "dead": 0,
  "missing": 0
}
```

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
    "assistance_needed": "Ambulance, Food Packs"
  }
}
```

`disaster_type` and `description` are required. New reports start as `Pending`.

---

### `POST /get_reports.php`
List incident reports, scoped by role.

**Request**
```json
{ "role": "barangay", "barangay_id": 1 }
```
- For `barangay`, `barangay_id` is required (returns only that barangay's
  reports). PHO/PCF/superadmin see all reports.

**Response** (`data` is an array)
```json
{
  "success": true,
  "message": "Reports loaded successfully.",
  "data": [
    {
      "id": 38, "user_id": 4, "barangay_id": 1, "barangay_name": "Andagaw",
      "disaster_type": "Fire", "evacuation_needed": "Yes",
      "evacuation_center_id": 7, "evacuation_center_name": "Aklan State University",
      "incident_datetime": "2026-06-02 20:57:00",
      "assistance_needed": "Ambulance, Food Packs",
      "description": "...", "latitude": "11.7042760", "longitude": "122.3756190",
      "affected_people": 1, "injured": 1, "dead": 1, "missing": 1,
      "status": "Pending", "referred_to_pho": 0, "created_at": "2026-06-02 12:57:49"
    }
  ]
}
```

---

### `POST /update_incident.php`
Edit an existing report. **Only allowed while the report is still `Pending`**,
and only by the owning barangay.

**Request** — same fields as `create_incident.php`, plus `report_id`:
```json
{ "report_id": 38, "user_id": 4, "barangay_id": 1, "disaster_type": "Fire",
  "description": "Updated details", "...": "…" }
```

**Response**
```json
{ "success": true, "message": "Incident report updated successfully.",
  "data": { "report_id": 38, "status": "Pending" } }
```
Returns an error if the report is already being processed.

---

### `POST /update_status.php`
Change a report's status (coordinators / PHO). Also logs the change in
`incident_status_logs`.

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
Valid statuses: `Pending`, `Verified`, `Responding`, `Referred to PHO`,
`Resolved`, `Dismissed`.

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
      "id": 5, "file_name": "scaled_ccslogo.jpg",
      "file_path": "uploads/incidents/report_38/photo_..._scaled_ccslogo.jpg",
      "file_url": "http://<server>/<project>/uploads/incidents/report_38/...",
      "file_type": "photo", "file_size": 581522,
      "created_at": "2026-06-02 12:57:49"
    }
  ]
}
```

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
Upload one or more photos/videos for a report. **This endpoint uses
`multipart/form-data`, not JSON.**

**Form fields**
| Field | Type | Notes |
|-------|------|-------|
| `incident_report_id` | text | Required |
| `uploaded_by` | text | User id, required |
| `evidence_files[]` | file(s) | One or more; photos/videos; max **25 MB** each |

Files are validated by type and content; the folder
`uploads/incidents/report_<id>/` is created automatically.

**Response**
```json
{
  "success": true, "message": "Evidence upload completed.",
  "data": {
    "uploaded": [
      { "file_name": "photo.jpg", "file_path": "uploads/incidents/report_39/...",
        "file_url": "http://<server>/...", "file_type": "photo", "file_size": 12345 }
    ],
    "rejected": [
      { "file_name": "big.mov", "reason": "File is too large (max 25 MB)." }
    ]
  }
}
```

---

## 3. Dashboard & Map

### `POST /get_dashboard_summary.php`
All dashboard numbers and charts for a scope and month/year.

**Request**
```json
{ "role": "pho", "barangay_id": null, "month": 6, "year": 2026 }
```
- `barangay` role is scoped to its own `barangay_id`; others see everything.
- `month`/`year` filter the time-based charts.

**Response (`data`)** includes:
```json
{
  "scope_label": "All Barangays",
  "month": 6, "year": 2026, "note": "…",
  "total_reports": 1, "pending": 1, "forwarded_to_pho": 0,
  "evacuation_centers": 7,
  "status_summary": [ { "status": "Pending", "count": 1 } ],
  "impact": { "affected_people": 1, "injured": 1, "dead": 1, "missing": 1 },
  "daily_trend": [ { "day": "2026-06-02", "count": 1 } ],
  "disaster_summary": [ { "disaster_type": "Fire", "count": 1 } ],
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
If the server has no internet, `weather.available` is `false` (or `stale: true`
with the last saved reading).

---

### `POST /get_map_data.php`
Everything the map needs: barangay halls, evacuation centers, and incident pins.

**Request**
```json
{ "role": "pho", "barangay_id": null }
```

**Response (`data`)**
```json
{
  "barangay_halls": [ { "id": 1, "name": "Andagaw", "latitude": 11.704, "longitude": 122.375 } ],
  "evacuation_centers": [ { "id": 1, "barangay": "Buswang Old", "center_name": "Saint Gabriel College",
      "center_type": "School / Institution", "status": "Available", "latitude": 11.715, "longitude": 122.375 } ],
  "incidents": [ { "id": 38, "barangay_id": 1, "barangay_name": "Andagaw", "disaster_type": "Fire",
      "status": "Pending", "latitude": 11.704, "longitude": 122.375, "created_at": "2026-06-02 12:57:49" } ]
}
```

---

## 4. Evacuation Centers

### `POST /get_evacuation_centers.php`
List evacuation centers, optionally filtered.

**Request**
```json
{ "role": "barangay", "barangay_name": "Poblacion", "search": "" }
```

**Response:** `data` is an array of center objects (see DATABASE.md columns).

### `POST /save_evacuation_center.php`
Create a new evacuation center.

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

**Response**
```json
{ "success": true, "message": "Evacuation center saved successfully.",
  "data": { "id": 8 } }
```

---

## 5. Hotlines

### `POST /get_hotlines.php`
List emergency hotlines, optionally filtered.

**Request**
```json
{ "role": "barangay", "barangay_id": 13, "category": "", "search": "" }
```

**Response:** `data` is an array of hotline objects (see DATABASE.md columns).

### `POST /save_hotline.php`
Create a new hotline entry.

**Request**
```json
{
  "acting_user_id": 1, "hotline_scope": "Barangay", "barangay_id": 13,
  "office_name": "Kalibo PNP", "municipality": "Kalibo", "category": "PNP",
  "telephone_numbers": "268-2166", "cellphone_numbers": "0939-916-7066",
  "hotline_number": "166", "remarks": "", "status": "Active"
}
```

**Response**
```json
{ "success": true, "message": "Hotline saved successfully.",
  "data": { "id": 22 } }
```

---

## 6. Alerts

### `POST /get_alerts.php`
List alerts visible to the caller.

**Request**
```json
{ "role": "barangay", "barangay_id": 1, "user_id": 4, "search": "" }
```

**Response:** `data` is an array of alert objects.

### `POST /save_alert.php`
Create (broadcast) a new alert.

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

**Response**
```json
{ "success": true, "message": "Alert created successfully.", "data": { } }
```

### `POST /get_unread_alert_count.php`
Unread alert count for a user (for the notification badge).

**Request**
```json
{ "user_id": 4, "barangay_id": 1 }
```
**Response**
```json
{ "success": true, "message": "Unread count loaded.", "data": { "count": 2 } }
```

### `POST /mark_alerts_read.php`
Mark one or more alerts as read for a user.

**Request**
```json
{ "user_id": 4, "barangay_id": 1, "alert_ids": [15, 16] }
```
**Response**
```json
{ "success": true, "message": "Alerts marked as read.", "data": { "count": 2 } }
```

---

## 7. Users & Admin

> These endpoints are for **superadmin**. The acting admin is identified by
> `acting_user_id`, and actions are recorded in `user_activity_logs`.

### `POST /get_users.php`
List user accounts.
```json
{ "search": "" }
```
`data` is an array of users (no password hashes are returned).

### `POST /save_user.php`
Create a new account.
```json
{ "acting_user_id": 1, "name": "Pook Barangay Account", "username": "pook",
  "password": "admin123", "role": "barangay", "barangay_id": 14 }
```
**Response:** `{ "data": { "id": 20 } }`

### `POST /update_user.php`
Edit an account (no password change here).
```json
{ "acting_user_id": 1, "user_id": 20, "name": "Pook BLGU",
  "username": "pook", "role": "barangay", "barangay_id": 14 }
```
**Response:** `{ "message": "User updated successfully." }`

### `POST /reset_user_password.php`
Set a new password for an account.
```json
{ "acting_user_id": 1, "user_id": 20, "password": "newPass123" }
```
**Response:** `{ "message": "Password reset successfully." }`

### `POST /toggle_user_status.php`
Activate / deactivate an account (flips current status).
```json
{ "acting_user_id": 1, "user_id": 20 }
```
**Response:** `{ "message": "Account is now Inactive.", "data": { "status": "Inactive" } }`

### `POST /get_user_activity.php`
Read the superadmin audit trail.
```json
{ "acting_user_id": 1 }
```
`data` is an array of `user_activity_logs` entries.

### `user_audit.php`
Internal helper used for the user-management audit checks (superadmin-gated).
Not called directly by the app UI.

---

## 8. Lookups

### `GET|POST /get_barangays.php`
List barangays (for dropdowns). Optional `acting_user_id` scopes the list to the
acting MDR/Mayor account's municipality (`mdr_kalibo`/`mayor_kalibo` → Kalibo,
`mdr_ibajay`/`mayor_ibajay` → Ibajay); all other roles get every active barangay.
The response echoes the resolved scope (`null` = all).
```json
{ "success": true, "message": "Barangays loaded successfully.", "scope": "Ibajay",
  "data": [ { "id": 17, "name": "Andagaw", "municipality": "Ibajay", "population": 1200 } ] }
```

### `GET|POST /get_disaster_types.php`
List disaster types (for dropdowns).
```json
{ "success": true, "message": "Disaster types loaded successfully.",
  "data": [ { "id": 1, "name": "Typhoon", "status": "Active" } ] }
```

---

## 9. Reserved (next phase)

These endpoint files exist as placeholders and currently return
`success: false` with the message *"This endpoint is reserved for the next
phase."* They are **not implemented yet**:

- `get_dashboard_counts.php`
- `update_evacuation_center.php`
- `delete_evacuation_center.php`
- `update_hotline.php`
- `delete_hotline.php`
- `delete_alert.php`
