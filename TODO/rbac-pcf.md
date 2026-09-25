# OBILAK — PCF MDRRMO Sub-Role System

> **Scope:** Municipal-level role-based access control for PCF (MDR-Admin / MDR-Kalibo / MDR-Ibajay)
> **Applies to:** Both OBILAK implementations
> - PHP + MySQL (`sastergpt/`)
> - Node.js + PostgreSQL (`capstone_project/`)
> **Status:** Implemented (PHP + Flutter). Ready to port to Node.js + PostgreSQL.

---

## 0. Display Naming Convention

| Internal (DB / code) | Display (UI) | Where it appears |
|---|---|---|
| `pcf` (role) | **PCF** | Sidebar brand, topbar chip |
| `sub_role` = `mdr_admin` | **MDR Admin** | Sidebar card, profile, topbar chip, manage users |
| `sub_role` = `mdr_kalibo` | **MDRRMO KALIBO** / **MDRRMO** | Sidebar card, profile, topbar chip |
| `sub_role` = `mdr_ibajay` | **MDRRMO IBAJAY** / **MDRRMO** | Sidebar card, profile, topbar chip |
| `sub_role` = `''` (empty/null) | **Municipal** | Legacy unscoped pcf (backwards compat) |

### Sidebar User Card (Web + Flutter)

```
MDR Admin:   → "MDR Admin" / "MDR Admin"
MDR-Kalibo:  → "MDRRMO KALIBO" / "MDRRMO"
MDR-Ibajay:  → "MDRRMO IBAJAY" / "MDRRMO"
```

### Topbar Status Chip

Shows the role label: **MDR Admin** / **MDRRMO KALIBO** / **MDRRMO IBAJAY** (no "PCF" prefix for MDR roles).

### Municipality Filter (Web + Flutter)

| Sub-role | Filter behavior |
|---|---|
| `mdr_admin` | Municipality dropdown visible (can switch between Kalibo, Ibajay, All) |
| `mdr_kalibo` | **Hidden** — forced to Kalibo |
| `mdr_ibajay` | **Hidden** — forced to Ibajay |
| `''` (legacy) | Municipality dropdown visible (current behavior) |

---

## 1. The Problem

### Current State

The PCF (Provincial Coordination Facility) role has **one account** — a single `role='pcf'` user with `sub_role=NULL`. This user sees incident reports from **all municipalities** (Kalibo and Ibajay) with no scoping.

### Why This Breaks in Real Disaster Response

During simultaneous disasters across municipalities (e.g., flooding in Kalibo + typhoon damage in Ibajay), the PCF needs **separate MDRRMO teams** per municipality:

| Problem | Impact |
|---|---|
| **No municipal isolation** | MDR-Kalibo officer sees Ibajay reports and vice versa — information overload |
| **No audit trail** | Can't distinguish which MDRRMO officer took action on a report |
| **Single point of failure** | One PCF login serves both municipalities |
| **No role-appropriate scoping** | An MDR-Kalibo officer can accidentally act on an Ibajay report |

### Real-World Reference

Under **RA 10121** and **DILG-NDRRMC JMC 2014-1**, each municipality has its own MDRRMO (Municipal Disaster Risk Reduction and Management Office). The MDRRMO is the primary coordinating body at the municipal level. OBILAK should mirror this: each MDRRMO gets its own scoped admin that only sees their municipality's reports.

---

## 2. The Solution

### Overview

Add **sub-role** capability within the existing `pcf` role. Three sub-roles aligned with the actual MDRRMO structure:

```
┌─────────────────────────────────────────────────────┐
│  MDR ADMIN (PCF Admin / MDRRMO Supervisor)          │
│  ├── Full access to web dashboard + mobile app      │
│  ├── Manages ALL MDRRMO accounts (Kalibo + Ibajay)  │
│  ├── Sees reports from ALL municipalities           │
│  ├── Can verify, respond, refer to PHO, resolve     │
│  ├── Can manage hotlines, evacuation centers         │
│  ├── Manages user accounts + Activity Log            │
│  └── Municipality filter dropdown visible            │
│                                                     │
  │  MDR-KALIBO (Kalibo MDRRMO Officer)                 │
  │  ├── Web dashboard + mobile app                      │
  │  ├── Sees ONLY Kalibo barangay reports              │
  │  ├── Sees ONLY Kalibo evacuation centers            │
  │  ├── Can verify, respond, refer to PHO, resolve     │
  │  ├── Can manage hotlines                             │
  │  ├── NO Manage Users / Activity Log                  │
  │  └── Municipality filter HIDDEN (forced Kalibo)     │
  │                                                     │
  │  MDR-IBAJAY (Ibajay MDRRMO Officer)                 │
  │  ├── Web dashboard + mobile app                      │
  │  ├── Sees ONLY Ibajay barangay reports              │
  │  ├── Sees ONLY Ibajay evacuation centers            │
  │  ├── Can verify, respond, refer to PHO, resolve     │
  │  ├── Can manage hotlines                             │
  │  ├── NO Manage Users / Activity Log                  │
  │  └── Municipality filter HIDDEN (forced Ibajay)     │
  └─────────────────────────────────────────────────────┘
  ```

  ### Permission Matrix

  | Permission | MDR Admin | MDR-Kalibo | MDR-Ibajay | Legacy PCF |
  |---|:---:|:---:|:---:|:---:|
  | View reports (all municipalities) | ✅ | ❌ | ❌ | ✅ |
  | View reports (own municipality only) | ✅ | ✅ Kalibo | ✅ Ibajay | ✅ |
  | Verify / Respond / Refer to PHO | ✅ | ✅ | ✅ | ✅ |
  | Resolve / Dismiss reports | ✅ | ✅ | ✅ | ✅ |
  | Manage MDR Admin accounts | ✅ | ❌ | ❌ | ❌ |
  | Manage MDR-Kalibo accounts | ✅ | ❌ | ❌ | ❌ |
  | Manage MDR-Ibajay accounts | ✅ | ❌ | ❌ | ❌ |
  | Manage hotlines | ✅ | ✅ | ✅ | ✅ |
  | Manage evacuation centers | ✅ | ✅ | ✅ | ✅ |
  | View dashboard analytics | ✅ | ✅ (scoped) | ✅ (scoped) | ✅ |
  | Municipality filter dropdown | ✅ | ❌ (forced) | ❌ (forced) | ✅ |
  | View activity log | ✅ (all PCF) | ❌ | ❌ | ❌ |
  | Access Manage Users page | ✅ | ❌ | ❌ | ❌ |

  > **Key restrictions:**
  > - MDR-Kalibo **cannot** see Ibajay reports — municipality is forced at query level.
  > - MDR-Ibajay **cannot** see Kalibo reports — same enforcement.
  > - MDR-Kalibo **cannot** create MDR-Ibajay accounts (and vice versa).
  > - Only MDR Admin can create/manage other MDR Admin accounts.
  > - Legacy PCF (blank sub_role) sees all municipalities but has **no** manage-users/activity access.

  ### `can_manage_users` Truth Table

  | Sub-role | `can_manage_users` |
  |---|:---:|
  | MDR Admin (`mdr_admin`) | `1` / `TRUE` |
  | MDR-Kalibo (`mdr_kalibo`) | `0` / `FALSE` |
  | MDR-Ibajay (`mdr_ibajay`) | `0` / `FALSE` |
  | Legacy PCF (blank) | `0` / `FALSE` |

  Only MDR Admin can manage user accounts. MDR-Kalibo and MDR-Ibajay are operational rescue officers — they act on reports but do not manage user accounts.

  ### Municipality Scope Enforcement

  The municipality scope is enforced at the **SQL query level**, not just the UI:

  ```php
  // MDR-Kalibo forced scope (example from get_reports.php):
  $mdr_muni = mdr_municipality($actor_sub_role); // 'Kalibo' for mdr_kalibo
  if ($mdr_muni) {
      $where .= " AND barangays.municipality = ?";
      $params[] = $mdr_muni;
  }
  ```

  For MDR-Kalibo/MDR-Ibajay, the `set_municipality_filter.php` endpoint **ignores** any user-chosen filter and overrides with the forced municipality. The sidebar filter dropdown is **hidden** entirely.

  ### Platform Access

  | Role | Mobile App | Web Dashboard |
  |---|:---:|:---:|
  | MDR Admin | ✅ Full nav + Manage Users | ✅ Full sidebar + Manage Users + Activity Log |
  | MDR-Kalibo | ✅ Full nav (no manage) | ✅ Full sidebar (no manage); filter hidden |
  | MDR-Ibajay | ✅ Full nav (no manage) | ✅ Full sidebar (no manage); filter hidden |
  | Legacy PCF | ✅ Current nav (no manage) | ✅ Current sidebar (no manage) |

  ---

  ## 3. Report Flow — Municipality Scoping

  ### How Reports Reach the MDRRMO

  The existing flow is unchanged:

  ```
  BHERT submits report (barangay_id set)
          ↓
    Captain reviews → Forwarded to PCF
          ↓
    MDRRMO sees report IF:
      - MDR Admin: always (all municipalities)
      - MDR-Kalibo: report's barangay is in Kalibo
      - MDR-Ibajay: report's barangay is in Ibajay
  ```

  The scoping is done by joining `incident_reports.barangay_id → barangays.municipality` and filtering by the MDR sub-role's forced municipality.

  ### Status Flow (Unchanged)

  The MDRRMO sub-roles have the **same status authority** as the current PCF role:

  | Actor | Can set to |
  |---|---|
  | **MDR Admin** | `Verified`, `Responding`, `Referred to PHO`, `Resolved`, `Dismissed` |
  | **MDR-Kalibo** | `Verified`, `Responding`, `Referred to PHO`, `Resolved`, `Dismissed` |
  | **MDR-Ibajay** | `Verified`, `Responding`, `Referred to PHO`, `Resolved`, `Dismissed` |

  ### PCF Report Filtering (SQL)

  ```sql
  -- PCF WHERE clause (both web and API):
  WHERE incident_reports.status IN (
      'Forwarded to PCF', 'Verified', 'Responding',
      'Referred to PHO', 'Resolved', 'Dismissed'
  )
  -- PLUS municipality scope for MDR sub-roles:
  AND barangays.municipality = ?
```

### All Valid Status Values

```sql
'Pending', 'Reviewed', 'Forwarded to PCF', 'Verified',
'Responding', 'Referred to PHO', 'Resolved', 'Dismissed'
```

---

## 4. User Management

### Who Can Manage Whom

| Actor | Can create/edit/toggle/reset | Cannot touch |
|---|---|---|
| **Superadmin** | All users | (none) |
| **MDR Admin** | `mdr_admin`, `mdr_kalibo`, `mdr_ibajay` (pcf role only) | barangay, pho, superadmin, self |
| **MDR-Kalibo** | (no user management) | all accounts |
| **MDR-Ibajay** | (no user management) | all accounts |
| **Captain** (barangay) | Secretary, BHERT (own barangay only) | Captain, pcf, pho, superadmin |
| **Secretary** (barangay) | BHERT only (own barangay only) | Captain, Secretary, pcf, pho, superadmin |

### Scope Enforcement

```php
// Only MDR Admin can manage PCF/MDR user accounts.
if ($actor_role === 'pcf' && $actor_sub_role !== 'mdr_admin') {
    send_response(false, "Only MDR Admin can manage MDRRMO accounts.");
}

// MDR Admin can only touch PCF accounts, not barangay/pho/superadmin.
if ($actor_role === 'pcf' && $target_role !== 'pcf') {
    send_response(false, "You can only manage PCF accounts.");
}
```

### `verify_actor()` — API Authorization

```php
function verify_actor($connection, $acting_user_id) {
    // ... query user from DB ...
    if (strtolower($row['role']) === 'superadmin') return $row;
    if (strtolower($row['role']) === 'barangay' && $row['can_manage_users'] == 1) return $row;
    if (strtolower($row['role']) === 'pcf' && $row['can_manage_users'] == 1) return $row; // NEW
    return null;
}
```

### One-Admin Constraint

Unlike barangay (one Captain per barangay), MDRRMO sub-roles have **no per-municipality constraint**. Multiple MDR-Kalibo accounts are allowed if needed. However, only MDR Admin (pcfadmin) can create them — MDR-Kalibo and MDR-Ibajay are operational rescue officers, not administrators.

---

## 5. Activity Log

### Scope

| Actor | Sees activity from |
|---|---|
| Superadmin | All users (unchanged) |
| MDR Admin | All PCF users (mdr_admin + mdr_kalibo + mdr_ibajay) |
| MDR-Kalibo | (no access to activity log) |
| MDR-Ibajay | (no access to activity log) |
| Captain (barangay) | Own actions only (unchanged) |

### SQL Scope

```php
// MDR-Kalibo activity scope:
if ($V_sub_role === 'mdr_kalibo') {
    $LogResult = mysqli_query($connection,
        "SELECT * FROM user_activity_logs
         WHERE actor_id IN (
             SELECT id FROM users WHERE role = 'pcf' AND sub_role = 'mdr_kalibo'
         )
         ORDER BY created_at DESC LIMIT 300");
}
```

### Table (Unchanged)

```sql
CREATE TABLE user_activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    actor_id INT,
    actor_name VARCHAR(100),
    action VARCHAR(50),
    target_user_id INT,
    target_username VARCHAR(50),
    details VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 6. Database Schema Changes

### Column Modification — `users.sub_role` ENUM

Extend the existing ENUM to include MDR sub-roles:

#### MySQL (PHP project)

```sql
ALTER TABLE users
  MODIFY COLUMN `sub_role` ENUM('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay') DEFAULT NULL;
```

No new columns needed — `sub_role` and `can_manage_users` already exist from the barangay RBAC migration.

#### PostgreSQL (Node.js project)

```sql
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_sub_role_check,
  ALTER COLUMN sub_role TYPE VARCHAR(20);

ALTER TABLE users
  ADD CONSTRAINT users_sub_role_check
  CHECK (sub_role IN ('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay'));
```

### Seed Accounts

```sql
-- Password for all three: admin123
-- Bcrypt hash: $2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS

-- MDR Admin (login: pcfadmin, displays as "MDR Admin")
UPDATE users SET
    sub_role = 'mdr_admin',
    can_manage_users = 1,
    password = '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS'
WHERE username = 'pcfadmin' AND role = 'pcf';

-- MDR-Kalibo admin (new account — can_manage_users=0, operational officer)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('MDR Kalibo Admin', 'mdr_kalibo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pcf', 'mdr_kalibo', 0, NULL, 'Active', NOW());

-- MDR-Ibajay admin (new account — can_manage_users=0, operational officer)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('MDR Ibajay Admin', 'mdr_ibajay', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pcf', 'mdr_ibajay', 0, NULL, 'Active', NOW());
```

---

## 7. Implementation Checklist

### Phase 1: Database Migration

**Files:** `database/migrations/add_pcf_mdr_subroles.sql`, `database/capstone.sql`

- Extend `sub_role` ENUM with `mdr_admin`, `mdr_kalibo`, `mdr_ibajay`
- Seed: update pcfadmin → `mdr_admin`, insert `mdr_kalibo` and `mdr_ibajay`
- Update `capstone.sql` schema dump to match

### Phase 2: Core Helpers

**Files:** `app/includes/functions.php`

- `mdr_municipality($role, $sub_role)` → `'Kalibo'|'Ibajay'|null`
- `can_manage_users($role, $sub_role)`: pcf with any mdr sub_role → true; pcf with blank sub_role → false
- `sub_role_name()`: `mdr_admin` → `'MDR Admin'`, `mdr_kalibo` → `'MDR-Kalibo'`, `mdr_ibajay` → `'MDR-Ibajay'`
- `role_name()`: pcf + mdr sub_role → show the MDR label (not generic "Municipal")
- `get_effective_municipality($role, $sub_role)`: for mdr_kalibo/ibajay → forced muni; else → `get_filter_municipality()`
- `sub_role_manage_flag()`: mdr_admin/mdr_kalibo/mdr_ibajay → 1

### Phase 3: API Authorization

**Files:** `api/user_audit.php`

- Extend `verify_actor()`: allow `role='pcf'` with `can_manage_users=1` to return the actor row

### Phase 4: Web Report Scoping

**Files:** `public/incident-reports.php`, `public/dashboard.php`, `public/map.php`

- Add forced municipality WHERE for pcf + mdr sub-roles
- dashboard.php: forced scope on totals, evac count, charts, weather coords
- map.php: scope incident + evac queries

### Phase 5: Sidebar & Municipality Filter

**Files:** `app/includes/sidebar.php`, `app/auth/set_municipality_filter.php`

- Sidebar: show Manage Users + Activity Log links for pcf with can_manage_users
- Sidebar: hide Municipality filter for mdr_kalibo/ibajay (read-only label)
- set_municipality_filter.php: override posted value for mdr_kalibo/ibajay

### Phase 6: API Report Scoping

**Files:** `api/get_reports.php`, `api/get_dashboard_summary.php`, `api/get_map_data.php`

- When actor is pcf with mdr sub_role (looked up from DB via user_id), force `barangays.municipality`
- This auto-scopes Flutter lists/dashboards without UI changes

### Phase 7: Web User Management

**Files:** `public/manage-users.php`, `app/users/save-user.php`, `app/users/update-user.php`, `app/users/toggle-user-status.php`, `app/users/reset-user-password.php`

- manage-users.php: pcf scope branch — `WHERE role='pcf' AND sub_role = <scope>`
- Create modal: hidden role=pcf; sub_role options restricted by actor's sub_role
- Save/update/toggle/reset: pcf scope checks (same sub_role only, no self-edit, no other roles)

### Phase 8: API User Management

**Files:** `api/save_user.php`, `api/update_user.php`, `api/get_users.php`, `api/toggle_user_status.php`, `api/reset_user_password.php`

- All: pcf scope branch (target role='pcf', sub_role filter per matrix)
- get_users.php: scope query for pcf actor (same as barangay pattern but sub_role-based)

### Phase 9: Web Activity Log

**Files:** `public/user-activity.php`

- Add pcf branch: mdr_admin → all pcf users; mdr_kalibo/ibajay → their sub_role's users
- Sidebar link already added in Phase 5

### Phase 10: Flutter Auth & Navigation

**Files:** `auth_service.dart`, `pcf_main_screen.dart`

- `auth_service.dart`: getters `isPcfAdmin`, `isMdrKalibo`, `isMdrIbajay`, `currentMdrMunicipality`
- `pcf_main_screen.dart`: add Manage Users entry for pcf admins (mirror barangay pattern)
- Inline `_ManageUsersScreen` scoped via APIs (pass `acting_user_id`)
- Report list auto-scoped from Phase 6 API changes

### Phase 11: Verify

- `php -l` on all touched PHP files
- `flutter analyze` on Flutter project
- Login matrix: pcfadmin / mdr_kalibo / mdr_ibajay
- Scoping: each MDR sees only own municipality's reports
- User management: MDR admins can only manage same-sub_role pcf users
- Activity log: scoped per sub_role

---

## 8. API Endpoint Reference

| Endpoint | Method | Who can call | What it does |
|---|---|---|---|
| `api/login.php` | POST | Anyone | Returns user data including `sub_role`, `can_manage_users` |
| `api/save_user.php` | POST | Superadmin, Captain, Secretary, MDR Admin | Creates user with role scoping |
| `api/get_users.php` | POST | Superadmin, Captain, Secretary, MDR Admin | Lists users scoped by role |
| `api/update_user.php` | POST | Superadmin, Captain, Secretary, MDR Admin | Edits user with role scoping |
| `api/toggle_user_status.php` | POST | Superadmin, Captain, Secretary, MDR Admin | Activates/deactivates user |
| `api/reset_user_password.php` | POST | Superadmin, Captain, Secretary, MDR Admin | Resets user password |
| `api/get_reports.php` | POST | All roles | Returns reports with role + municipality filtering |
| `api/update_status.php` | POST | Captain, PCF (all sub-roles), PHO | Updates report status with role enforcement |
| `api/get_dashboard_summary.php` | POST | All roles | Dashboard stats with municipality scoping |
| `api/get_map_data.php` | POST | All roles | Map data with municipality scoping |

### `get_reports.php` Filtering by Role

```
barangay → WHERE barangay_id = ? (all statuses)
           + AND user_id = ? (if sub_role = 'tanod', own reports only)
pcf/mdr_admin   → WHERE status IN (Forwarded+...) + NO municipality filter
pcf/mdr_kalibo  → WHERE status IN (Forwarded+...) + AND municipality = 'Kalibo'
pcf/mdr_ibajay  → WHERE status IN (Forwarded+...) + AND municipality = 'Ibajay'
pcf/(blank)     → WHERE status IN (Forwarded+...) + NO municipality filter
pho       → WHERE referred_to_pho = 1 OR status IN (Referred to PHO, ...)
superadmin → no filter (sees everything)
```

---

## 9. Web Page Reference

| Page | MDR Admin | MDR-Kalibo | MDR-Ibajay | Legacy PCF |
|---|:---:|:---:|:---:|:---:|
| `dashboard.php` | ✅ All muni | ✅ Kalibo | ✅ Ibajay | ✅ All muni |
| `incident-reports.php` | ✅ All muni | ✅ Kalibo | ✅ Ibajay | ✅ All muni |
| `manage-users.php` | ✅ (all pcf users) | ❌ | ❌ | ❌ |
| `user-activity.php` | ✅ (all pcf users) | ❌ | ❌ | ❌ |
| `evacuation-centers.php` | ✅ All muni | ✅ Kalibo | ✅ Ibajay | ✅ All muni |
| `hotlines.php` | ✅ | ✅ | ✅ | ✅ |
| `map.php` | ✅ All muni (filter visible) | ✅ Kalibo (filter hidden) | ✅ Ibajay (filter hidden) | ✅ All muni |
| `alert.php` | ✅ | ✅ | ✅ | ✅ |

---

## 10. Flutter Screen Reference

| Screen | MDR Admin | MDR-Kalibo | MDR-Ibajay | Legacy PCF |
|---|:---:|:---:|:---:|:---:|
| Dashboard tab | ✅ All muni | ✅ Kalibo | ✅ Ibajay | ✅ All muni |
| Reports tab | ✅ Full actions | ✅ Full actions | ✅ Full actions | ✅ Full actions |
| Alerts tab | ✅ | ✅ | ✅ | ✅ |
| Call/Hotlines tab | ✅ | ✅ | ✅ | ✅ |
| Map | ✅ All muni | ✅ Kalibo | ✅ Ibajay | ✅ All muni |
| Evacuation Centers | ✅ | ✅ | ✅ | ✅ |
| Manage Users | ✅ Tab | ❌ Hidden | ❌ Hidden | ❌ Hidden |
| Profile | ✅ | ✅ | ✅ | ✅ |

---

## 11. Node.js Porting Notes

### Schema (PostgreSQL)

```sql
-- users table sub_role column:
ALTER TABLE users
  ALTER COLUMN sub_role TYPE VARCHAR(20),
  ADD CONSTRAINT users_sub_role_check
  CHECK (sub_role IN ('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay'));

-- can_manage_users:
-- Already BOOLEAN from barangay migration, no change needed.
```

### Seed Data

```sql
-- Same hash for admin123: $2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS
-- (PostgreSQL bcrypt may differ — use Node.js bcrypt.hashSync('admin123', 12))

UPDATE users SET sub_role = 'mdr_admin', can_manage_users = TRUE
WHERE username = 'pcfadmin' AND role = 'pcf';

INSERT INTO users (name, username, password, role, sub_role, can_manage_users, status)
VALUES ('MDR Kalibo Admin', 'mdr_kalibo', '<hash>', 'pcf', 'mdr_kalibo', FALSE, 'Active');

INSERT INTO users (name, username, password, role, sub_role, can_manage_users, status)
VALUES ('MDR Ibajay Admin', 'mdr_ibajay', '<hash>', 'pcf', 'mdr_ibajay', FALSE, 'Active');
```

### Scoping Logic

```javascript
// Express middleware / service layer:
function mdrMunicipality(subRole) {
  const map = { mdr_kalibo: 'Kalibo', mdr_ibajay: 'Ibajay' };
  return map[subRole] || null;
}

// In getReports endpoint:
const muni = mdrMunicipality(actor.sub_role);
if (muni) {
  query += ' AND b.municipality = $N';
  params.push(muni);
}
```

### verifyActor

```javascript
// Node.js equivalent:
async function verifyActor(pool, userId) {
  const { rows } = await pool.query(
    'SELECT id, role, sub_role, can_manage_users FROM users WHERE id = $1 AND status = $2',
    [userId, 'Active']
  );
  const user = rows[0];
  if (!user) return null;
  if (user.role === 'superadmin') return user;
  if (user.role === 'barangay' && user.can_manage_users) return user;
  // Only MDR Admin (pcfadmin) has can_manage_users=true.
  if (user.role === 'pcf' && user.can_manage_users) return user;
  return null;
}
```

### User Management Scope

```javascript
// Only MDR Admin can manage PCF/MDR accounts.
if (actor.role === 'pcf') {
  if (actor.sub_role !== 'mdr_admin' || !actor.can_manage_users) {
    throw new Error('Not authorized to manage users');
  }
  if (target.role !== 'pcf') {
    throw new Error('Not a PCF account');
  }
}
```

### Flutter MDR Rules

```dart
// AuthService.effectiveMunicipality must force MDR municipalities:
if (isMdrKalibo) return 'Kalibo';
if (isMdrIbajay) return 'Ibajay';

// Report/map API requests must include userId so PHP/Node can re-read sub_role
// from the database and not trust client-provided municipality alone.
userId: AuthService.currentUserId

// PCF drawer/profile display:
// mdr_admin  -> "MDR Admin" / "MDR Admin"
// mdr_kalibo -> "MDRRMO KALIBO" / "MDRRMO"
// mdr_ibajay -> "MDRRMO IBAJAY" / "MDRRMO"

// Municipality dropdown hidden for mdr_kalibo/mdr_ibajay.
// Shared map loads only the forced municipality polygons for MDR officers.
```

### Files to Port

| PHP File | Node.js Equivalent |
|---|---|
| `api/user_audit.php::verify_actor()` | `middleware/auth.js` or `services/userService.js` |
| `api/save_user.php` | `routes/users.js` POST `/` |
| `api/get_users.php` | `routes/users.js` GET `/` |
| `api/update_user.php` | `routes/users.js` PUT `/:id` |
| `api/toggle_user_status.php` | `routes/users.js` PATCH `/:id/toggle` |
| `api/reset_user_password.php` | `routes/users.js` PATCH `/:id/reset-password` |
| `api/get_reports.php` | `routes/incidents.js` GET `/` |
| `api/get_dashboard_summary.php` | `routes/dashboard.js` GET `/summary` |
| `api/get_map_data.php` | `routes/map.js` GET `/data` |
| `public/manage-users.php` | EJS/React manage-users page |
| `public/user-activity.php` | EJS/React activity-log page |
| `app/includes/functions.js` | `utils/helpers.js` |

---

## 12. Verification Checklist

| # | Scenario | Expected Result |
|---|---|---|
| 1 | MDR Admin (pcfadmin) logs in → web | Full sidebar: Dashboard, Map, Alert, Reports, EC, Hotlines, Manage Users, Activity Log |
| 2 | MDR-Kalibo logs in → web | Full sidebar (no Manage Users, no Activity Log); Municipality filter **hidden** (forced Kalibo) |
| 3 | MDR-Ibajay logs in → web | Full sidebar (no Manage Users, no Activity Log); Municipality filter **hidden** (forced Ibajay) |
| 4 | Legacy PCF (blank sub_role) logs in | Current sidebar; no Manage Users, no Activity Log; Municipality filter visible |
| 5 | MDR Admin views reports | Sees all reports (Kalibo + Ibajay) |
| 6 | MDR-Kalibo views reports | Sees **only** Kalibo reports (Ibajay reports invisible) |
| 7 | MDR-Ibajay views reports | Sees **only** Ibajay reports (Kalibo reports invisible) |
| 8 | MDR-Kalibo dashboard stats | Counts only Kalibo reports + Kalibo evac centers |
| 9 | MDR-Ibajay dashboard stats | Counts only Ibajay reports + Ibajay evac centers |
| 10 | MDR Admin opens Manage Users | Sees all pcf users (mdr_admin + mdr_kalibo + mdr_ibajay) |
| 11 | MDR-Kalibo opens Manage Users | Blocked — no access |
| 12 | MDR-Ibajay opens Manage Users | Blocked — no access |
| 13 | MDR Admin opens Activity Log | Shows actions by all PCF users |
| 14 | MDR-Kalibo opens Activity Log | Blocked — no access |
| 15 | MDR Admin creates mdr_kalibo user | User created with sub_role='mdr_kalibo' |
| 16 | MDR-Kalibo verifies report | Status = Verified (scoped to Kalibo) |
| 17 | MDR-Ibajay refers to PHO | Status = Referred to PHO, referred_to_pho=1 |
| 18 | MDR-Kalibo views evac centers | Sees only Kalibo evac centers |
| 19 | MDR-Ibajay views evac centers | Sees only Ibajay evac centers (empty if no data) |
| 20 | MDR-Kalibo views hotlines | Sees all hotlines (unscoped) |
| 21 | MDR-Kalibo map | Shows Kalibo barangays only; no municipality toggle |
| 22 | MDR-Ibajay map | Shows Ibajay barangays only; no municipality toggle |
| 23 | MDR Admin map | Shows filter dropdown; can switch municipalities |
| 24 | Flutter MDR-Kalibo reports list | Shows only Kalibo reports |
| 25 | Flutter MDR-Ibajay dashboard | Shows only Ibajay stats |
| 26 | Flutter MDR-Kalibo drawer | No Manage Users entry |
| 27 | Flutter MDR Admin drawer | Manage Users entry present |
| 28 | Superadmin views all users | Sees all pcf accounts including all MDR sub-roles |
| 29 | Captain forwards report from Kalibo barangay | Appears in MDR-Kalibo list, not MDR-Ibajay |
| 30 | Captain forwards report from Ibajay barangay | Appears in MDR-Ibajay list, not MDR-Kalibo |

---

*Created: 2026-08-29 | OBILAK — PCF MDRRMO Sub-Role System Specification*
