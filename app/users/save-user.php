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

$V_name = trim($_POST['N_name'] ?? '');
$V_username = trim($_POST['N_username'] ?? '');
$V_password = (string)($_POST['N_password'] ?? '');
$V_role_input = trim($_POST['N_role'] ?? '');
$V_barangay_id = $_POST['N_barangay_id'] ?? '';
$V_sub_role_input = trim($_POST['N_sub_role'] ?? '');
$V_allowed_sub = ['captain', 'secretary', 'tanod'];
$V_mdr_sub = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
$V_is_mdr = ($V_role === 'pcf' && in_array($V_sub_role, ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay']));
$V_is_pho = ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null));

if ($V_name === '' || $V_username === '' || $V_password === '') {
    redirect_users('err', 'Please fill in all required fields.');
}
if (strlen($V_password) < 6) {
    redirect_users('err', 'Password must be at least 6 characters.');
}

if ($V_is_superadmin) {
    // Superadmin can create any role.
    $V_allowed = ['superadmin', 'pcf', 'pho', 'barangay'];
    if (!in_array($V_role_input, $V_allowed, true)) {
        redirect_users('err', 'Please fill in all required fields.');
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
    // PCF MDR: creates pcf users only, no barangay.
    $V_final_role = 'pcf';
    $V_barangay_id = null;

    if ($V_actor_sub_role === 'mdr_kalibo') {
        if ($V_sub_role_input !== 'mdr_kalibo') {
            redirect_users('err', 'MDR-Kalibo accounts can only create MDR-Kalibo accounts.');
        }
    } elseif ($V_actor_sub_role === 'mdr_ibajay') {
        if ($V_sub_role_input !== 'mdr_ibajay') {
            redirect_users('err', 'MDR-Ibajay accounts can only create MDR-Ibajay accounts.');
        }
    } elseif ($V_actor_sub_role === 'mdr_admin') {
        if (!in_array($V_sub_role_input, $V_mdr_sub, true)) {
            redirect_users('err', 'Please choose a valid MDR sub-role.');
        }
    }
} elseif ($V_is_pho) {
    // PHO Admin: creates PDRRMO and Governor accounts (role pho).
    $V_final_role = 'pho';
    $V_barangay_id = null;

    if (!in_array($V_sub_role_input, ['pdrrmo', 'governor'], true)) {
        redirect_users('err', 'PHO Admin can only create PDRRMO and Governor accounts.');
    }
} else {
    // Barangay Chairman/Secretary: always creates barangay users in own barangay.
    $V_final_role = 'barangay';
    $V_barangay_id = $V_actor_barangay;

    if (!in_array($V_sub_role_input, $V_allowed_sub, true)) {
        redirect_users('err', 'Please choose a valid sub-role.');
    }
    // Secretary can only create Tanod.
    if ($V_actor_sub_role === 'secretary' && $V_sub_role_input !== 'tanod') {
        redirect_users('err', 'Secretaries can only create BHERT accounts.');
    }
}

$chk = mysqli_prepare($connection, "SELECT id FROM users WHERE username = ? LIMIT 1");
mysqli_stmt_bind_param($chk, "s", $V_username);
mysqli_stmt_execute($chk);
if (mysqli_fetch_assoc(mysqli_stmt_get_result($chk))) {
    redirect_users('err', 'That username is already taken.');
}

            // One Chairman per barangay.
if ($V_final_role === 'barangay' && $V_sub_role_input === 'captain') {
    $cchk = mysqli_prepare($connection, "SELECT id FROM users WHERE role = 'barangay' AND sub_role = 'captain' AND barangay_id = ? LIMIT 1");
    mysqli_stmt_bind_param($cchk, "i", $V_barangay_id);
    mysqli_stmt_execute($cchk);
    if (mysqli_fetch_assoc(mysqli_stmt_get_result($cchk))) {
            redirect_users('err', 'This barangay already has a Chairman. Each barangay can only have one Chairman.');
    }
}

$V_manage_flag = sub_role_manage_flag($V_sub_role_input);
$V_hash = password_hash($V_password, PASSWORD_DEFAULT);
$ins = mysqli_prepare($connection, "INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'Active', NOW())");
mysqli_stmt_bind_param($ins, "sssssii", $V_name, $V_username, $V_hash, $V_final_role, $V_sub_role_input, $V_manage_flag, $V_barangay_id);
if (!mysqli_stmt_execute($ins)) {
    redirect_users('err', 'Could not create the user. Please try again.');
}
$V_new_id = (int)mysqli_insert_id($connection);
$sub_info = ($V_final_role === 'barangay') ? " ($V_sub_role_input)" : '';
log_user_action($connection, $V_actor_id, $V_actor_name, 'create', $V_new_id, $V_username, "Created $V_final_role$sub_info account");
redirect_users('ok', 'User created successfully.');
?>
