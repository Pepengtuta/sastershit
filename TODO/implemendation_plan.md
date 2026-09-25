# OBILAK — Hierarchical RBAC: Final Implementation Plan

> [!NOTE]
> **Status: Awaiting "go" + one final decision (Option A or B at the bottom).**
> Everything else is confirmed and ready to build.

---

## What We Are Building

The current system has **hardcoded roles** — every phoadmin always gets the same sidebar,
every pcfadmin always gets the same sidebar. No flexibility, requires code changes to adjust.

The new system has **GUI-assigned permissions**:

```
CURRENT (hardcoded):
  phoadmin → always gets: [Barangay Map, Alert, Health Reports, Evac Centers, Hotlines]

NEW (GUI-assigned):
  Superadmin opens GUI → picks a checklist for phoadmin → saves
  phoadmin opens GUI → picks a checklist for PDRRMO1 → saves
  PDRRMO1 can only be given permissions phoadmin already has — nothing more
```

**No code changes ever again to add a new account type or adjust access.**

---

## How the GUI Works (Your Exact Description)

### Step 1 — Superadmin assigns to phoadmin

```
Superadmin → Manage Users → Select "phoadmin" → Edit Permissions

  ☐ Dashboard
  ☑ Alert
  ☑ All Reports
  ☑ Health Reports
  ☑ Evacuation Centers
  ☑ Emergency Hotlines
  ☐ Activity Logs
  ☐ Manage Users
  ☐ Barangay Map

  [Save] → phoadmin updated: 5 permissions
```

### Step 2 — phoadmin creates PDRRMO1 user, assigns a subset

```
phoadmin → Manage Users → Create User → Assign Permissions

  ☑ Alert         ← phoadmin has this ✅
  ☑ Health Reports← phoadmin has this ✅
  ☑ All Reports   ← phoadmin has this ✅
  ☑ Evac Centers  ← phoadmin has this ✅
  ☑ Hotlines      ← phoadmin has this ✅
  (Dashboard, Activity Logs, Manage Users — HIDDEN, phoadmin doesn't have them)

  [Save] → PDRRMO1 created with whatever subset phoadmin checked
```

**The magic:** The GUI only shows permissions the **current admin HAS**. They can only
pass down what they own. Zero code changes to add a new role — just toggle in the GUI.

---

## Confirmed Account Hierarchy

```
SUPERADMIN  ─── has ALL permissions, sees ALL data, creates anyone
│
├── PROVINCIAL (scope: all barangays)
│   ├── phoadmin (UPGRADED) ─── Superadmin assigns permissions via GUI
│   │       └── creates → PHO staff (PDRRMO, Governor, etc.)
│   │               └── phoadmin assigns SUBSET of own permissions to each
│   │
│   └── [New accounts Superadmin can create: PDRRMO Admin, etc.]
│
├── MUNICIPAL (scope: all 16 barangays in Kalibo)
│   ├── pcfadmin (UPGRADED) ─── Superadmin assigns permissions via GUI
│   │       └── creates → PCF staff (MDRRMO, Mayor, etc.)
│   │               └── pcfadmin assigns SUBSET of own permissions to each
│   │
│   └── [New accounts Superadmin can create: MDRRMO Admin, etc.]
│
└── BARANGAY (scope: single barangay only)
    ├── Barangay Admin ← THE EXISTING 16 ACCOUNTS (andagaw, poblacion, etc.) UPGRADED
    │   Each is admin of their own barangay only.
    │       └── creates within their barangay:
    │               ├── Brgy. Captain → scope: MONITOR only (web)
    │               └── Tanod / Official → scope: REPORT only (mobile app)
    │
    └── [No sub-level below Tanod]
```

### Platform Access

| Account | Web Dashboard | Mobile App |
|---------|:---:|:---:|
| Superadmin | ✅ Full | ❌ |
| phoadmin + staff (PDRRMO, Governor) | ✅ | ❌ |
| pcfadmin + staff (MDRRMO, Mayor) | ✅ | ❌ |
| Barangay Admin (existing 16) | ✅ Admin only | ❌ |
| Brgy. Captain | ✅ Monitor own brgy | ✅ |
| Tanod / Official | ❌ | ✅ Report only |

---

## Permission Keys (Hardcoded Once in PHP)

Mapped directly from the current sidebar items you listed:

| Permission Key | Sidebar Label | Who normally has it |
|---------------|--------------|---------------------|
| `view_dashboard` | Dashboard | Superadmin, PCF |
| `view_map` | Barangay Map | PHO, PCF |
| `view_alerts` | Alert (read) | All accounts |
| `manage_alerts` | Alert (create/broadcast) | Superadmin, PCF |
| `view_all_reports` | All Incident Reports | Superadmin, PCF, MDRRMO, Mayor |
| `view_health_reports` | Health Reports | PHO, PDRRMO |
| `update_report_status` | (Action on reports) | PCF, PHO |
| `refer_to_pho` | (Refer report to PHO) | PCF |
| `view_evacuation_centers` | Evacuation Centers (read) | All accounts |
| `manage_evacuation_centers` | Evacuation Centers (edit) | Superadmin, PCF |
| `view_hotlines` | Emergency Hotlines (read) | All accounts |
| `manage_hotlines` | Emergency Hotlines (edit) | Superadmin, PCF |
| `view_audit_log` | Activity Logs | Superadmin only |
| `manage_users` | Manage Users (own scope) | Any admin |
| `grant_permissions` | Assign/revoke permissions (own scope) | Any admin |
| `create_report` | Submit Incident Report | Tanod / Official |
| `edit_report` | Edit own pending report | Tanod / Official |

**Total: 17 permissions.** These are registered in the `permissions` DB table once. The GUI
reads them from the database — adding a new permission in future = add one row to the DB,
no code changes in PHP logic.

---

## Default Permission Sets (What Each Existing Account Gets on Migration)

| Account | Permissions |
|---------|-------------|
| `superadmin` | **ALL 17** |
| `pcfadmin` | `view_map`, `view_alerts`, `manage_alerts`, `view_all_reports`, `update_report_status`, `refer_to_pho`, `view_evacuation_centers`, `manage_evacuation_centers`, `view_hotlines`, `manage_hotlines`, `manage_users`, `grant_permissions` |
| `phoadmin` | `view_map`, `view_alerts`, `view_health_reports`, `update_report_status`, `view_evacuation_centers`, `view_hotlines`, `manage_users`, `grant_permissions` |
| All 16 `barangay` accounts | `view_map`, `view_alerts`, `view_evacuation_centers`, `view_hotlines`, `manage_users`, `grant_permissions` *(see Option A/B below)* |

**Example — PHO creates PDRRMO1 sub-user:**
PHO's GUI checklist shows only its 8 permissions. PHO ticks `view_alerts` + `view_health_reports`
+ `view_all_reports` → PDRRMO1 gets those 3. PHO cannot give `view_dashboard` — it doesn't have it.

**Example — PHO creates Governor sub-user:**
PHO ticks `view_alerts` + `view_all_reports` → Governor gets those 2, read-only.

**Example — PCF creates MDRRMO sub-user:**
PCF ticks `view_alerts` + `view_all_reports` → MDRRMO gets those 2.

**Example — PCF creates Mayor sub-user:**
PCF ticks `view_all_reports` → Mayor gets 1 permission.

---

## Database Changes

### 3 New Tables Added (nothing deleted)

```sql
-- 1. Named account types (display only, not security)
CREATE TABLE account_types (
  id           INT PRIMARY KEY AUTO_INCREMENT,
  name         VARCHAR(60) NOT NULL,   -- 'Brgy. Captain', 'PDRRMO', 'Mayor', 'Tanod'
  scope_level  ENUM('barangay','municipal','provincial','system') NOT NULL,
  description  VARCHAR(255)
);

-- 2. The fixed permission registry (populated once, read-only after)
CREATE TABLE permissions (
  id          INT PRIMARY KEY AUTO_INCREMENT,
  perm_key    VARCHAR(60) UNIQUE NOT NULL,  -- e.g. 'view_dashboard'
  label       VARCHAR(100) NOT NULL,         -- e.g. 'Dashboard'
  description VARCHAR(255),
  category    VARCHAR(60)                    -- 'Reports', 'Dashboard', 'Admin', etc.
);

-- 3. The live assignment table (GUI writes here)
CREATE TABLE user_permissions (
  id           INT PRIMARY KEY AUTO_INCREMENT,
  user_id      INT NOT NULL,
  perm_key     VARCHAR(60) NOT NULL,
  granted_by   INT NOT NULL,   -- tracks who gave this, enables cascade revoke
  granted_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_up (user_id, perm_key),
  FOREIGN KEY (user_id)    REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (granted_by) REFERENCES users(id)
);
```

### 3 Columns Added to `users` Table

```sql
ALTER TABLE users
  ADD COLUMN account_type_id INT NULL,       -- FK → account_types.id
  ADD COLUMN scope_level ENUM('barangay','municipal','provincial','system') NULL,
  ADD COLUMN created_by INT NULL;            -- FK → users.id (who created this account)
```

The existing `role` column is **kept** during transition (backward compat). Existing PHP that
reads `role` still works day one. New PHP reads `user_permissions`.

---

## API Changes

### New Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/get_my_permissions.php` | POST | Returns the permission keys array for a user |
| `/get_grantable_permissions.php` | POST | Returns permissions the current user CAN grant (their own set) |
| `/save_user_permission.php` | POST | Grant or revoke a permission for a user (within own scope) |
| `/get_account_types.php` | GET | Lookup list for the GUI dropdown |

### Existing Endpoints — Permission Check Added

Before (hardcoded role check):
```php
if ($role === 'pcf') { /* allow */ }
```

After (permission check):
```php
if (!user_has_permission($conn, $user_id, 'update_report_status')) {
    send_response(false, 'Access denied.');
}
```

`user_has_permission()` is added to `api_helper.php` — one DB lookup, used everywhere.

---

## Web Dashboard Changes

### Sidebar
Each `<li>` checks against the user's permission array:
```php
if (in_array('view_dashboard', $user_permissions)) { /* show Dashboard link */ }
if (in_array('view_map', $user_permissions))       { /* show Barangay Map link */ }
// ... etc for all 17 items
```
Permission array is loaded once on session start from `user_permissions` table.

### Manage Users Page (new)
- Lists users in the current user's scope.
- "Edit Permissions" button opens a modal checklist.
- Checklist **only shows** permissions the current logged-in user has (from `get_grantable_permissions`).
- Saves to `user_permissions` table via `save_user_permission.php`.

---

## Flutter App Changes

- On login response, also fetch `get_my_permissions.php`.
- Store permission array in `AuthService` (alongside existing user fields).
- Bottom nav tabs and drawer items built from permission array, not from `role` string.
- `create_report` permission → show report submission screens.
- No `create_report` permission → hide report tab entirely.

---

## Migration (Zero Data Loss)

1. Run the 3 `CREATE TABLE` statements.
2. Run the 3 `ALTER TABLE users` statements.
3. Run the seed INSERT — populate `permissions` table with all 17 permission rows.
4. Run the migration INSERT — populate `user_permissions` for existing accounts per the table above.
5. Done. Old accounts work exactly as before on day one.

---

## The One Remaining Decision

> [!IMPORTANT]
> **Should the existing 16 Barangay Admin accounts (andagaw, poblacion, etc.) ALSO be able to submit incident reports themselves?**
>
> - **Option A — Admin only:** They manage their barangay + create Tanod/Captain accounts.
>   They do NOT submit reports. All reports come from sub-accounts they create.
>   → Cleanest hierarchy. Matches the professor's structure exactly.
>
> - **Option B — Admin + Reporter:** They keep `create_report` in addition to admin permissions.
>   They can both manage the barangay AND submit reports.
>   → More flexible but blurs the admin/reporter separation.
>
> **My recommendation: Option A.** Cleanest for the demo and the defense.
> The role is clear: the 16 accounts administrate. Tanods report.

---

## Verification Checklist (After Build)

- [ ] `superadmin` logs in → sees all 17 sidebar items
- [ ] Superadmin removes `view_dashboard` from `pcfadmin` via GUI → pcfadmin no longer sees Dashboard
- [ ] `phoadmin` creates PDRRMO1, assigns `view_health_reports` + `view_alerts`
- [ ] PDRRMO1 logs in → sees only Health Reports + Alerts sidebar
- [ ] PDRRMO1 tries to grant `view_dashboard` (phoadmin doesn't have it) → blocked
- [ ] Superadmin revokes `view_health_reports` from phoadmin → PDRRMO1 also loses it (cascade)
- [ ] Barangay Admin (`andagaw`) creates a Tanod account, grants `create_report`
- [ ] Tanod logs into mobile app → sees only report submission, nothing else
- [ ] `pcfadmin` login still works, sees the same sidebar as before (migration success)
- [ ] `phoadmin` login still works, sees the same sidebar as before (migration success)
