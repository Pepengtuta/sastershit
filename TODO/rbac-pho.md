# OBILAK - PHO Referral RBAC

> **Scope:** Provincial Health Office access to MDRRMO-referred incidents
> **Applies to:** PHP + MySQL web/API, Flutter, and the future Node.js + PostgreSQL port
> **Status:** Implemented in PHP and Flutter. Ready to port to `capstone_project/`.

---

## 1. Purpose

PHO must not see barangay incidents merely because they exist in Kalibo or Ibajay. An incident becomes visible to PHO only after an authorized PCF/MDRRMO officer refers it to PHO.

The municipality filter is a view filter, not an authorization rule:

- **All Municipalities:** all PHO-referred incidents
- **Kalibo:** PHO-referred Kalibo incidents only
- **Ibajay:** PHO-referred Ibajay incidents only
- Unreferred incidents remain hidden in every scope

Referral escalates provincial coordination. It does not remove MDRRMO ownership or municipal response responsibilities.

---

## 2. Account Model

### PHO Admin (`phoadmin`)

| Field | Value |
|---|---|
| Username | `phoadmin` |
| Role | `pho` |
| Sub-role | empty / null |
| Barangay | null |
| `can_manage_users` | `1` |
| Default municipality | null |
| Municipality access | Kalibo, Ibajay, All |

The default Provincial account (empty sub-role) is the **PHO Admin**. It creates
and manages **PDRRMO** accounts only and reads the Provincial activity log.

### PDRRMO

| Field | Value |
|---|---|
| Role | `pho` |
| Sub-role | `pdrrmo` |
| Barangay | null |
| `can_manage_users` | `0` |
| Municipality access | Kalibo, Ibajay, All |

PDRRMO is a province-wide rescue/response sub-role. It sees the same
PHO-referred incidents (both Kalibo and Ibajay) and may update provincial
report statuses, but has **no** user management or activity log access.

PHO has no municipality-specific sub-roles. Any PHO account (Admin or PDRRMO)
can switch its display scope, but every query must retain referral authorization.

---

## 3. Referral Source of Truth

The durable authorization flag is:

```sql
incident_reports.referred_to_pho = 1
```

Compatibility statuses are also recognized:

```text
Referred to PHO
Forwarded to PHO
```

Required SQL predicate:

```sql
AND (
  incident_reports.referred_to_pho = 1
  OR incident_reports.status IN ('Referred to PHO', 'Forwarded to PHO')
)
```

The boolean flag is important because an incident may later become `Responding` or `Resolved`. It must remain visible to PHO after the status changes.

Do not implement PHO authorization as only:

```sql
incident_reports.status = 'Referred to PHO'
```

That would hide referred cases after normal workflow progression.

---

## 4. Access Matrix

| Capability | PHO Admin | PDRRMO |
|---|---|---|
| View unreferred/Pending barangay incident | No | No |
| View PCF-visible but not PHO-referred incident | No | No |
| View PHO-referred incident | Yes | Yes |
| View referred incidents from all municipalities | Yes | Yes |
| Filter referred incidents to Kalibo | Yes | Yes |
| Filter referred incidents to Ibajay | Yes | Yes |
| View referred incident map location | Yes | Yes |
| View unreferred location through map/API | No | No |
| View referred attachments/details | Yes | Yes |
| Publish provincial alerts | Yes | Yes |
| Update provincial report status | Yes | Yes |
| Create / edit / deactivate PDRRMO accounts | Yes | No |
| Read Provincial (PHO) activity log | Yes | No |

---

## 5. Municipality Rules

Authorization and municipality scope must be combined with `AND`:

```sql
WHERE (
  incident_reports.referred_to_pho = 1
  OR incident_reports.status IN ('Referred to PHO', 'Forwarded to PHO')
)
AND barangays.municipality = ?
```

When the selected value is All Municipalities, omit only the municipality predicate. Never omit the referral predicate.

Use `barangays.municipality`, not a barangay-name subquery. Barangay names are not guaranteed to be unique across municipalities.

---

## 6. PHP Web Enforcement

### Map

`public/map.php` applies the PHO referral predicate before incident markers and recent-incident cards are serialized to JavaScript.

This server-side filtering prevents unreferred coordinates from appearing in page source, marker arrays, popups, and recent-incident panels.

### Reports

`public/health-reports.php` uses `referred_to_pho = 1` as the primary PHO report scope.

### Dashboard

`public/dashboard.php` scopes PHO totals, charts, trends, and recent reports with `referred_to_pho = 1`.

### Navigation

PHO web navigation includes:

- Dashboard
- Barangay Map
- Alert
- Health Reports
- Evacuation Centers
- Emergency Hotlines

Only the **PHO Admin** (empty/null sub-role) additionally receives **Manage
Users** and **Activity Log** entries. PDRRMO accounts never see them.

### Manage Users (PHO Admin only)

`public/manage-users.php` lists and manages PDRRMO accounts only:

```sql
WHERE users.role = 'pho' AND users.sub_role = 'pdrrmo'
```

- Creating a user forces `role='pho'`, `sub_role='pdrrmo'`, `can_manage_users=0`.
- The PHO Admin cannot edit or deactivate their own account.
- Web handlers: `app/users/save-user.php`, `app/users/update-user.php`,
  `app/users/toggle-status.php`, `app/users/reset-password.php`.

### Activity Log (PHO Admin only)

`public/user-activity.php` shows only Provincial (PHO) activity:

```sql
WHERE actor_id IN (SELECT id FROM users WHERE role = 'pho')
```

PDRRMO and PCF/MDRRMO activity are not exposed.

---

## 7. PHP API Enforcement

### `api/get_map_data.php`

For `role = 'pho'`, incident map data uses:

```php
$where .= " AND (
    incident_reports.referred_to_pho = 1
    OR incident_reports.status IN ('Referred to PHO','Forwarded to PHO')
)";
```

The response includes `referred_to_pho` so Flutter can apply defense-in-depth filtering after receipt.

### `api/get_reports.php`

PHO report queries use the same referral rule. Municipality is an additional prepared parameter when selected.

### `api/get_dashboard_summary.php`

PHO dashboard counts apply the referral rule before municipality and date filters.

### Required Request Context

```json
{
  "role": "pho",
  "municipality": "Ibajay"
}
```

Omit `municipality` for All Municipalities.

The production Node.js port should derive `role` from authenticated server session/JWT claims rather than trusting a client request field.

### User Management APIs (PHO Admin only)

`api/user_audit.php` `verify_actor()` admits a `pho` actor only when
`can_manage_users = 1` (i.e. the PHO Admin). PHO user-management endpoints then
enforce a strict PDRRMO scope:

| Endpoint | Scope rule |
|---|---|
| `api/get_users.php` | `role='pho' AND sub_role='pdrrmo'` |
| `api/save_user.php` | role forced `pho`, sub-role must be `pdrrmo`, `can_manage_users=0` |
| `api/update_user.php` | target must be a PDRRMO account; actor cannot edit self |
| `api/toggle_user_status.php` | target must be a PDRRMO account |
| `api/reset_user_password.php` | target must be a PDRRMO account |
| `api/get_user_activity.php` | `actor_id IN (SELECT id FROM users WHERE role='pho')` |

Superadmin-created `pho` accounts default to empty sub-role and
`can_manage_users=1` (PHO Admin). `sub_role_manage_flag()` returns `0` for
`pdrrmo`, `mdr_kalibo`, `mdr_ibajay`.

### Report Status Updates

`api/update_status.php` and `public/health-reports.php` already allow
`role='pho'` to update statuses, so PDRRMO (role `pho`) can update provincial
report statuses without extra authorization code.

---

## 8. Flutter Enforcement

### Map

`MapDataService.getMapData()` performs a client-side PHO safeguard:

```dart
isReferred || status == 'referred to pho' || status == 'forwarded to pho'
```

This is defense in depth only. The API remains authoritative because client-side filtering cannot protect raw API data.

### Municipality Toggle

`AuthService.filterMunicipality` stores the selected municipality.

- null = All Municipalities
- `Kalibo` = Kalibo only
- `Ibajay` = Ibajay only

Changing the filter must refresh:

- Dashboard
- Health Reports
- Emergency Hotlines
- Map
- Evacuation Centers

The map receives a new `refreshToken`, updates its local municipality, and requests fresh API data. A saved dropdown value is used only when it exists in the loaded municipality options.

### Transient Error Prevention

- Do not pass an invalid saved value to `DropdownButtonFormField`.
- Deduplicate municipality options.
- Represent All as null rather than silently replacing it with Kalibo.
- Replace the existing map data after a successful request; do not merge markers across scopes.

---

## 9. Node.js + PostgreSQL Port

Target project:

```text
C:\xampp\htdocs\vsp\capstone_project
```

### PostgreSQL Schema

```sql
ALTER TABLE incident_reports
  ADD COLUMN IF NOT EXISTS referred_to_pho boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_incident_reports_pho_referral
  ON incident_reports (referred_to_pho, barangay_id);
```

Prefer a referral timestamp and actor for accountability:

```sql
ALTER TABLE incident_reports
  ADD COLUMN IF NOT EXISTS referred_to_pho_at timestamptz,
  ADD COLUMN IF NOT EXISTS referred_to_pho_by bigint REFERENCES users(id);
```

### Express Authorization Middleware

```javascript
function requirePho(req, res, next) {
  if (req.user?.role !== 'pho') {
    return res.status(403).json({ success: false, message: 'PHO access required.' });
  }
  next();
}

function requirePhoAdmin(req, res, next) {
  if (req.user?.role !== 'pho' || req.user?.sub_role) {
    return res.status(403).json({ success: false, message: 'PHO Admin access required.' });
  }
  next();
}
```

Guard every report/map/dashboard route with `requirePho`. Guard user-management
routes (create/edit/toggle/reset/activity) with `requirePhoAdmin`, then scope
targets to `role='pho' AND sub_role='pdrrmo'` in SQL.

### Query Builder

```javascript
const conditions = [
  `(ir.referred_to_pho = TRUE
    OR ir.status IN ('Referred to PHO', 'Forwarded to PHO'))`,
];
const values = [];

if (req.query.municipality) {
  values.push(req.query.municipality);
  conditions.push(`b.municipality = $${values.length}`);
}

const sql = `
  SELECT ir.*, b.name AS barangay_name, b.municipality
  FROM incident_reports ir
  JOIN barangays b ON b.id = ir.barangay_id
  WHERE ${conditions.join(' AND ')}
  ORDER BY ir.created_at DESC
`;
```

Use this shared scope in report, map, dashboard, search, export, attachment, and notification services. Do not duplicate subtly different PHO predicates in every route.

### Recommended Service Helper

```javascript
function addPhoScope(query, actor, municipality) {
  if (actor.role !== 'pho') return query;

  query.where((builder) => {
    builder.where('ir.referred_to_pho', true)
      .orWhereIn('ir.status', ['Referred to PHO', 'Forwarded to PHO']);
  });

  if (municipality) query.where('b.municipality', municipality);
  return query;
}
```

### Audit Trail

When PCF refers an incident, record:

- incident ID
- referring user ID and MDR sub-role
- referring municipality
- old and new status
- referral reason
- timestamp
- later PHO acknowledgement, return, or closure

Referral reversal should require a reason and must not erase audit history.

---

## 10. Files to Port

| PHP / Flutter | Node.js equivalent |
|---|---|
| `api/get_map_data.php` | `routes/map.js` / `services/mapService.js` |
| `api/get_reports.php` | `routes/incidents.js` |
| `api/get_dashboard_summary.php` | `routes/dashboard.js` |
| `api/update_status.php` | referral/status service |
| `public/map.php` | React/EJS map page |
| `public/health-reports.php` | React/EJS PHO reports page |
| `public/dashboard.php` | React/EJS PHO dashboard |
| `public/manage-users.php`, `app/users/*.php` | `routes/users.js` (PHO Admin scope) |
| `public/user-activity.php` | `routes/activity.js` (PHO Admin scope) |
| `MapDataService` | frontend API client |
| `PhoMainScreen` municipality filter | frontend global filter state |

---

## 11. Verification Checklist

| # | Scenario | Expected |
|---|---|---|
| 1 | Barangay submits Pending report | Hidden from PHO map/reports/dashboard |
| 2 | Chairman forwards report to PCF only | Still hidden from PHO |
| 3 | MDR-Kalibo refers report to PHO | Visible to PHO in All and Kalibo |
| 4 | MDR-Ibajay refers report to PHO | Visible to PHO in All and Ibajay |
| 5 | MDR Admin refers report to PHO | Visible to PHO in its incident municipality |
| 6 | Referred case becomes Responding | Remains visible because referral flag persists |
| 7 | Referred case becomes Resolved | Remains visible because referral flag persists |
| 8 | PHO selects Kalibo | No Ibajay markers, reports, or counts |
| 9 | PHO selects Ibajay | No Kalibo markers, reports, or counts |
| 10 | PHO selects All | Referred Kalibo and Ibajay incidents visible |
| 11 | PHO calls map API directly | Unreferred coordinates absent from response |
| 12 | Municipality toggle changes in Flutter | Current screen reloads without transient error |
| 13 | Invalid saved municipality exists | Dropdown falls back safely to All |
| 14 | Superadmin opens map | Existing superadmin monitoring behavior unchanged |
| 15 | Barangay opens own map | Existing own-barangay behavior unchanged |
| 16 | `pdrrmo` / `admin123` logs in | Opens PHO screens; PDRRMO profile label; no Manage Users / Activity Log |
| 17 | `pdrrmo` opens map/reports | Only referred Kalibo and Ibajay incidents appear |
| 18 | `pdrrmo` updates a referred report status | Allowed |
| 19 | PHO Admin opens Manage Users | Lists PDRRMO accounts only; cannot edit self |
| 20 | PDRRMO calls user APIs directly | Rejected (no `can_manage_users`) |
| 21 | PHO Admin opens Activity Log | Provincial-only activity; no PCF/MDRRMO logs |

---

## 12. Security Rule

The invariant for PHO is:

```text
visible_to_pho = referred_to_pho AND optional_municipality_match
```

Apply this invariant before returning rows, coordinates, counts, attachments, search suggestions, exports, or notifications. UI hiding alone is not access control.

The user-management invariant for PHO is:

```text
manageable_by_pho_admin = (target.role = 'pho' AND target.sub_role = 'pdrrmo') AND actor.can_manage_users = 1
```

The activity invariant is:

```text
visible_activity = actor_id IN (SELECT id FROM users WHERE role = 'pho')
```
