# OBILAK Barangay Sub-Role System
## Technical Specification & Implementation Plan

> **Status:** Ready for Phase 1 Implementation  
> **Target Defense:** December 2026  
> **Scope:** Barangay level only (PCF/PHO alignment deferred to future phase)

---

## 1. Executive Summary

### The Problem
Currently: 1 account per barangay = single point of failure. During a typhoon, the Captain is at the Municipal EOC, the Secretary at the Barangay Hall, BHERT in the field — all need real-time incident reporting simultaneously. **Current system can't handle it.**

### The Solution
**RBAC-based sub-role system** aligned with RA 10121 BDRRMC structure:
- **Captain** (admin) → strategic decisions, escalate to PCF
- **Secretary** (coordinator) → real-time dashboard, evacuation center logistics, BHERT roster management
- **BHERT/Tanod** (reporters) → submit field incident reports via mobile

**Everything uses the existing 17-permission-key RBAC model** — no separate boolean columns, no hardcoded role checks.

---

## 2. Permission Matrix (17 Keys + 4 New Barangay-Specific)

### Permissions Used by All Barangay Sub-Roles

| Permission Key | Label | Captain | Secretary | BHERT | Notes |
|---|---|:---:|:---:|:---:|---|
| `view_map` | Barangay Map | ✅ | ✅ | ❌ | Field context |
| `view_alerts` | Alerts (read-only) | ✅ | ✅ | ❌ | PHO/PCF broadcasts stay visible |
| `view_evacuation_centers` | Evac Centers (read) | ✅ | ✅ | ✅ | BHERT sees capacity before routing |
| `view_hotlines` | Emergency Hotlines | ✅ | ✅ | ❌ | For coordination |
| `view_activity_log` | Activity Log (scoped) | ✅ | ❌ | ❌ | Captain audits team only |
| `manage_evacuation_center_status` | Update family count, supplies | ❌ | ✅ | ❌ | Secretary's coordination hub |
| `manage_evacuation_center_config` | Add/remove centers | ✅ | ❌ | ❌ | Captain strategic decision |
| `manage_users` | Create/pause accounts (within barangay) | ✅ | ✅ | ❌ | Secretary assists Captain |
| `grant_permissions` | Assign roles to users (within barangay) | ✅ | ✅ | ❌ | Secretary can grant within Secretary permissions only |
| `create_report` | Submit incident report | ❌ | ❌ | ✅ | BHERT field reporting |
| `view_incident_reports` | Read field reports | ✅ | ✅ | ✅ | See own/barangay reports |
| `update_report_status` | Mark Resolved/Escalated | ✅ | ❌ | ❌ | Captain decision only |
| `refer_to_pho` | Send to PHO | ✅ | ❌ | ❌ | Captain escalation only |

**Subtotal: 13 permissions** (17 from original RBAC + 4 barangay-specific, overlap accounted)

---

## 3. Role Definitions

### 🟦 Captain (Barangay Admin)

**What they do:**
- Strategic decision-making during incidents
- Approves Secretary's coordination decisions
- Escalates critical reports to PCF
- Manages BHERT roster (create/pause accounts)

**Sidebar (Web):**
```
Dashboard
Barangay Map
Alerts
Evacuation Centers
Activity Log  ← Audit own team only
Manage Users  ← Create Captain/Secretary/BHERT accounts
```

**Permissions Granted:**
```
☑ view_map
☑ view_alerts
☑ view_evacuation_centers
☑ view_hotlines
☑ view_activity_log (scoped: barangay only)
☑ manage_evacuation_center_config
☑ manage_users (within barangay)
☑ grant_permissions (within barangay)
☑ update_report_status
☑ refer_to_pho
```

**What Captain CANNOT grant:**
- `view_activity_log` to anyone (audit-only)
- `update_report_status` to Secretary (coordination ≠ decisions)
- `refer_to_pho` to Secretary (escalation = Captain's call)

---

### 🟨 Secretary (Co-Admin/Coordinator)

**What they do:**
- Real-time monitoring of Tanod reports on dashboard
- Updates evacuation center status (families arriving, supplies used)
- Manages BHERT roster (create Tanod accounts, pause on leave)
- Coordinates with evacuation center staff
- Handles logistics (supply tracking, health referrals)

**Sidebar (Web):**
```
Dashboard
Barangay Map
Alerts
Evacuation Centers  ← Can update status
My Reports  ← Own administrative notes
Manage Users  ← Create BHERT accounts
```

**Permissions Granted:**
```
☑ view_map
☑ view_alerts
☑ view_evacuation_centers
☑ view_hotlines
☑ manage_evacuation_center_status  ← Update family count, supplies, referrals
☑ manage_users (within barangay)
☑ grant_permissions (limited: can only grant what Secretary has)
☑ view_incident_reports (read-only, own barangay)
```

**What Secretary CANNOT grant:**
- `manage_users` to anyone (only Captain can)
- `update_report_status` (Captain's authority)
- `refer_to_pho` (Captain's authority)

---

### 🟩 BHERT/Tanod (Field Reporter)

**What they do:**
- Submit incident reports from the field via mobile app
- See evacuation center capacity before routing families
- Provide real-time information to Secretary's coordination dashboard

**Sidebar (Mobile):**
```
Create Incident  ← Report form
My Reports  ← See submitted reports
```

**Permissions Granted:**
```
☑ create_report
☑ view_evacuation_centers (read-only)
☑ view_incident_reports (read-only, own reports)
```

**What BHERT CANNOT do:**
- View other barangays' data
- Manage accounts
- Update evacuation center records
- Escalate reports

---

## 4. Implementation Phases

### Phase 1 (Weeks 1-2): MVP — Individual Accounts, No Approval Workflow

**What gets built:**
1. Add 4 new permission keys to the permissions table
2. Migrate existing 16 barangay accounts → Captain role + full permissions
3. Captain creates Secretary account (via GUI Manage Users modal)
4. Captain/Secretary create individual BHERT accounts
5. Activity Log scoped to barangay level
6. Flutter mobile app filters sidebar based on `create_report` permission

**Schema changes:**
```sql
-- No new columns needed! Use existing RBAC structure.
-- Add permissions to permissions table:
INSERT INTO permissions (perm_key, label, category) VALUES
('manage_evacuation_center_status', 'Update Evacuation Center Status', 'Evacuation'),
('manage_evacuation_center_config', 'Manage Evacuation Center Setup', 'Evacuation'),
('view_activity_log', 'View Activity Log (Scoped)', 'Admin'),
('view_incident_reports', 'View Incident Reports', 'Reports');

-- Migrate existing accounts:
-- (Use save_user_permission.php with Captain as superadmin proxy)
```

**Files to modify:**
- `permissions.php` - seed 4 new permission keys
- `save_user.php` - add account type dropdown (Captain/Secretary/BHERT)
- `manage-users.php` - GUI checklist filtered by current user's permissions
- `activity_log.php` - add barangay scope filter
- Flutter: `auth_service.dart`, `barangay_main_screen.dart`

**Testing checklist:**
- [ ] Captain logs in → sees full 11 permissions in sidebar
- [ ] Captain creates Secretary → Secretary sees 7 permissions
- [ ] Secretary creates Tanod → Tanod sees only "Create Incident"
- [ ] Activity Log shows only Poblacion barangay actions
- [ ] Secretary cannot grant `update_report_status` (greyed out in checklist)

---

### Phase 2 (Post-Defense): Approval Workflow

**What gets added:**
1. Reports have status: `pending_approval` → `submitted` → `resolved/escalated`
2. Captain/Secretary approve before report goes to PCF
3. Notification system (email/SMS to Captain when new report pending)

**Schema additions:**
```sql
ALTER TABLE incidents ADD COLUMN approval_status ENUM('pending','approved','rejected') DEFAULT 'pending';
ALTER TABLE incidents ADD COLUMN approved_by INT;
ALTER TABLE incidents ADD COLUMN approved_at TIMESTAMP NULL;
```

**Why defer?** 
- Phase 1 MVP is simpler, more defensible
- You can gather feedback from Captain/Secretary during field testing
- Decision: do they actually want approval bottlenecks, or straight-through reporting?

---

## 5. Database Schema Changes

### New Table: Account Types (Reference Only)

```sql
CREATE TABLE account_types (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL UNIQUE,  -- 'Barangay Captain', 'Secretary', 'BHERT Member'
  scope_level ENUM('barangay','municipal','provincial','system') NOT NULL,
  description VARCHAR(255)
);

INSERT INTO account_types (name, scope_level, description) VALUES
('Barangay Captain', 'barangay', 'Barangay-level admin, strategic decisions, escalation authority'),
('Secretary', 'barangay', 'Barangay coordinator, evacuation center management, roster'),
('BHERT Member', 'barangay', 'Field reporter, incident submission via mobile');
```

### New Columns on `users` Table

```sql
ALTER TABLE users
  ADD COLUMN account_type_id INT NULL REFERENCES account_types(id),
  ADD COLUMN created_by INT NULL REFERENCES users(id);
```

### New Rows in `permissions` Table

```sql
INSERT INTO permissions (perm_key, label, category, description) VALUES
('manage_evacuation_center_status', 'Update Evacuation Center Status', 'Evacuation', 
  'Update family count, supplies, referrals at centers'),
('manage_evacuation_center_config', 'Manage Evacuation Center Setup', 'Evacuation', 
  'Add/remove/modify evacuation centers'),
('view_activity_log', 'View Activity Log (Barangay-Scoped)', 'Admin', 
  'Audit barangay team actions only'),
('view_incident_reports', 'View Incident Reports', 'Reports', 
  'Read incident reports within scope');
```

### Migration: Existing Barangay Accounts → Captain

```sql
-- Get all existing barangay accounts and make them Captains
INSERT INTO user_permissions (user_id, perm_key, granted_by, granted_at)
SELECT u.id, p.perm_key, 1, NOW()
FROM users u
CROSS JOIN permissions p
WHERE u.role = 'barangay'
  AND p.perm_key IN (
    'view_map', 'view_alerts', 'view_evacuation_centers', 'view_hotlines',
    'view_activity_log', 'manage_evacuation_center_config', 'manage_users',
    'grant_permissions', 'update_report_status', 'refer_to_pho'
  );

-- Update account type
UPDATE users SET account_type_id = (SELECT id FROM account_types WHERE name = 'Barangay Captain')
WHERE role = 'barangay';
```

---

## 6. Activity Log Scoping

### Current Problem
```
Activity Log (No scoping):
  2:00 PM - PCF Admin: Broadcast "All EOC report 3 PM"
  2:01 PM - BHERT-Juan: Submitted "5 families stranded Purok 3"
  2:02 PM - PHO Admin: Alert "Dengue outbreak Aklan"
  2:03 PM - Secretary: Updated evac center (47 families)
  
Captain drowns in noise — can't audit own team.
```

### Solution: Barangay-Scoped View
```sql
-- Captain views Activity Log
SELECT * FROM activity_log
WHERE barangay_id = 'poblacion'  ← ONLY this barangay
  AND action_type IN ('create_report', 'update_report', 'update_evac_center', 'create_user', 'grant_permission')
ORDER BY created_at DESC;

-- Result:
  2:01 PM - BHERT-Juan: Submitted "5 families stranded Purok 3"
  2:03 PM - Secretary: Updated evac center (47 families)
  2:05 PM - BHERT-Maria: Updated evac center status
```

**Why keep PHO/PCF alerts visible?**
- Captain still needs to see emergency broadcasts (typhoon escalation, evacuation orders)
- Just not the operational noise (who made what decision at provincial level)

### Code Implementation
```php
// api/get_activity_log.php
$user = $_SESSION['user'];
$perms = user_has_permission($conn, $user['id'], 'view_activity_log');

if (!$perms) {
    send_response(false, 'Access denied');
}

// If Captain: show barangay + system-level alerts
$query = "SELECT * FROM activity_log 
WHERE (barangay_id = '{$user['barangay_id']}' 
   OR scope_level = 'system')
AND action_type IN ('create_report', 'update_report', 'update_evac_center', 'create_user', 'grant_permission', 'broadcast_alert')
ORDER BY created_at DESC LIMIT 100";

$result = mysqli_query($conn, $query);
send_response(true, 'Activity log retrieved', ['logs' => fetch_all($result)]);
```

---

## 7. Permission Assignment Rules (Privilege Escalation Prevention)

### Rule 1: Can Only Grant What You Have
```
Captain has: [view_map, view_alerts, ..., update_report_status, refer_to_pho]
Captain tries to grant to Secretary: 
  ✅ Can grant: view_map, view_alerts, etc.
  ❌ Cannot grant: manage_evacuation_center_config (Captain only), refer_to_pho (Captain only)
```

### Rule 2: Secretary Cannot Grant Admin Permissions
```
Secretary has: [view_map, manage_evacuation_center_status, manage_users, ...]
Secretary tries to grant to new user:
  ✅ Can grant: view_map, view_alerts, create_report
  ❌ Cannot grant: manage_users (co-admin only), grant_permissions (co-admin only)
```

**Implementation:**
```php
// get_grantable_permissions.php (already exists, reuse)
function get_grantable_permissions($conn, $user_id) {
    // Returns only permissions this user already has
    $query = "SELECT DISTINCT perm_key FROM user_permissions WHERE user_id = $user_id";
    $result = mysqli_query($conn, $query);
    return fetch_all($result);
}

// Manage Users modal:
// Display ONLY the permissions returned from get_grantable_permissions()
```

---

## 8. API Endpoints (Summary)

### New/Modified Endpoints

| Endpoint | Method | Purpose | Who Uses |
|----------|--------|---------|----------|
| `/get_my_permissions.php` | POST | Load user's permissions on login | All roles |
| `/get_grantable_permissions.php` | POST | Get permissions current user can assign | Captain, Secretary |
| `/save_user_permission.php` | POST | Grant/revoke permission | Captain, Secretary |
| `/get_account_types.php` | GET | Dropdown list (Captain, Secretary, BHERT) | Manage Users modal |
| `/get_activity_log.php` | POST | Activity log (scoped by barangay) | Captain |
| `/save_user.php` (modified) | POST | Create new user + assign account type | Captain, Secretary |

### Example: Captain Creates Tanod

```bash
POST /save_user.php
{
  "username": "tanod_juan",
  "password": "hashed_pwd",
  "barangay_id": "poblacion",
  "account_type_id": 3,  ← BHERT Member
  "created_by": 42  ← Captain's user_id
}

POST /save_user_permission.php (called 1x for Tanod)
{
  "user_id": 99,  ← New Tanod
  "perm_key": "create_report",
  "granted_by": 42  ← Captain
}

Response: { "success": true, "user_id": 99, "permissions": ["create_report", "view_evacuation_centers"] }
```

---

## 9. Web Dashboard Changes

### Manage Users Page (New/Enhanced)

**Flow:**
1. Captain navigates to **Manage Users**
2. See list: "Secretary-Poblacion", "Tanod-Juan", "Tanod-Maria"
3. Click **Edit** on "Tanod-Juan"
4. Modal shows checklist:
   ```
   Permissions Available to Assign:
   ☑ create_report
   ☑ view_evacuation_centers
   (All other permissions hidden — Captain doesn't have them)
   ```
5. Click **Save** → `save_user_permission.php` called
6. Tanod-Juan's sidebar updates automatically

**Code template:**
```html
<!-- manage-users.php -->
<div id="permissionModal" class="modal">
  <form onsubmit="savePermissions(event)">
    <div id="permissionCheckboxes"></div>
    <button type="submit">Save Permissions</button>
  </form>
</div>

<script>
async function editUser(userId) {
  const response = await fetch('/api/get_grantable_permissions.php', {
    method: 'POST',
    body: JSON.stringify({ user_id: userId })
  });
  const { permissions } = await response.json();
  
  // Build checklist from permissions array
  const html = permissions.map(p => `
    <label>
      <input type="checkbox" name="perm_${p.perm_key}" value="${p.perm_key}">
      ${p.label}
    </label>
  `).join('');
  
  document.getElementById('permissionCheckboxes').innerHTML = html;
  showModal();
}
</script>
```

### Sidebar (Conditional Rendering)

```php
<?php
// sidebar.php
$perms = $_SESSION['user_permissions']; // Loaded on login

if (in_array('view_map', $perms)) { ?>
  <li><a href="/map.php">Barangay Map</a></li>
<?php } ?>

<?php if (in_array('view_alerts', $perms)) { ?>
  <li><a href="/alerts.php">Alerts</a></li>
<?php } ?>

<?php if (in_array('view_activity_log', $perms)) { ?>
  <li><a href="/activity-log.php">Activity Log</a></li>
<?php } ?>

<?php if (in_array('manage_users', $perms)) { ?>
  <li><a href="/manage-users.php">Manage Users</a></li>
<?php } ?>
```

---

## 10. Flutter Mobile App Changes

### Auth Service (Modified)

```dart
// lib/services/auth_service.dart
class AuthService {
  List<String> userPermissions = [];

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$API_URL/login.php'),
      body: {'username': username, 'password': password}
    );

    final data = jsonDecode(response.body);
    
    if (data['success']) {
      _token = data['token'];
      _userId = data['user_id'];
      
      // NEW: Fetch permissions
      await _loadPermissions();
      
      return true;
    }
    return false;
  }

  Future<void> _loadPermissions() async {
    final response = await http.post(
      Uri.parse('$API_URL/get_my_permissions.php'),
      headers: {'Authorization': 'Bearer $_token'},
      body: {'user_id': _userId}
    );

    final data = jsonDecode(response.body);
    userPermissions = List<String>.from(data['permissions']);
  }

  bool hasPermission(String permKey) => userPermissions.contains(permKey);
}
```

### Main Screen (Conditional Tab Navigation)

```dart
// lib/screens/barangay_main_screen.dart
class BarangayMainScreen extends StatefulWidget {
  @override
  State<BarangayMainScreen> createState() => _BarangayMainScreenState();
}

class _BarangayMainScreenState extends State<BarangayMainScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: [
          // BHERT sees: Create Incident
          if (auth.hasPermission('create_report'))
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle),
              label: 'Create Incident'
            ),
          
          // Captain sees: Map, Alerts, Evac Center
          if (auth.hasPermission('view_map'))
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Map'
            ),
          
          if (auth.hasPermission('view_alerts'))
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Alerts'
            ),
          
          if (auth.hasPermission('view_evacuation_centers'))
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Evac Centers'
            ),
        ],
        onTap: (index) => _navigateTo(index),
      ),
    );
  }
}
```

---

## 11. Testing Strategy

### Unit Tests (Permission Model)
```php
// test/PermissionTest.php
function test_captain_can_grant_to_secretary() {
    $captain_perms = get_user_permissions($conn, 'captain_poblacion');
    $grantable = get_grantable_permissions($conn, 'captain_poblacion');
    
    assert(in_array('manage_users', $grantable));
    assert(in_array('update_report_status', $grantable));
}

function test_secretary_cannot_grant_refer_to_pho() {
    $grantable = get_grantable_permissions($conn, 'secretary_poblacion');
    assert(!in_array('refer_to_pho', $grantable));
}
```

### Integration Tests (Full Flow)
```
Scenario: Captain creates BHERT, field reporter submits incident

1. Captain logs in → Sees "Manage Users"
2. Captain creates "Tanod-Juan" (account type: BHERT)
3. System grants "create_report" permission to Tanod-Juan
4. Tanod-Juan logs into mobile → Sidebar shows only "Create Incident"
5. Tanod-Juan submits report → Report appears in Secretary's dashboard
6. Secretary updates evac center: "20 families arrived"
7. Captain views Activity Log → Sees both actions (Tanod submit + Secretary update)
8. Captain tries to grant "refer_to_pho" to Secretary → Blocked (Secretary doesn't have it)
```

---

## 12. Migration Checklist

- [ ] Add 4 new permission rows to `permissions` table
- [ ] Add `account_type_id` and `created_by` columns to `users` table
- [ ] Create `account_types` table with Captain/Secretary/BHERT entries
- [ ] Run migration script: Existing 16 barangay accounts → Captain + all permissions
- [ ] Deploy new PHP endpoints (`get_account_types.php`, etc.)
- [ ] Update `manage-users.php` with permission checklist
- [ ] Update `activity_log.php` with barangay scope filter
- [ ] Deploy Flutter changes (auth service + conditional nav)
- [ ] Test on dev server before production
- [ ] Load test: Can Captain create 50+ Tanod accounts?

---

## 13. Defense Summary (What You'll Say)

> "The current system has one account per barangay — a single point of failure. During a typhoon, the Captain is at the EOC, the Secretary is at the hall, and field workers need to report simultaneously. 
>
> Our new system uses a **permission-based hierarchy** aligned with RA 10121. Captain is admin, Secretary is coordinator managing evacuation logistics, and BHERT are field reporters. Each gets exactly the permissions they need, nothing more.
>
> **Phase 1:** Individual Tanod accounts with full audit trail. No approval bottlenecks — reports go straight to Secretary's dashboard.
>
> **Phase 2 (future):** Approval workflow if field testing shows it's needed.
>
> The entire system is built on the **17-permission RBAC model we already have** — no separate role table, no hardcoded checks. Superadmin opens a GUI, clicks checkboxes, saves. Done. The dashboard automatically adapts based on permissions. Everything is audited."

---

## 14. Files Summary (What to Modify/Create)

### PHP Backend
- `api/get_account_types.php` - NEW
- `api/get_activity_log.php` - MODIFY (add barangay scope)
- `manage-users.php` - MODIFY (add permission checklist modal)
- `save_user.php` - MODIFY (add account type parameter)
- `includes/api_helper.php` - (reuse existing permission functions)

### Database
- `database/migrations/add_barangay_subroles.sql` - NEW
- `database/seeds/permission_keys.sql` - MODIFY (add 4 new rows)

### Flutter
- `lib/services/auth_service.dart` - MODIFY (add permission loading)
- `lib/screens/barangay_main_screen.dart` - MODIFY (conditional nav)

### Documentation
- This spec document
- Deployment guide
- User manual for Captain/Secretary account management

---

## 15. Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Secretary gets permission to `refer_to_pho` | Checklist greys out permissions Secretary doesn't have |
| Circular permission grants (A grants to B, B grants to A) | Add check: cannot grant to users above own hierarchy level |
| Activity log becomes too large | Archive old logs weekly, Captain views only last 30 days |
| BHERT account created without permission | `manage_users` restricted to Captain/Secretary only |
| Captain forgets to create Secretary | Default: new barangay account gets Captain permissions (can be downgraded) |

---

**End of Specification**

*Next step: Await approval to begin Phase 1 implementation.*
