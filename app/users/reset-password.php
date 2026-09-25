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
$V_is_mdr = ($V_role === 'pcf' && in_array($V_sub_role, ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay']));
$V_is_pho = ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null));

$V_id = (int)($_GET['id'] ?? 0);
$V_password = (string)($_POST['N_password'] ?? '');
if ($V_id <= 0 || $V_password === '') {
    redirect_users('err', 'Please enter a new password.');
}
if (strlen($V_password) < 6) {
    redirect_users('err', 'Password must be at least 6 characters.');
}

$tstmt = mysqli_prepare($connection, "SELECT username, role, sub_role, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($tstmt, "i", $V_id);
mysqli_stmt_execute($tstmt);
$V_target = mysqli_fetch_assoc(mysqli_stmt_get_result($tstmt));
if (!$V_target) {
    redirect_users('err', 'User not found.');
}

// Scope check for non-superadmin.
if (!$V_is_superadmin) {
    if ($V_is_mdr) {
        // MDR actors can only reset pcf users.
        if ($V_target['role'] !== 'pcf') {
            redirect_users('err', 'You can only manage PCF accounts.');
        }
        // mdr_kalibo can only manage mdr_kalibo; mdr_ibajay can only manage mdr_ibajay.
        if ($V_actor_sub_role === 'mdr_kalibo' && $V_target['sub_role'] !== 'mdr_kalibo') {
            redirect_users('err', 'MDR-Kalibo accounts can only manage MDR-Kalibo accounts.');
        }
        if ($V_actor_sub_role === 'mdr_ibajay' && $V_target['sub_role'] !== 'mdr_ibajay') {
            redirect_users('err', 'MDR-Ibajay accounts can only manage MDR-Ibajay accounts.');
        }
    } elseif ($V_is_pho) {
        // PHO Admin scope check: only PDRRMO/Governor accounts.
        if ($V_target['role'] !== 'pho' || !in_array($V_target['sub_role'], ['pdrrmo', 'governor'], true)) {
            redirect_users('err', 'PHO Admin can only manage PDRRMO and Governor accounts.');
        }
    } else {
        // Barangay admin scope check.
        if ((int)$V_target['barangay_id'] !== $V_actor_barangay) {
            redirect_users('err', 'You can only manage users in your own barangay.');
        }
        if ($V_target['sub_role'] === 'captain') {
            redirect_users('err', 'You cannot reset Chairman passwords.');
        }
    }
}

$V_hash = password_hash($V_password, PASSWORD_DEFAULT);
$uid = (int)$V_id;

$up = mysqli_prepare($connection, "UPDATE users SET password = ? WHERE id = ?");
mysqli_stmt_bind_param($up, "si", $V_hash, $uid);
if (!mysqli_stmt_execute($up)) {
    redirect_users('err', 'Could not reset the password. Please try again.');
}
log_user_action($connection, $V_actor_id, $V_actor_name, 'reset_password', $V_id, $V_target['username'], 'Reset password');
redirect_users('ok', 'Password reset successfully.');
?>
