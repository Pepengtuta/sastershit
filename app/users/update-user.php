<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
require_once __DIR__ . "/../../config/db_connection.php";
require_once __DIR__ . "/../includes/functions.php";

function redirect_users($V_param, $V_msg) {
    header("Location: ../../public/manage-users.php?" . $V_param . "=" . urlencode($V_msg));
    exit;
}

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_can_manage = (int)($_SESSION['can_manage_users'] ?? 0);
$V_is_superadmin = ($V_role === 'superadmin');

if (!$V_is_superadmin && !$V_can_manage) {
    redirect_users('err', 'You are not authorized to manage users.');
}

$V_actor_id = (int)($_SESSION['user_id'] ?? 0);
$V_actor_name = $_SESSION['name'] ?? '';
$V_actor_sub_role = $V_sub_role;
$V_actor_barangay = (int)($_SESSION['barangay_id'] ?? 0);

$V_id = (int)($_GET['id'] ?? 0);
$V_name = trim($_POST['N_name'] ?? '');
$V_username = trim($_POST['N_username'] ?? '');
$V_role_input = trim($_POST['N_role'] ?? '');
$V_barangay_id = $_POST['N_barangay_id'] ?? '';
$V_sub_role_input = trim($_POST['N_sub_role'] ?? '');
$V_allowed_sub = ['captain', 'secretary', 'tanod'];
$V_mdr_sub = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
$V_is_mdr = ($V_role === 'pcf' && in_array($V_sub_role, ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay']));
$V_is_pho = ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null));

if ($V_id <= 0 || $V_name === '' || $V_username === '') {
    redirect_users('err', 'Please fill in all required fields.');
}

$tstmt = mysqli_prepare($connection, "SELECT id, username, role, sub_role, barangay_id, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($tstmt, "i", $V_id);
mysqli_stmt_execute($tstmt);
$V_target = mysqli_fetch_assoc(mysqli_stmt_get_result($tstmt));
if (!$V_target) {
    redirect_users('err', 'User not found.');
}

// Scope check for non-superadmin.
if (!$V_is_superadmin) {
    if ($V_is_mdr) {
        // MDR actors can only edit pcf users.
        if ($V_target['role'] !== 'pcf') {
            redirect_users('err', 'You can only edit PCF accounts.');
        }
        // mdr_kalibo can only manage mdr_kalibo; mdr_ibajay can only manage mdr_ibajay.
        if ($V_actor_sub_role === 'mdr_kalibo' && $V_target['sub_role'] !== 'mdr_kalibo') {
            redirect_users('err', 'MDR-Kalibo accounts can only manage MDR-Kalibo accounts.');
        }
        if ($V_actor_sub_role === 'mdr_ibajay' && $V_target['sub_role'] !== 'mdr_ibajay') {
            redirect_users('err', 'MDR-Ibajay accounts can only manage MDR-Ibajay accounts.');
        }
    } elseif ($V_is_pho) {
        // PHO Admin scope check: only PDRRMO/Governor accounts (role pho).
        if ($V_target['role'] !== 'pho' || !in_array($V_target['sub_role'], ['pdrrmo', 'governor'], true)) {
            redirect_users('err', 'PHO Admin can only manage PDRRMO and Governor accounts.');
        }
    } else {
        // Barangay admin scope check.
        if ((int)$V_target['barangay_id'] !== $V_actor_barangay) {
            redirect_users('err', 'You can only edit users in your own barangay.');
        }
        // Cannot manage other Chairmen.
        if ($V_target['sub_role'] === 'captain') {
            redirect_users('err', 'You cannot edit Chairman accounts.');
        }
    }
    // Cannot change your own sub-role.
    if ($V_id === $V_actor_id) {
        redirect_users('err', 'You cannot change your own role.');
    }
}

if ($V_is_superadmin) {
    $V_allowed = ['superadmin', 'pcf', 'pho', 'barangay'];
    if (!in_array($V_role_input, $V_allowed, true)) {
        redirect_users('err', 'Please fill in all required fields.');
    }
    // Cannot change your own role.
    if ($V_id === $V_actor_id && $V_role_input !== $V_target['role']) {
        redirect_users('err', 'You cannot change your own role.');
    }
    // Cannot demote last active Super Admin.
    if ($V_target['role'] === 'superadmin' && $V_role_input !== 'superadmin' && $V_target['status'] === 'Active') {
        if (count_active_superadmins($connection, $V_id) === 0) {
            redirect_users('err', 'You cannot remove the last active Super Admin.');
        }
    }
    $V_final_role = $V_role_input;
    if ($V_final_role === 'barangay') {
        $V_barangay_id = (int)$V_barangay_id;
        if ($V_barangay_id <= 0) {
            redirect_users('err', 'Please choose a barangay.');
        }
        if (!in_array($V_sub_role_input, $V_allowed_sub, true)) {
            $V_sub_role_input = 'captain';
        }
    } elseif ($V_final_role === 'pcf') {
        $V_barangay_id = null;
        if ($V_sub_role_input !== '' && !in_array($V_sub_role_input, $V_mdr_sub, true)) {
            redirect_users('err', 'Invalid sub-role for PCF.');
        }
    } else {
        $V_barangay_id = null;
        $V_sub_role_input = '';
    }
} elseif ($V_is_mdr) {
    // MDR actor: role is always pcf, sub_role is validated against allowed.
    $V_final_role = 'pcf';
    $V_barangay_id = null;
    // Actor can only change sub_role within their scope.
    if ($V_actor_sub_role === 'mdr_kalibo') {
        if ($V_sub_role_input !== 'mdr_kalibo') {
            redirect_users('err', 'MDR-Kalibo accounts can only manage MDR-Kalibo accounts.');
        }
    } elseif ($V_actor_sub_role === 'mdr_ibajay') {
        if ($V_sub_role_input !== 'mdr_ibajay') {
            redirect_users('err', 'MDR-Ibajay accounts can only manage MDR-Ibajay accounts.');
        }
    } elseif ($V_actor_sub_role === 'mdr_admin') {
        if (!in_array($V_sub_role_input, $V_mdr_sub, true)) {
            redirect_users('err', 'Please choose a valid MDR sub-role.');
        }
    }
} elseif ($V_is_pho) {
    // PHO Admin: role is always pho, sub-role locked to PDRRMO/Governor.
    $V_final_role = 'pho';
    $V_barangay_id = null;
    if (!in_array($V_sub_role_input, ['pdrrmo', 'governor'], true)) {
        redirect_users('err', 'PHO Admin can only manage PDRRMO and Governor accounts.');
    }
} else {
    // Barangay admin: role is always barangay, scoped to own barangay.
    $V_final_role = 'barangay';
    $V_barangay_id = $V_actor_barangay;
    if (!in_array($V_sub_role_input, $V_allowed_sub, true)) {
        redirect_users('err', 'Please choose a valid sub-role.');
    }
    // Secretary can only manage Tanod.
    if ($V_actor_sub_role === 'secretary' && $V_sub_role_input !== 'tanod') {
        redirect_users('err', 'Secretaries can only manage BHERT accounts.');
    }
        // One Chairman per barangay.
    if ($V_sub_role_input === 'captain' && $V_target['sub_role'] !== 'captain') {
        $cchk = mysqli_prepare($connection, "SELECT id FROM users WHERE role = 'barangay' AND sub_role = 'captain' AND barangay_id = ? AND id <> ? LIMIT 1");
        mysqli_stmt_bind_param($cchk, "ii", $V_barangay_id, $V_id);
        mysqli_stmt_execute($cchk);
        if (mysqli_fetch_assoc(mysqli_stmt_get_result($cchk))) {
            redirect_users('err', 'This barangay already has a Chairman.');
        }
    }
}

$uchk = mysqli_prepare($connection, "SELECT id FROM users WHERE username = ? AND id <> ? LIMIT 1");
mysqli_stmt_bind_param($uchk, "si", $V_username, $V_id);
mysqli_stmt_execute($uchk);
if (mysqli_fetch_assoc(mysqli_stmt_get_result($uchk))) {
    redirect_users('err', 'That username is already taken.');
}

$V_manage_flag = sub_role_manage_flag($V_sub_role_input);
$up = mysqli_prepare($connection, "UPDATE users SET name = ?, username = ?, role = ?, sub_role = ?, can_manage_users = ?, barangay_id = ? WHERE id = ?");
mysqli_stmt_bind_param($up, "ssssiii", $V_name, $V_username, $V_final_role, $V_sub_role_input, $V_manage_flag, $V_barangay_id, $V_id);
if (!mysqli_stmt_execute($up)) {
    redirect_users('err', 'Could not update the user. Please try again.');
}
$sub_info = ($V_final_role === 'barangay') ? " ($V_sub_role_input)" : '';
log_user_action($connection, $V_actor_id, $V_actor_name, 'update', $V_id, $V_username, "Updated details / role = $V_final_role$sub_info");
redirect_users('ok', 'User updated successfully.');
?>
