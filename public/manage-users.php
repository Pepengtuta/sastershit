<?php
$V_page_title = "Manage Users";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_can_manage = (int)($_SESSION['can_manage_users'] ?? 0);
$V_is_mdr = ($V_role === 'pcf' && in_array($V_sub_role, ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay']));
$V_mdr_sub = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay'];
$V_is_pho = ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null));

// Only superadmin or barangay Chairman/Secretary or PCF MDR can access.
if ($V_role != 'superadmin' && !$V_can_manage) {
    header("Location: dashboard.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_actor_id = (int)$_SESSION['user_id'];
$V_is_superadmin = ($V_role === 'superadmin');

// Scope: superadmin sees all, barangay admins see own barangay, MDR sees scoped pcf users.
if ($V_is_superadmin) {
    $UserQuery = "SELECT users.*, barangays.name AS barangay_name
                  FROM users
                  LEFT JOIN barangays ON users.barangay_id = barangays.id
                  ORDER BY users.role ASC, users.name ASC";
    $UserStmt = mysqli_prepare($connection, $UserQuery);
    mysqli_stmt_execute($UserStmt);
} elseif ($V_is_mdr) {
    // MDR actors: mdr_admin sees all pcf users; others see only matching sub_role.
    if ($V_sub_role === 'mdr_admin') {
        $UserQuery = "SELECT users.*, barangays.name AS barangay_name
                      FROM users
                      LEFT JOIN barangays ON users.barangay_id = barangays.id
                      WHERE users.role = 'pcf'
                      ORDER BY users.sub_role ASC, users.name ASC";
        $UserStmt = mysqli_prepare($connection, $UserQuery);
        mysqli_stmt_execute($UserStmt);
    } else {
        $UserQuery = "SELECT users.*, barangays.name AS barangay_name
                      FROM users
                      LEFT JOIN barangays ON users.barangay_id = barangays.id
                      WHERE users.role = 'pcf' AND users.sub_role = ?
                      ORDER BY users.name ASC";
        $UserStmt = mysqli_prepare($connection, $UserQuery);
        mysqli_stmt_bind_param($UserStmt, "s", $V_sub_role);
        mysqli_stmt_execute($UserStmt);
    }
} elseif ($V_is_pho) {
    // PHO Admin: manages PDRRMO and Governor accounts (role pho).
    $UserQuery = "SELECT users.*, barangays.name AS barangay_name
                  FROM users
                  LEFT JOIN barangays ON users.barangay_id = barangays.id
                  WHERE users.role = 'pho' AND users.sub_role IN ('pdrrmo', 'governor')
                  ORDER BY users.sub_role ASC, users.name ASC";
    $UserStmt = mysqli_prepare($connection, $UserQuery);
    mysqli_stmt_execute($UserStmt);
} else {
    $V_my_barangay = (int)($_SESSION['barangay_id'] ?? 0);
    $UserQuery = "SELECT users.*, barangays.name AS barangay_name
                  FROM users
                  LEFT JOIN barangays ON users.barangay_id = barangays.id
                  WHERE users.barangay_id = ?
                  ORDER BY users.sub_role ASC, users.name ASC";
    $UserStmt = mysqli_prepare($connection, $UserQuery);
    mysqli_stmt_bind_param($UserStmt, "i", $V_my_barangay);
    mysqli_stmt_execute($UserStmt);
}
$UserResult = mysqli_stmt_get_result($UserStmt);

// Barangays for the create/edit dropdowns.
$BrgyResult = mysqli_query($connection, "SELECT id, name, population FROM barangays ORDER BY name ASC");
$V_barangays = [];
if ($BrgyResult) {
    while ($b = mysqli_fetch_assoc($BrgyResult)) { $V_barangays[] = $b; }
}

$V_roles = ['superadmin', 'pcf', 'pho', 'barangay'];
$V_sub_roles = $V_is_mdr ? ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay'] : ($V_is_pho ? ['pdrrmo', 'governor'] : ['captain', 'secretary', 'tanod']);

// --- Barangay population display/edit (inline, in header) ---
// Visible for Barangay Captain/Secretary (own barangay) and Superadmin (dropdown of barangays).
$V_show_population_ui = false;
$V_population = 0;
$V_population_barangay_id = 0;
$V_population_barangay_name = '';

if ($V_is_superadmin) {
    // Superadmin: editable via barangay dropdown. Default to none selected.
    $V_show_population_ui = true;
    $V_population_barangays_list = $V_barangays; // reuse the barangays list fetched above
} elseif ($V_role === 'barangay' && ($V_sub_role === 'captain' || $V_sub_role === 'secretary')) {
    // Barangay Captain/Secretary: own barangay only.
    $V_show_population_ui = true;
    $V_population_barangay_id = (int)($_SESSION['barangay_id'] ?? 0);
    $V_population_barangay_name = $_SESSION['barangay_name'] ?? '';
    $V_population = (int)($_SESSION['population'] ?? 0);
    if ($V_population === 0 && $V_population_barangay_id > 0) {
        $PopStmt = mysqli_prepare($connection, "SELECT name, population FROM barangays WHERE id = ? LIMIT 1");
        mysqli_stmt_bind_param($PopStmt, "i", $V_population_barangay_id);
        mysqli_stmt_execute($PopStmt);
        $PopResult = mysqli_stmt_get_result($PopStmt);
        if ($PopRow = mysqli_fetch_assoc($PopResult)) {
            $V_population = (int)$PopRow['population'];
            $V_population_barangay_name = $PopRow['name'] ?? $V_population_barangay_name;
        }
    }
}

function render_barangay_options($V_barangays, $V_selected = 0) {
    $out = '<option value="">— Select barangay —</option>';
    foreach ($V_barangays as $b) {
        $sel = ((int)$b['id'] === (int)$V_selected) ? ' selected' : '';
        $out .= '<option value="' . h($b['id']) . '"' . $sel . '>' . h($b['name']) . '</option>';
    }
    return $out;
}
function render_role_options($V_roles, $V_selected = '') {
    $out = '';
    foreach ($V_roles as $r) {
        $sel = ($r === $V_selected) ? ' selected' : '';
        $out .= '<option value="' . h($r) . '"' . $sel . '>' . h(role_name($r)) . '</option>';
    }
    return $out;
}
function render_sub_role_options($V_sub_roles, $V_selected = '') {
    // Picker labels keep the town visible for the two mayor sub-roles (both display as "Mayor").
    $V_picker_labels = ['mayor_kalibo' => 'Mayor (Kalibo)', 'mayor_ibajay' => 'Mayor (Ibajay)'];
    $out = '<option value="">— None —</option>';
    foreach ($V_sub_roles as $sr) {
        $sel = ($sr === $V_selected) ? ' selected' : '';
        $label = $V_picker_labels[$sr] ?? sub_role_name($sr);
        $out .= '<option value="' . h($sr) . '"' . $sel . '>' . h($label) . '</option>';
    }
    return $out;
}

$V_ok = $_GET['ok'] ?? '';
$V_err = $_GET['err'] ?? '';
$V_p_ok = $_GET['p_ok'] ?? '';
$V_perr = $_GET['perr'] ?? '';
$V_modals = '';
?>

<?php if ($V_p_ok != '') { ?>
    <div class="alert alert-success"><?php echo h($V_p_ok); ?></div>
<?php } ?>
<?php if ($V_perr != '') { ?>
    <div class="alert alert-danger"><?php echo h($V_perr); ?></div>
<?php } ?>
<?php if ($V_ok != '') { ?>
    <div class="alert alert-success"><?php echo h($V_ok); ?></div>
<?php } ?>
<?php if ($V_err != '') { ?>
    <div class="alert alert-danger"><?php echo h($V_err); ?></div>
<?php } ?>

<style>
/* Let the Action dropdown show outside the table without being clipped. */
.panel-card,
.table-wrap,
.custom-table,
.custom-table tbody,
.custom-table tr,
.custom-table td {
    overflow: visible !important;
}
.user-action-cell .dropdown-menu {
    z-index: 3000;
}
</style>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Manage Users</h2>
            <p>Create and manage system and barangay accounts.</p>
        </div>
        <div>
            <button type="button" class="btn btn-danger" data-bs-toggle="modal" data-bs-target="#createUserModal">
                <span class="material-symbols-outlined icon-md" style="vertical-align:middle;">person_add</span> Add User
            </button>
        </div>
    </div>

    <?php if ($V_show_population_ui) { ?>
    <form class="panel-card mb-3 border p-3" method="POST" action="../app/users/update-barangay-population.php" id="popForm" style="background:#f8f9fa;"
          onsubmit="return validatePopulationForm();">
        <?php echo csrf_field(); ?>
        <div class="d-flex flex-wrap align-items-center gap-3">
            <span class="material-symbols-outlined" style="color:#dc3545;">groups</span>
            <div>
                <div class="text-muted small">Barangay Population</div>
                <div class="fw-bold" id="popDisplay">
                    <?php if ($V_is_superadmin) { ?>
                        -- (select a barangay) --
                    <?php } else { ?>
                        <?php echo h($V_population_barangay_name); ?>: <?php echo number_format($V_population); ?>
                    <?php } ?>
                </div>
            </div>
            <?php if ($V_is_superadmin) { ?>
                <select name="N_barangay_id" id="popBarangaySelect" class="form-select form-select-sm" style="max-width:260px;" onchange="updatePopDisplay();">
                    <option value="">— Select barangay —</option>
                    <?php foreach ($V_population_barangays_list as $pb) { ?>
                        <option value="<?php echo (int)$pb['id']; ?>" data-pop="<?php echo (int)$pb['population']; ?>" data-name="<?php echo h($pb['name']); ?>"><?php echo h($pb['name']); ?></option>
                    <?php } ?>
                </select>
            <?php } else { ?>
                <input type="hidden" name="N_barangay_id" value="<?php echo (int)$V_population_barangay_id; ?>">
            <?php } ?>
            <input type="text" inputmode="numeric" pattern="[0-9]*" name="N_population" id="popInput" class="form-control form-control-sm" min="0" maxlength="8" style="max-width:160px;" placeholder="Population" aria-describedby="popError" value="<?php echo $V_is_superadmin ? '' : $V_population; ?>" oninput="stripNonDigits(this);">
            <button type="submit" class="btn btn-sm btn-danger">Save Population</button>
        </div>
        <div id="popError" class="text-danger small mt-1" style="display:none;"></div>
        <div class="small text-muted mt-1">Used to auto-fill the "Affected" count on natural disaster incident reports.</div>
    </form>
    <?php } ?>

    <div class="filter-bar">
        <input type="text" id="userSearch" class="form-control" placeholder="Search name, username, barangay...">
        <select id="userRoleFilter" class="form-select">
            <option value="">All roles</option>
            <?php foreach ($V_roles as $role) { ?>
                <option value="<?php echo h($role); ?>"><?php echo h(role_name($role)); ?></option>
            <?php } ?>
        </select>
        <select id="userSubRoleFilter" class="form-select">
            <option value="">All sub-roles</option>
            <?php foreach ($V_sub_roles as $sr) { ?>
                <option value="<?php echo h($sr); ?>"><?php echo h(sub_role_name($sr)); ?></option>
            <?php } ?>
        </select>
        <button type="button" class="btn btn-light border" onclick="resetUserFilters()">Reset</button>
    </div>

    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Username</th>
                    <th>Role</th>
                    <th>Sub-Role</th>
                    <th>Barangay</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($UserResult && mysqli_num_rows($UserResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($UserResult)) {
                        $V_uid = (int)$row['id'];
                        $V_is_self = ($V_uid === $V_actor_id);
                        $V_status = $row['status'] ?? 'Active';
                        $V_sub = $row['sub_role'] ?? '';
                        $V_sub_display = $V_sub ? sub_role_name($V_sub) : '-';
                        $V_search_text = $row['name'] . ' ' . $row['username'] . ' ' . ($row['barangay_name'] ?? '') . ' ' . $V_sub;
                    ?>
                        <tr class="user-row"
                            data-search="<?php echo h(strtolower($V_search_text)); ?>"
                            data-role="<?php echo h(strtolower($row['role'])); ?>"
                            data-subrole="<?php echo h(strtolower($V_sub)); ?>">
                            <td><strong><?php echo h($row['name']); ?></strong><?php echo $V_is_self ? ' <span class="soft-badge badge-soft-info">You</span>' : ''; ?></td>
                            <td><?php echo h($row['username']); ?></td>
                            <td><?php echo h(role_name($row['role'])); ?></td>
                            <td>
                                <?php if ($V_sub) { ?>
                                    <span class="soft-badge <?php
                                        if ($V_sub === 'captain') echo 'badge-soft-danger';
                                        elseif ($V_sub === 'secretary') echo 'badge-soft-info';
                                        elseif ($V_sub === 'mdr_admin') echo 'badge-soft-warning';
                                        elseif ($V_sub === 'mdr_kalibo') echo 'badge-soft-info';
                                        elseif ($V_sub === 'mdr_ibajay') echo 'badge-soft-success';
                                        elseif ($V_sub === 'pdrrmo') echo 'badge-soft-danger';
                                        elseif ($V_sub === 'governor') echo 'badge-soft-warning';
                                        elseif ($V_sub === 'mayor_kalibo') echo 'badge-soft-warning';
                                        elseif ($V_sub === 'mayor_ibajay') echo 'badge-soft-warning';
                                        else echo 'badge-soft-secondary';
                                    ?>">
                                        <?php echo h($V_sub_display); ?>
                                    </span>
                                <?php } else { echo '-'; } ?>
                            </td>
                            <td><?php echo h($row['barangay_name'] ?: '-'); ?></td>
                            <td><span class="soft-badge <?php echo h(user_status_class($V_status)); ?>"><?php echo h($V_status); ?></span></td>
                            <td><?php echo date('M d, Y', strtotime($row['created_at'])); ?></td>
                            <td class="user-action-cell">
                                <?php
                                // Determine if current user can manage this target user.
                                $V_target_role = $row['role'] ?? '';
                                $V_target_sub = $row['sub_role'] ?? '';
                                $V_can_manage_target = true;
                                if ($V_is_self) {
                                    $V_can_manage_target = false;
                                } elseif ($V_is_superadmin) {
                                    $V_can_manage_target = true;
                                } elseif ($V_is_mdr) {
                                    // MDR actors: only pcf users, scoped by sub_role.
                                    $V_can_manage_target = false;
                                    if ($V_target_role === 'pcf') {
                                        if ($V_sub_role === 'mdr_admin') {
                                            $V_can_manage_target = true;
                                        } elseif ($V_sub_role === 'mdr_kalibo' && $V_target_sub === 'mdr_kalibo') {
                                            $V_can_manage_target = true;
                                        } elseif ($V_sub_role === 'mdr_ibajay' && $V_target_sub === 'mdr_ibajay') {
                                            $V_can_manage_target = true;
                                        }
                                    }
                                } elseif ($V_is_pho) {
                                    // PHO Admin: manages PDRRMO and Governor accounts.
                                    $V_can_manage_target = ($V_target_role === 'pho' && in_array($V_target_sub, ['pdrrmo', 'governor'], true));
                                } else {
                                    // Barangay admin rules.
                                    if ($V_target_sub === 'captain') {
                                        $V_can_manage_target = false;
                                    }
                                }
                                ?>
                                <?php if ($V_can_manage_target) { ?>
                                <div class="dropdown">
                                    <button class="btn btn-sm btn-dark dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                        Action
                                    </button>
                                    <ul class="dropdown-menu dropdown-menu-end">
                                        <li>
                                            <button class="dropdown-item" type="button" data-bs-toggle="modal" data-bs-target="#editUserModal<?php echo $V_uid; ?>">Edit</button>
                                        </li>
                                        <li>
                                            <button class="dropdown-item" type="button" data-bs-toggle="modal" data-bs-target="#resetUserModal<?php echo $V_uid; ?>">Reset Password</button>
                                        </li>
                                        <li><hr class="dropdown-divider"></li>
                                        <li>
                                            <form method="POST" action="../app/users/toggle-status.php?id=<?php echo $V_uid; ?>" class="m-0" onsubmit="return confirm('<?php echo $V_status === 'Active' ? 'Deactivate' : 'Reactivate'; ?> this account?');">
                                                <?php echo csrf_field(); ?>
                                                <?php if ($V_status === 'Active') { ?>
                                                    <button type="submit" class="dropdown-item text-danger">Deactivate</button>
                                                <?php } else { ?>
                                                    <button type="submit" class="dropdown-item text-success">Reactivate</button>
                                                <?php } ?>
                                            </form>
                                        </li>
                                    </ul>
                                </div>
                                <?php } ?>
                            </td>
                        </tr>
                        <?php
                        ob_start();
                        ?>
                        <!-- Edit modal for user <?php echo $V_uid; ?> -->
                        <div class="modal fade" id="editUserModal<?php echo $V_uid; ?>" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog">
                            <div class="modal-content">
                              <form method="POST" action="../app/users/update-user.php?id=<?php echo $V_uid; ?>">
                                <?php echo csrf_field(); ?>
                                <div class="modal-header">
                                  <h5 class="modal-title">Edit User</h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                </div>
                                <div class="modal-body">
                                  <div class="mb-3">
                                    <label class="form-label">Full name</label>
                                    <input type="text" name="N_name" class="form-control" value="<?php echo h($row['name']); ?>" required>
                                  </div>
                                  <div class="mb-3">
                                    <label class="form-label">Username</label>
                                    <input type="text" name="N_username" class="form-control" value="<?php echo h($row['username']); ?>" required>
                                  </div>
                                  <?php if ($V_is_superadmin) { ?>
                                  <div class="mb-3">
                                    <label class="form-label">Role</label>
                                    <select name="N_role" class="form-select role-select"
                                            data-brgy-target="editBrgyWrap<?php echo $V_uid; ?>"
                                            data-subrole-target="editSubRoleWrap<?php echo $V_uid; ?>"
                                            <?php echo $V_is_self ? 'disabled' : ''; ?> required>
                                      <?php echo render_role_options($V_roles, $row['role']); ?>
                                    </select>
                                    <?php if ($V_is_self) { ?>
                                      <input type="hidden" name="N_role" value="<?php echo h($row['role']); ?>">
                                      <small class="text-muted">You cannot change your own role.</small>
                                    <?php } ?>
                                  </div>
                                  <?php } elseif ($V_is_mdr) { ?>
                                    <input type="hidden" name="N_role" value="pcf">
                                  <?php } elseif ($V_is_pho) { ?>
                                    <input type="hidden" name="N_role" value="pho">
                                  <?php } else { ?>
                                    <input type="hidden" name="N_role" value="barangay">
                                  <?php } ?>
                                  <div class="mb-3" id="editSubRoleWrap<?php echo $V_uid; ?>" style="<?php echo ($V_is_superadmin && $row['role'] !== 'barangay' && $row['role'] !== 'pcf') ? 'display:none;' : ''; ?>">
                                    <label class="form-label">Sub-Role</label>
                                    <select name="N_sub_role" class="form-select sub-role-select">
                                      <?php
                                      if ($V_is_mdr) {
                                          $V_edit_mdr_target = $V_sub_role;
                                          $V_target_sr = $row['sub_role'] ?? '';
                                          // mdr_admin can edit to any mdr sub_role; others restricted to their own.
                                          if ($V_sub_role === 'mdr_admin') {
                                              $V_edit_allowed = $V_mdr_sub;
                                          } else {
                                              $V_edit_allowed = [$V_sub_role];
                                          }
                                      } elseif ($V_is_pho) {
                                          $V_edit_allowed = ['pdrrmo', 'governor'];
                                      } elseif (!$V_is_superadmin) {
                                          $V_edit_allowed = ($V_sub_role === 'secretary') ? ['tanod'] : ['secretary', 'tanod'];
                                      } else {
                                          $V_edit_allowed = ($row['role'] === 'pcf')
                                              ? ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay']
                                              : $V_sub_roles;
                                      }
                                      echo render_sub_role_options($V_edit_allowed, $V_sub);
                                      ?>
                                    </select>
                                    <?php if ($V_is_mdr) { ?>
                                      <small class="text-muted">MDR Admin can assign any MDR sub-role. MDR-Kalibo/Ibajay can only manage their own sub-role.</small>
                                    <?php } elseif ($V_is_pho) { ?>
                                      <small class="text-muted">PHO Admin manages PDRRMO and Governor accounts.</small>
                                    <?php } else { ?>
                                      <small class="text-muted">Chairman = full admin. Secretary = manage BHERTs. BHERT = field reporter.</small>
                                    <?php } ?>
                                  </div>
                                  <?php if ($V_is_superadmin) { ?>
                                  <div class="mb-3" id="editBrgyWrap<?php echo $V_uid; ?>" style="<?php echo $row['role'] === 'barangay' ? '' : 'display:none;'; ?>">
                                    <label class="form-label">Barangay</label>
                                    <select name="N_barangay_id" class="form-select">
                                      <?php echo render_barangay_options($V_barangays, $row['barangay_id'] ?? 0); ?>
                                    </select>
                                  </div>
                                  <?php } elseif ($V_is_mdr) { ?>
                                    <input type="hidden" name="N_barangay_id" value="0">
                                  <?php } elseif ($V_is_pho) { ?>
                                    <input type="hidden" name="N_barangay_id" value="0">
                                  <?php } else { ?>
                                    <input type="hidden" name="N_barangay_id" value="<?php echo (int)($_SESSION['barangay_id'] ?? 0); ?>">
                                  <?php } ?>
                                </div>
                                <div class="modal-footer">
                                  <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                                  <button type="submit" class="btn btn-danger">Save changes</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                        <!-- Reset password modal for user <?php echo $V_uid; ?> -->
                        <div class="modal fade" id="resetUserModal<?php echo $V_uid; ?>" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog">
                            <div class="modal-content">
                              <form method="POST" action="../app/users/reset-password.php?id=<?php echo $V_uid; ?>">
                                <?php echo csrf_field(); ?>
                                <div class="modal-header">
                                  <h5 class="modal-title">Reset Password</h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                </div>
                                <div class="modal-body">
                                  <p class="text-muted">Set a new password for <strong><?php echo h($row['username']); ?></strong>.</p>
                                  <div class="mb-3">
                                    <label class="form-label">New password</label>
                                    <input type="text" name="N_password" class="form-control" minlength="6" placeholder="At least 6 characters" required>
                                  </div>
                                </div>
                                <div class="modal-footer">
                                  <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                                  <button type="submit" class="btn btn-warning">Reset password</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                        <?php
                        $V_modals .= ob_get_clean();
                    } ?>
                <?php } else { ?>
                    <tr><td colspan="8" class="empty-state">No users found.</td></tr>
                <?php } ?>
                <tr id="noUserMatchRow" style="display:none;">
                    <td colspan="8" class="empty-state">No matching users.</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

<!-- Create user modal -->
<div class="modal fade" id="createUserModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content">
      <form method="POST" action="../app/users/save-user.php">
        <?php echo csrf_field(); ?>
        <div class="modal-header">
          <h5 class="modal-title">Add User</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          <div class="mb-3">
            <label class="form-label">Full name</label>
            <input type="text" name="N_name" class="form-control" required>
          </div>
          <div class="mb-3">
            <label class="form-label">Username</label>
            <input type="text" name="N_username" class="form-control" required>
          </div>
          <div class="mb-3">
            <label class="form-label">Password</label>
            <input type="text" name="N_password" class="form-control" minlength="6" placeholder="At least 6 characters" required>
          </div>
          <?php if ($V_is_superadmin) { ?>
          <div class="mb-3">
            <label class="form-label">Role</label>
            <select name="N_role" class="form-select role-select" data-brgy-target="createBrgyWrap" data-subrole-target="createSubRoleWrap" required>
              <option value="">— Select role —</option>
              <?php echo render_role_options($V_roles, ''); ?>
            </select>
          </div>
          <?php } elseif ($V_is_mdr) { ?>
            <input type="hidden" name="N_role" value="pcf">
          <?php } elseif ($V_is_pho) { ?>
            <input type="hidden" name="N_role" value="pho">
          <?php } else { ?>
            <input type="hidden" name="N_role" value="barangay">
          <?php } ?>
          <div class="mb-3" id="createSubRoleWrap" style="<?php echo $V_is_superadmin ? 'display:none;' : ''; ?>">
            <label class="form-label">Sub-Role</label>
            <select name="N_sub_role" class="form-select sub-role-select">
              <?php
              if ($V_is_mdr) {
                  $V_allowed_create = ($V_sub_role === 'mdr_admin') ? $V_mdr_sub : [$V_sub_role];
              } elseif ($V_is_pho) {
                  $V_allowed_create = ['pdrrmo', 'governor'];
              } else {
                  // Barangay Chairman can create Secretary and BHERT; Secretary only BHERT.
                  $V_allowed_create = ($V_sub_role === 'secretary') ? ['tanod'] : ['secretary', 'tanod'];
              }
              echo render_sub_role_options($V_allowed_create, $V_allowed_create[0] ?? '');
              ?>
            </select>
            <?php if ($V_is_mdr) { ?>
              <small class="text-muted">MDR Admin can create any MDR sub-role. MDR-Kalibo/Ibajay can only create their own sub-role.</small>
            <?php } elseif ($V_is_pho) { ?>
              <small class="text-muted">PHO Admin creates PDRRMO and Governor accounts.</small>
            <?php } else { ?>
              <small class="text-muted">Chairman = full admin. Secretary = manage BHERTs. BHERT = field reporter.</small>
            <?php } ?>
          </div>
          <?php if ($V_is_superadmin) { ?>
          <div class="mb-3" id="createBrgyWrap" style="display:none;">
            <label class="form-label">Barangay</label>
            <select name="N_barangay_id" class="form-select">
              <?php echo render_barangay_options($V_barangays, 0); ?>
            </select>
          </div>
          <?php } elseif ($V_is_mdr) { ?>
            <input type="hidden" name="N_barangay_id" value="0">
          <?php } elseif ($V_is_pho) { ?>
            <input type="hidden" name="N_barangay_id" value="0">
          <?php } else {
            // Barangay admins: auto-set barangay to own
            $V_my_barangay = (int)($_SESSION['barangay_id'] ?? 0);
          ?>
            <input type="hidden" name="N_barangay_id" value="<?php echo $V_my_barangay; ?>">
          <?php } ?>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
          <button type="submit" class="btn btn-danger">Create user</button>
        </div>
      </form>
    </div>
  </div>
</div>

<?php echo $V_modals; ?>

<script>
var V_IS_SUPERADMIN = <?php echo $V_is_superadmin ? 'true' : 'false'; ?>;

// Role options for the superadmin add/edit user sub-role selects.
var SUPERADMIN_SUB_ROLE_OPTIONS = {
    'barangay': [
        ['captain', 'Chairman'],
        ['secretary', 'Secretary'],
        ['tanod', 'BHERT']
    ],
    'pcf': [
        ['mdr_admin', 'MDR Admin'],
        ['mdr_kalibo', 'MDR-Kalibo'],
        ['mdr_ibajay', 'MDR-Ibajay'],
        ['mayor_kalibo', 'Mayor (Kalibo)'],
        ['mayor_ibajay', 'Mayor (Ibajay)']
    ]
};

function rebuildSubRoleOptions(select, role) {
    var opts = SUPERADMIN_SUB_ROLE_OPTIONS[role];
    if (!opts) return;
    var current = select.value;
    var found = false;
    var html = '<option value="">- None -</option>';
    opts.forEach(function(o) {
        if (o[0] === current) found = true;
        html += '<option value="' + o[0] + '">' + o[1] + '</option>';
    });
    select.innerHTML = html;
    select.value = found ? current : '';
}
function runUserFilter() {
    var query    = document.getElementById('userSearch').value.toLowerCase().trim();
    var role     = document.getElementById('userRoleFilter').value.toLowerCase();
    var subRole  = document.getElementById('userSubRoleFilter').value.toLowerCase();
    var rows     = document.querySelectorAll('.user-row');
    var visible  = 0;
    rows.forEach(function(row) {
        var rowSearch   = row.getAttribute('data-search') || '';
        var rowRole     = row.getAttribute('data-role') || '';
        var rowSubRole  = row.getAttribute('data-subrole') || '';
        var matchQuery   = !query    || rowSearch.includes(query);
        var matchRole    = !role     || rowRole === role;
        var matchSubRole = !subRole  || rowSubRole === subRole;
        var show = matchQuery && matchRole && matchSubRole;
        row.style.display = show ? '' : 'none';
        if (show) visible++;
    });
    var noMatch = document.getElementById('noUserMatchRow');
    if (noMatch) noMatch.style.display = (visible === 0) ? '' : 'none';
}
function resetUserFilters() {
    document.getElementById('userSearch').value = '';
    document.getElementById('userRoleFilter').value = '';
    document.getElementById('userSubRoleFilter').value = '';
    runUserFilter();
}
document.getElementById('userSearch').addEventListener('input', runUserFilter);
document.getElementById('userRoleFilter').addEventListener('change', runUserFilter);
document.getElementById('userSubRoleFilter').addEventListener('change', runUserFilter);

// Show the barangay and sub-role dropdowns only when the chosen role requires them.
function syncRoleFields(select) {
    var brgyTargetId  = select.getAttribute('data-brgy-target');
    var subTargetId   = select.getAttribute('data-subrole-target');
    if (brgyTargetId) {
        var brgyWrap = document.getElementById(brgyTargetId);
        if (brgyWrap) brgyWrap.style.display = (select.value === 'barangay') ? '' : 'none';
    }
    if (subTargetId) {
        var subWrap = document.getElementById(subTargetId);
        if (subWrap) subWrap.style.display = (select.value === 'barangay' || select.value === 'pcf') ? '' : 'none';
        if (subWrap && V_IS_SUPERADMIN) {
            var selOpt = subWrap.querySelector('select');
            if (selOpt) rebuildSubRoleOptions(selOpt, select.value);
        }
    }
}
document.querySelectorAll('.role-select').forEach(function(sel) {
    syncRoleFields(sel);
    sel.addEventListener('change', function() { syncRoleFields(sel); });
});

// ---- Barangay Population: digits-only + inline validation ----
var V_POP_MAX = 5000000;

function stripNonDigits(input) {
    // Never allow commas, letters, or symbols while typing.
    input.value = input.value.replace(/\D/g, '');
    clearPopError();
}

function showPopError(msg) {
    var err = document.getElementById('popError');
    if (err) {
        err.textContent = msg;
        err.style.display = 'block';
    }
}

function clearPopError() {
    var err = document.getElementById('popError');
    if (err) {
        err.textContent = '';
        err.style.display = 'none';
    }
}

// For superadmin: show the selected barangay's population comma-formatted.
function updatePopDisplay() {
    var disp = document.getElementById('popDisplay');
    var sel = document.getElementById('popBarangaySelect');
    if (!disp || !sel) return;
    var opt = sel.selectedOptions && sel.selectedOptions[0];
    if (!opt || !opt.value) {
        disp.textContent = '-- (select a barangay) --';
        return;
    }
    var name = opt.getAttribute('data-name') || '';
    var pop = parseInt(opt.getAttribute('data-pop'), 10) || 0;
    disp.textContent = name + ': ' + Number(pop).toLocaleString();
}

function validatePopulationForm() {
    // Superadmin must pick a barangay first.
    var sel = document.getElementById('popBarangaySelect');
    if (sel && !sel.value) {
        showPopError('Select a barangay first.');
        sel.focus();
        return false;
    }

    var input = document.getElementById('popInput');
    var raw = input.value.replace(/\D/g, '');
    input.value = raw;

    if (raw === '') {
        showPopError('Population is required.');
        input.focus();
        return false;
    }

    var num = parseInt(raw, 10);
    if (!/^\d+$/.test(raw)) {
        showPopError('Population must be a whole number, no commas or symbols.');
        input.focus();
        return false;
    }
    if (num > V_POP_MAX) {
        showPopError('Population is too large (max ' + Number(V_POP_MAX).toLocaleString() + ').');
        input.focus();
        return false;
    }

    clearPopError();
    return true;
}
</script>

<?php include "../app/includes/footer.php"; ?>
