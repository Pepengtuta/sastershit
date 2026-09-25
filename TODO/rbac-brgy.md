# OBILAK — Barangay Sub-Role System

> **Scope:** Barangay-level role-based access control (Captain / Secretary / BHERT) + Captain-to-PCF triage workflow
> **Applies to:** Both OBILAK implementations
> - PHP + MySQL (`sastergpt/`)
> - Node.js + PostgreSQL (`capstone_project/`)
> **Status:** Implemented (PHP + Flutter). Ready to port to Node.js + PostgreSQL.

---

## 0. Display Naming Convention

The DB/code uses internal names (`tanod`, `pcf`). The UI uses display names that differ:

| Internal (DB / code) | Display (UI) | Where it appears |
|---|---|---|
| `tanod` | **BHERT** | All user-facing labels, sidebar, profile, manage users, Flutter nav |
| `pcf` | **PCF** | Sidebar brand, topbar chip, button labels (stays 3-letter abbreviation) |
| `sub_role` = `captain` | **Captain** | Sidebar, profile, topbar chip, Flutter nav |
| `sub_role` = `secretary` | **Secretary** | Sidebar, profile, topbar chip, Flutter nav |
| `'Provincial Coordination Facility'` | **Primary Care Facility** | Only where the full name was previously displayed (e.g., `role_name()` for `pcf` role) |

### Sidebar User Card (Web + Flutter)

```
Captain:  → "Captain: JUAN" / "BRGY: Andagaw"
Secretary → "Secretary" / "BRGY: Andagaw"
BHERT:    → "BHERT: JUAN" / "BRGY: Andagaw"
```

Role prefixes ("Tanod", "Captain", etc.) are stripped from the stored name before display.

### Topbar Status Chip

Shows just the role label: **Captain** / **Secretary** / **BHERT** (no "Barangay" prefix).

### Status Labels

Status values in the DB are unchanged (`Forwarded to PCF`, etc.). A `status_display()` helper in `functions.php` maps them to shorter display labels: `Forwarded to PCF` → `→ PCF`, `Referred to PHO` → `→ PHO`.

---

## 1. The Problem

### Current State

The system has **one account per barangay** — a single `role='barangay'` user tied to a `barangay_id`. For example, the entire barangay of Poblacion has one login (`poblacion / admin123`).

### Why This Breaks in Real Disaster Response

During a typhoon (the #1 hazard in Kalibo, Aklan), the BDRRMC (Barangay Disaster Risk Reduction and Management Council) operates as a team — not a single person:

| Person | Location | What They're Doing |
|---|---|---|
| **Barangay Captain** | Municipal EOC / Evacuation Center | Coordinating with MDRRMO, making command decisions |
| **Secretary** | Barangay Hall | Processing evacuation lists, updating evac center capacity, managing logistics |
| **BHERT** | Field / Purok / Sitio | Going door-to-door, submitting incident reports, evacuating families |

Under the current one-account model:

- **Single point of failure** — If the Captain's phone dies or is unreachable, the entire barangay stops reporting
- **No audit trail** — Can't distinguish who submitted which report (Captain? Secretary? BHERT?)
- **Bottleneck** — Only one person can submit reports at a time
- **No role-appropriate access** — A BHERT in the field sees the same interface as the Captain at the EOC

### Real-World Reference

Under **RA 10121** (Philippine Disaster Risk Reduction and Management Act of 2010) and **DILG-NDRRMC Joint Memorandum Circular No. 2014-1**, every barangay is mandated to have a BDRRMC with:
- **Chairperson:** Punong Barangay (Captain)
- **Vice Chairperson:** Barangay Secretary
- **Members:** Kagawads, BHERT members (including Tanods), BHWs, CSO representatives

The system should mirror this actual organizational structure.

---

## 2. The Solution

### Overview

Add **sub-role** capability within the existing `barangay` role. Three sub-roles aligned with the actual BDRRMC structure:

```
┌─────────────────────────────────────────────────────┐
│  CAPTAIN (Admin)                                    │
│  ├── Full access to web dashboard + mobile app      │
│  ├── Manages all barangay users (Secretary + BHERT) │
│  ├── Can create/edit/delete incident reports        │
│  ├── Can review and forward reports to PCF          │
│  ├── Can dismiss reports                            │
│  └── Views activity log (scoped to own barangay)    │
│                                                     │
│  SECRETARY (Co-Admin / Coordinator)                 │
│  ├── Web dashboard + mobile app                     │
│  ├── Can manage BHERT accounts ONLY                 │
│  ├── Can view reports + update evac centers/alerts  │
│  ├── CANNOT create/edit incident reports            │
│  ├── CANNOT update report status                    │
│  └── CANNOT refer to PHO (Captain's authority)      │
│                                                     │
│  BHERT (Field Reporter)                             │
│  ├── Web (mobile-responsive) + mobile app           │
│  ├── Submits incident reports                       │
│  ├── Views own reports only (field isolation)       │
│  ├── Can edit own reports (if still Pending)        │
│  ├── Access to Emergency Hotlines (field backup)    │
│  └── CANNOT manage users or update status           │
└─────────────────────────────────────────────────────┘
```

### Permission Matrix

| Permission | Captain | Secretary | BHERT |
|---|:---:|:---:|:---:|
| Submit incident report | ✅ | ❌ | ✅ |
| Edit incident report | ✅ | ❌ | ✅ (own, Pending only) |
| View own reports only | ✅ (all barangay) | ✅ (all barangay) | ✅ (own only) |
| View all barangay reports | ✅ | ✅ | ❌ |
| Review report (Pending→Reviewed) | ✅ | ❌ | ❌ |
| Forward report to PCF | ✅ | ❌ | ❌ |
| Dismiss report | ✅ | ❌ | ❌ |
| Manage BHERT accounts | ✅ | ✅ (BHERT only) | ❌ |
| Create Secretary accounts | ✅ | ❌ | ❌ |
| Create Captain accounts | ❌ | ❌ | ❌ |
| View dashboard analytics | ✅ | ✅ | ❌ |
| Manage hotlines | ✅ | ✅ | ❌ (view only) |
| View Emergency Hotlines | ✅ | ✅ | ✅ |
| View activity log | ✅ | ❌ | ❌ |

> **Key restrictions:**
> - Secretary **cannot** create, edit, or submit incident reports — only Captain and BHERT can.
> - Secretary **cannot** update report status — only Captain (triage) and PCF (action) can.
> - Only `superadmin` can create or manage Captain accounts. Prevents self-elevation.
> - Only **one Captain per barangay** enforced at DB level.
> - Secretary can only create **BHERT** accounts (not Captain or Secretary).

### `can_manage_users` Truth Table

| Sub-role | `can_manage_users` |
|---|:---:|
| Captain | `1` / `TRUE` |
| Secretary | `1` / `TRUE` |
| BHERT | `0` / `FALSE` |

This flag is set automatically based on `sub_role`. Captain and Secretary can both manage users, but Secretary is limited to creating BHERT only.

### Platform Access

| Role | Mobile App | Web Dashboard |
|---|:---:|:---:|
| Captain | ✅ Full nav | ✅ Full sidebar |
| Secretary | ✅ No Create Incident tab | ✅ No Create Incident link |
| BHERT | ✅ 4-tab (Dashboard, Reports, Alerts, Call) | ✅ 4-link (Dashboard, Create Incident, My Reports, Hotlines) |

---

## 3. Captain Triage Workflow (Gatekeeper Model)

This is the core workflow. **Captain is the gatekeeper** — they triage reports before PCF sees them.

### Status Flow

```
BHERT submits report
        ↓
   ┌─ Pending ─────────────────────────────┐
   │  (Visible to Barangay only)           │
   │  Captain can: Review, Edit, Dismiss   │
   └───────────────────────────────────────┘
        ↓ Captain clicks "Review"
   ┌─ Reviewed ────────────────────────────┐
   │  (Still visible to Barangay only)     │
   │  Captain can: Forward to PCF, Dismiss │
   └───────────────────────────────────────┘
        ↓ Captain clicks "Forward to PCF"
   ┌─ Forwarded to PCF ───────────────────┐
   │  (NOW visible to PCF!)               │
   │  PCF can: Verify, Respond, Dismiss,  │
   │           Send to PHO                 │
   └───────────────────────────────────────┘
        ↓ PCF clicks "Verify"
   ┌─ Verified ────────────────────────────┐
   │  (Visible to PCF + Barangay)          │
   └───────────────────────────────────────┘
        ↓ PCF clicks "Respond"
   ┌─ Responding ──────────────────────────┐
   │  Ongoing response                     │
   └───────────────────────────────────────┘
        ↓ PCF clicks "Send to PHO"
   ┌─ Referred to PHO ─────────────────────┐
   │  (Visible to PHO)                     │
   └───────────────────────────────────────┘
        ↓ PCF resolves
   ┌─ Resolved / Dismissed ────────────────┐
   │  Terminal states                      │
   └───────────────────────────────────────┘
```

### Allowed Status Transitions (Server-Side Enforcement)

| Actor | Can set to |
|---|---|
| **Captain** | `Reviewed`, `Forwarded to PCF`, `Dismissed` |
| **PCF** | `Verified`, `Responding`, `Referred to PHO`, `Resolved`, `Dismissed` |
| **PHO** | `Responding`, `Resolved` |

> **Critical:** The API must look up the actor's role from the database using `user_id`. Never trust a role value sent by the client. The web session provides the role; the mobile API queries it.

### PCF Report Filtering

PCF **only** sees reports that are "Forwarded to PCF" or later. Pending and Reviewed reports are barangay-internal.

```sql
-- PCF WHERE clause (both web and API):
WHERE incident_reports.status IN (
    'Forwarded to PCF', 'Verified', 'Responding',
    'Referred to PHO', 'Resolved', 'Dismissed'
)
```

Barangay sees all their own reports regardless of status (Pending, Reviewed, Forwarded, etc.).

### All Valid Status Values

```sql
-- Used in CASE/ENUM/validation across the system:
'Pending', 'Reviewed', 'Forwarded to PCF', 'Verified',
'Responding', 'Referred to PHO', 'Resolved', 'Dismissed'
```

---

## 4. Context-Aware Report Attribution

The system shows **different attribution** depending on who's viewing:

| Viewer | Sees |
|---|---|
| **Barangay** (any sub-role) | "by [BHERT Name]" — the creator's name |
| **PCF / PHO / Superadmin** | "Barangay [Barangay Name]" — the barangay identity |

This is because barangay users need to know which BHERT submitted the report (accountability), while PCF/PHO need to know which barangay it came from (coordination).

### Implementation

- The `incident_reports.user_id` column stores the creator's user ID (already existed).
- The API `get_reports.php` JOINs the `users` table and returns `creator_name`.
- The UI conditionally displays:
  - `if (role === 'barangay') → show "by $creator_name"`
  - `else → show "Barangay $barangay_name"`

---

## 5. DRRM Disaster Type Color Coding

Each disaster type has a unique color for quick visual identification across the system.

### Color Palette

| Disaster Type | Icon Color | Background | Border |
|---|---|---|---|
| Typhoon | `#1565C0` (blue) | `#E3F2FD` | `#1565C0` |
| Flood | `#0277BD` (light blue) | `#E1F5FE` | `#0277BD` |
| Storm Surge | `#00838F` (teal) | `#E0F7FA` | `#00838F` |
| Earthquake | `#795548` (brown) | `#EFEBE9` | `#5D4037` |
| Landslide | `#6D4C41` (dark brown) | `#EFEBE9` | `#4E342E` |
| Fire | `#D32F2F` (red) | `#FFEBEE` | `#B71C1C` |
| Drought / El Niño | `#EF6C00` (orange) | `#FFF3E0` | `#E65100` |
| Disease Outbreak | `#7B1FA2` (purple) | `#F3E5F5` | `#6A1B9A` |
| Accident / Mass Casualty | `#AD1457` (pink) | `#FCE4EC` | `#880E4F` |
| Others | `#616161` (gray) | `#F5F5F5` | `#424242` |

### Where It Appears

- **Web incident-reports.php:** Colored badge in the Disaster Type column (dot + text, rounded pill)
- **Web create/edit dropdowns:** Emoji prefix on each option (🌀 Typhoon, 🌊 Flood, etc.)
- **Flutter create/edit dropdowns:** Colored dot prefix on each option
- **Flutter report cards:** Colored dot + text badge below the disaster type title
- **Flutter status badges:** Status-specific colors (Pending=yellow, Reviewed=blue, Forwarded=blue, Verified=primary, etc.)

### Implementation

- **PHP:** `disaster_type_color()`, `disaster_type_dot()`, `disaster_type_badge()` in `functions.php`
- **Flutter:** `DisasterTypeConfig` class in `lib/constants/disaster_type_config.dart` with `iconColors`, `backgroundColors`, `borderColors` maps

### Disaster Types Filter (DB-Driven)

The incident-reports filter dropdown queries the `disaster_types` table instead of hardcoded values:

```sql
SELECT name FROM disaster_types WHERE status = 'Active' ORDER BY id ASC
```

This keeps the filter in sync if new types are added by superadmin.

---

## 6. Database Schema Changes

### Column Additions to `users` Table

The minimal change — **2 columns added, no new tables:**

#### MySQL (PHP project)

```sql
ALTER TABLE users
  ADD COLUMN `sub_role` ENUM('captain','secretary','tanod') DEFAULT NULL
    AFTER `role`,
  ADD COLUMN `can_manage_users` TINYINT(1) DEFAULT 0
    AFTER `sub_role`;
```

#### PostgreSQL (Node.js project)

```sql
ALTER TABLE users
  ADD COLUMN sub_role VARCHAR(20) DEFAULT NULL,
  ADD COLUMN can_manage_users BOOLEAN DEFAULT FALSE;

ALTER TABLE users
  ADD CONSTRAINT users_sub_role_check
  CHECK (sub_role IN ('captain', 'secretary', 'tanod'));
```

### Migration: Existing 16 Barangay Accounts → Captain

```sql
-- MySQL
UPDATE users
SET sub_role = 'captain', can_manage_users = 1
WHERE role = 'barangay' AND sub_role IS NULL;

-- PostgreSQL
UPDATE users
SET sub_role = 'captain', can_manage_users = TRUE
WHERE role = 'barangay' AND sub_role IS NULL;
```

### One Captain Per Barangay (DB-Level Enforcement)

```sql
-- MySQL: enforced in application code (save_user.php)
-- Before INSERT, check:
SELECT id FROM users
WHERE role = 'barangay' AND sub_role = 'captain' AND barangay_id = ?
LIMIT 1;
-- If row exists → reject "This barangay already has a Captain."

-- PostgreSQL: same check in Node.js application code
SELECT id FROM users
WHERE role = 'barangay' AND sub_role = 'captain' AND barangay_id = $1
LIMIT 1;
```

### `disaster_types` Table (for DB-driven filter)

If not already present, ensure this table exists:

```sql
-- MySQL
CREATE TABLE IF NOT EXISTS disaster_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status ENUM('Active','Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- PostgreSQL
CREATE TABLE IF NOT EXISTS disaster_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Seed with the 10 DRRM types if empty.

### `incident_status_logs` Table (for audit trail)

Tracks every status change:

```sql
-- MySQL
CREATE TABLE incident_status_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    incident_report_id INT NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    remarks TEXT,
    updated_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- PostgreSQL
CREATE TABLE incident_status_logs (
    id SERIAL PRIMARY KEY,
    incident_report_id INTEGER NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    remarks TEXT,
    updated_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Why NOT a Full RBAC Table System

| Factor | Full RBAC | Simple `sub_role` |
|---|---|---|
| New tables | 3 | 0 |
| Migration complexity | High (seed 17+ rows) | Low (2 columns + UPDATE) |
| Permission checks | `user_has_permission()` DB query | `if ($sub_role === 'captain')` |
| Code changes needed | Every API endpoint | Only user-facing endpoints |
| Maintenance burden | High (admin GUI needed) | Low (ENUM constraint) |
| **Capstone fit** | Over-engineered | Appropriate scope |

For ~16 barangays with ~5-8 users each, a simple `sub_role` ENUM is the right tool.

---

## 7. Implementation Checklist (for Node.js port)

### Phase 1: Database Migration

**Files:** Migration SQL file

- Add `sub_role` and `can_manage_users` columns to `users`
- Migrate existing 16 barangay accounts to Captain
- Ensure `disaster_types` table exists with 10 DRRM types
- Ensure `incident_status_logs` table exists

### Phase 2: Login Response

**Files:** Login endpoint

- SELECT `sub_role`, `can_manage_users` from `users`
- Include both in the login response JSON

### Phase 3: User Management (CRUD)

**Files:** Create user, update user, toggle status, reset password endpoints

Key rules:
- `verifyActor()` helper: queries DB for actor's role/sub_role/can_manage_users
- Superadmin can do anything
- Captain (barangay + captain): can create Secretary/BHERT, edit any barangay user
- Secretary (barangay + secretary): can create BHERT only, can edit BHERT only
- Scope enforcement: `barangay_id` of new/edited user MUST match actor's `barangay_id`
- One Captain per barangay check before INSERT
- Secretary blocked from editing Captain accounts

### Phase 4: Get Users (Scoped)

**Files:** Get users endpoint

- Barangay Captain/Secretary: `WHERE barangay_id = ?` (own barangay only)
- Superadmin: no filter (sees all)
- SELECT includes `sub_role`, `can_manage_users`

### Phase 5: Web Session & Sidebar

**Files:** Login handler (session), sidebar template

- Store `sub_role` and `can_manage_users` in session alongside role
- Sidebar conditional rendering:
  - BHERT: Dashboard, Create Incident, My Reports, Hotlines (4 links)
  - Captain/Secretary: Full sidebar + Manage Users
  - Captain only: + Activity Log
  - Secretary: NO Create Incident link, NO Activity Log

### Phase 6: Flutter Auth & Navigation

**Files:** `auth_service.dart`, `barangay_main_screen.dart`

Auth getters:
```dart
static String? get currentSubRole => currentUser?['sub_role']?.toString();
static bool get isCaptain => currentSubRole == 'captain';
static bool get isSecretary => currentSubRole == 'secretary';
static bool get isTanod => currentSubRole == 'tanod';
static bool get canManageUsers => currentUser?['can_manage_users'] == true || ...;
```

Bottom nav:
- BHERT: 4 tabs (Dashboard, Reports, Alerts, Call)
- Captain/Secretary: 4 tabs (Dashboard, Reports, Alerts, Call)
- Secretary: FAB hidden (no Create Incident)
- Secretary: popup menu has no "Create Incident" option

### Phase 7: Captain Workflow (Status Changes)

**Files:** Status update endpoint (both web handler and API)

Web handler (`app/reports/update-status.php`):
- Allow: Captain, PCF, PHO
- Captain allowed statuses: `['Reviewed', 'Forwarded to PCF', 'Dismissed']`
- PCF allowed statuses: `['Verified', 'Responding', 'Referred to PHO', 'Resolved', 'Dismissed']`
- Insert into `incident_status_logs` on every status change
- If status = 'Referred to PHO', also set `referred_to_pho = 1`

API (`api/update_status.php`):
- Same logic but accepts JSON input
- Looks up actor role from DB using `user_id` (never trust client-sent role)
- Normalizes legacy label: 'Forwarded to PHO' → 'Referred to PHO'

Flutter (`reports_screen.dart`):
- Captain sees "Update Status" button on each report card
- Bottom sheet shows: Review (if Pending), Forward to PCF (if Reviewed), Dismiss (both)
- Calls `IncidentService.updateStatus()` which hits the API

### Phase 8: PCF Report Filtering

**Files:** Get reports endpoint, incident-reports page

- API: `WHERE status IN ('Forwarded to PCF','Verified','Responding','Referred to PHO','Resolved','Dismissed')` when `role = 'pcf'`
- Web: same WHERE clause for `$V_role == 'pcf'`
- Barangay: `WHERE barangay_id = ?` (sees all their own reports regardless of status)

### Phase 9: Secretary Incident Restrictions

**Files:** Create incident page, edit incident page

- Web: redirect Secretary away from `create-incident-report.php` and `edit-incident-report.php`
- Flutter: Secretary popup menu has no "Create Incident" option; FAB hidden
- Dashboard: "Create Report" button hidden for Secretary
- Incident Reports: "Create Report" button hidden for Secretary

### Phase 10: Context-Aware Attribution

**Files:** Report card widget, report detail modal, incident-reports table

- API returns `creator_name` (from JOIN on `users`)
- Barangay views: show "by [Creator Name]"
- PCF/PHO/Superadmin views: show "Barangay [Barangay Name]"
- Web: conditional column header ("By" for barangay, "Barangay" for others)
- Flutter: conditional Text widget in `report_card.dart` and `report_details_sheet.dart`

### Phase 11: DRRM Color Coding

**Files:** Color constants, form dropdowns, report cards, status badges

- PHP helpers: `disaster_type_color()`, `disaster_type_dot()`, `disaster_type_badge()` in `functions.php`
- Flutter: `DisasterTypeConfig` class with icon/background/border color maps
- Web dropdowns: emoji prefix on each disaster type option
- Flutter dropdowns: colored dot prefix on each option
- Web table: colored badge pill in Disaster Type column
- Flutter report cards: colored dot + text badge
- `status_class()` in PHP: maps all 8 statuses to badge CSS classes
- `StatusBadge` widget in Flutter: maps statuses to colors

### Phase 12: "Assistance Needed" Disabled

**Decision:** Moved to PCF level per boss. Commented out on both web and Flutter create/edit forms.

- Web `create-incident-report.php`: assistance section commented out
- Web `edit-incident-report.php`: assistance section commented out
- Flutter `create_incident_screen.dart`: assistance section commented out
- Flutter `edit_incident_screen.dart`: assistance section commented out
- The DB column still exists; data is still shown in report detail if present

---

## 8. API Endpoint Reference

| Endpoint | Method | Who can call | What it does |
|---|---|---|---|
| `api/login.php` | POST | Anyone | Returns user data including `sub_role`, `can_manage_users` |
| `api/save_user.php` | POST | Superadmin, Captain, Secretary | Creates user with role scoping |
| `api/get_users.php` | POST | Superadmin, Captain, Secretary | Lists users scoped by barangay |
| `api/update_user.php` | POST | Superadmin, Captain, Secretary | Edits user with role scoping |
| `api/toggle_user_status.php` | POST | Superadmin, Captain, Secretary | Activates/deactivates user |
| `api/reset_user_password.php` | POST | Superadmin, Captain, Secretary | Resets user password |
| `api/get_reports.php` | POST | All roles | Returns reports with role-based filtering |
| `api/update_status.php` | POST | Captain, PCF, PHO | Updates report status with role enforcement |

### `get_reports.php` Filtering by Role

```
barangay → WHERE barangay_id = ? (all statuses)
           + AND user_id = ? (if sub_role = 'tanod', own reports only)
           Captain/Secretary see all barangay reports; BHERT sees own only
pcf      → WHERE status IN ('Forwarded to PCF', 'Verified', ...)
pho      → WHERE referred_to_pho = 1 OR status IN ('Referred to PHO', ...)
superadmin → no filter (sees everything)
```

---

## 9. Web Page Reference

| Page | Captain | Secretary | BHERT |
|---|:---:|:---:|:---:|
| `dashboard.php` | ✅ | ✅ | ✅ |
| `incident-reports.php` | ✅ Review/Forward/Dismiss | ✅ View only | ✅ View + Edit (Pending) |
| `create-incident-report.php` | ✅ | ❌ Redirect | ✅ |
| `edit-incident-report.php` | ✅ | ❌ Redirect | ✅ (own, Pending) |
| `manage-users.php` | ✅ | ✅ (BHERT only) | ❌ |
| `user-activity.php` | ✅ | ❌ | ❌ |
| `evacuation-centers.php` | ✅ | ✅ | ✅ (view only) |
| `hotlines.php` | ✅ | ✅ | ✅ (view only) |
| `map.php` | ✅ | ✅ | ✅ (view only) |
| `barangay-alerts.php` | ✅ | ✅ | ✅ (view only) |

### Captain Action Dropdown (incident-reports.php)

When Captain views the reports table, each row has an "Action" dropdown:

| Status | Dropdown contains |
|---|---|
| Pending | View Details, Edit, Review, Dismiss |
| Reviewed | View Details, Forward to PCF, Dismiss |
| Other | View Details only |

---

## 10. Flutter Screen Reference

| Screen | Captain | Secretary | BHERT |
|---|:---:|:---:|:---:|
| Dashboard tab | ✅ | ✅ | ✅ |
| Reports tab | ✅ Full actions | ✅ View only | ✅ View + Edit (own only) |
| Alerts tab | ✅ | ✅ | ✅ |
| Call/Hotlines tab | ✅ | ✅ | ✅ |
| Create Incident | ✅ FAB + popup | ❌ Hidden | ✅ FAB + popup |
| Manage Users | ✅ Tab | ✅ Tab | ❌ Hidden |
| Profile | ✅ | ✅ | ✅ |

### Captain "Update Status" (Flutter reports_screen.dart)

- "Update Status" button appears on each report card when Captain
- Opens a bottom sheet with context-aware options:
  - Pending: Review, Dismiss
  - Reviewed: Forward to PCF, Dismiss

---

## 11. Defense Talking Points

### Problem Statement (30 seconds)

> "Currently, OBILAK has one account per barangay. During a typhoon, the Captain is at the Municipal EOC, the Secretary is at the Barangay Hall, and BHERTs are in the field — but they all share one login. This creates a single point of failure, no audit trail, and a reporting bottleneck."

### Solution (30 seconds)

> "We added a sub-role system aligned with the actual BDRRMC structure under RA 10121. The Captain is the barangay admin who triages reports before forwarding to PCF. The Secretary manages accounts and logistics but cannot create incidents. BHERTs submit reports from the field. Each role gets exactly the access they need."

### Technical Approach (20 seconds)

> "Instead of a complex RBAC table system, we used a simple `sub_role` ENUM column on the existing `users` table — just 2 columns added. The Captain acts as a triage gatekeeper: reports stay barangay-internal until the Captain explicitly forwards them to PCF. This prevents information overload at the provincial level."

### Why This Matters (20 seconds)

> "During Typhoon Frank-class events in Aklan, information fragmentation between barangays and the MDRRMO was a critical gap. Our system ensures that field reporters can submit real-time incident data, the Captain can make triage decisions, and PCF only sees reports that need their attention — with a clear audit trail of who did what."

---

## 12. Verification Checklist

| # | Scenario | Expected Result |
|---|---|---|
| 1 | Captain logs in → web | Full sidebar including Manage Users, Activity Log |
| 2 | Secretary logs in → web | Full sidebar minus Create Incident, Activity Log |
| 3 | BHERT logs in → web | 4 links: Dashboard, Create Incident, My Reports, Hotlines |
| 4 | BHERT logs in → mobile | 4 tabs: Dashboard, Reports, Alerts, Call |
| 5 | Captain creates Secretary | Secretary account created, `sub_role='secretary'` |
| 6 | Secretary creates BHERT | BHERT account created, `sub_role='tanod'` |
| 7 | Secretary tries to create Captain | Blocked |
| 8 | Secretary tries to create Secretary | Blocked (BHERT only) |
| 9 | Secretary tries to open Create Incident | Redirected to dashboard |
| 10 | Captain creates BHERT in wrong barangay | Blocked: scope violation |
| 11 | BHERT submits report | Status = Pending, visible to barangay only |
| 12 | Captain reviews report | Status = Reviewed, still barangay-only |
| 13 | Captain forwards to PCF | Status = Forwarded to PCF, NOW visible to PCF |
| 14 | Captain tries to set "Verified" | Blocked (Captain can only Review/Forward/Dismiss) |
| 15 | PCF verifies report | Status = Verified |
| 16 | PCF responds to report | Status = Responding |
| 17 | PCF sends to PHO | Status = Referred to PHO |
| 18 | PCF resolves report | Status = Resolved |
| 19 | Captain dismisses report | Status = Dismissed |
| 20 | Barangay views report | Shows "by [BHERT Name]" |
| 21 | PCF views report | Shows "Barangay [Barangay Name]" |
| 22 | Superadmin views all users | Sees all 16 Captain accounts + any Secretary/BHERT |
| 23 | Secretary tries to update report status | No status change buttons visible |
| 24 | BHERT tries to update report status | No status change buttons visible |
| 25 | One barangay tries to create 2nd Captain | Blocked: "already has a Captain" |
| 26 | BHERT 1 views reports | Sees only own reports |
| 27 | BHERT 2 views reports | Sees only own reports (not BHERT 1's) |
| 28 | Captain views reports | Sees all barangay reports (both BHERTs) |
| 29 | Secretary views reports | Sees all barangay reports (both BHERTs) |
| 30 | BHERT opens Hotlines (web) | Emergency Hotlines page loads |
| 31 | BHERT taps Call tab (mobile) | HotlinesScreen loads |

---

## 13. Changes Log (2026-08-23)

UI fixes, incident location improvements, and map enhancements. All changes are display/logic layer only — no DB schema changes, no new tables, no new columns.

### 13.1 Report No. wrapping fix

**Problem:** Report numbers like `2026-0048` wrapped onto two lines (`2026-` on one line, `0048` on the next) in the incident reports table for barangay roles.

**Fix:** Added `white-space: nowrap` via `.report-no` CSS class to the Report No. `<td>`.

**File:** `public/incident-reports.php`

### 13.2 Weather forecast cards — fill empty space

**Problem:** Forecast day cards had fixed width (`min-width: 64px` web / `width: 72` Flutter), leaving a big empty gap in the middle of the weather card.

**Fix:**
- Web: Added `flex: 1` to both `.weather-days` container and `.weather-day` cards
- Flutter: Replaced `SingleChildScrollView` + fixed-width `_WeatherDay` with `Row` of `Expanded` widgets

**Files:** `public/dashboard.php`, `flutter/.../widgets/dashboard_summary_view.dart`

### 13.3 Incident coordinates — clickable Google Maps + `exact_location` pipeline

**Problem:** Raw coordinates (`11.7015088, 122.3694887`) were unreadable to non-technical users. The `exact_location` field existed in DB but Flutter never sent or received it.

**Fix (8 files):**
- Web modal: coordinates now a clickable `<a>` link → `https://www.google.com/maps?q=LAT,LON`
- Flutter details sheet: coordinates are a tappable blue link that opens Google Maps via `UrlLauncher`
- Flutter pipeline fully wired:
  - `api/get_reports.php` — added `exact_location` to SELECT + response
  - `api/create_incident.php` — reads and saves `exact_location`
  - `api/update_incident.php` — reads and saves `exact_location`
  - `flutter/.../incident_service.dart` — added `exactLocation` param to `createIncident()` and `updateIncident()`
  - `flutter/.../create_incident_screen.dart` — new "Exact Location" text input field
  - `flutter/.../edit_incident_screen.dart` — new "Exact Location" text input field, prefills from report data

**Files:** `app/includes/functions.php`, `api/get_reports.php`, `api/create_incident.php`, `api/update_incident.php`, `flutter/.../services/incident_service.dart`, `flutter/.../screens/barangay/create_incident_screen.dart`, `flutter/.../screens/barangay/edit_incident_screen.dart`, `flutter/.../widgets/report_details_sheet.dart`

### 13.4 Status display abbreviation

**Problem:** `Forwarded to PCF` and `Referred to PHO` took too much space in the status column, making the table messy.

**Fix:** `status_display()` now returns shortened labels:
| DB Value | Display |
|---|---|
| `Forwarded to PCF` | `→ PCF` |
| `Referred to PHO` | `→ PHO` |
| `Forwarded to PHO` | `→ PHO` |
| All others | Unchanged |

DB values, SQL queries, filter logic, and API comparisons still use raw strings — this is display-only.

**File:** `app/includes/functions.php`

### 13.5 Disaster type badge abbreviation

**Problem:** `Accident / Mass Casualty Incident` (~35 chars) was too long for the badge in the reports table.

**Fix:** Abbreviated to `Accident / MCI` in the badge text. Full name preserved in `title` attribute (hover tooltip). An `$abbreviations` map in `disaster_type_badge()` makes it easy to add more abbreviations.

**File:** `app/includes/functions.php`

### 13.6 Map — Recent Incident brief below evac centers

**Problem:** The right panel on the barangay map only showed evacuation centers. No incident context for the selected barangay.

**Fix:** Added a "Recent Incident" card below the evacuation center cards showing the most recent incident for the selected barangay:
- Report number (`#0050`)
- Disaster type
- Affected / injured counts
- Barangay name, submitted date, status badge
- Shows "No recent incidents for this barangay." if none

SQL query in `map.php` expanded to include `created_at`, `affected_people`, `injured`.

**File:** `public/map.php`

### 13.7 Map — Brief updates on incident marker click

**Problem:** The incident brief only updated on barangay select. Clicking an incident marker only opened a Leaflet popup — the brief didn't change.

**Fix:** Extracted `renderIncidentBrief(incident)` as a standalone function. Added `marker.on('click', ...)` handler on incident markers that calls `renderIncidentBrief()` with the clicked incident's data.

**File:** `public/map.php`

### 13.8 Map — Brief gap fix

**Problem:** The incident brief was in a separate `#incidentBriefPanel` div outside `.evac-panel-body`. The evac panel was 505px tall with scroll, so with few evac centers there was a large empty gap before the brief.

**Fix:** Moved `#incidentBriefPanel` inside the scrollable `.evac-panel-body` via JS innerHTML (`panel.innerHTML = html + '<div id="incidentBriefPanel"></div>'`). The brief now sits directly below the evac cards with no gap.

**File:** `public/map.php`

### Node.js Porting Notes

For porting these changes to the Node.js + PostgreSQL version (`capstone_project/`):

1. **Status display** — Add a `status_display()` mapping function in the Node.js equivalent of `functions.php`
2. **Disaster type abbreviation** — Add an abbreviations map in the badge rendering logic
3. **Coordinates → Google Maps link** — In the report detail modal, wrap coordinates in an `<a href="https://www.google.com/maps?q=...">` tag
4. **`exact_location` pipeline** — Add the column to the `incident_reports` table if it doesn't exist, wire it through the API endpoints and Flutter service
5. **Weather card flex** — Apply the same CSS/Flutter changes
6. **Map incident brief** — Port the SQL query expansion and the `renderIncidentBrief()` JS function, plus the marker click handler

---

*Created: 2026-08-20 | Updated: 2026-08-23 | OBILAK — Barangay Sub-Role System Specification*
