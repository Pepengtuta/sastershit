<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
require_once "user_audit.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }

$input = json_decode(file_get_contents("php://input"), true) ?: [];
$actor = verify_actor($connection, $input['acting_user_id'] ?? 0);
if (!$actor) send_response(false, "You are not authorized to manage users.");

// Mayor observers cannot manage users.
if (is_readonly_role_api($actor['role'], $actor['sub_role'] ?? '')) {
    send_response(false, "You are not authorized to manage users.");
}

$actor_id = (int)$actor['id'];

$id = (int)($input['user_id'] ?? 0);
$name = trim($input['name'] ?? '');
$username = trim($input['username'] ?? '');
$sub_role = trim($input['sub_role'] ?? '');

if ($id <= 0 || $name === '' || $username === '') {
    send_response(false, "Please fill in all required fields.");
}

// ── Fetch target user ──
$tstmt = mysqli_prepare($connection, "SELECT id, username, role, sub_role, barangay_id, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($tstmt, "i", $id);
mysqli_stmt_execute($tstmt);
$target = mysqli_fetch_assoc(mysqli_stmt_get_result($tstmt));
if (!$target) send_response(false, "User not found.");

// ── Scope check for admins ──
$is_superadmin = ($actor['role'] === 'superadmin');
$is_pcf = ($actor['role'] === 'pcf');
$is_pho = (strtolower($actor['role'] ?? '') === 'pho');
if (!$is_superadmin && !$is_pcf && !$is_pho) {
    if ((int)$target['barangay_id'] !== (int)$actor['barangay_id']) {
        send_response(false, "You can only edit users in your own barangay.");
    }
    // Secretary cannot edit Chairman accounts
    if ($actor['sub_role'] === 'secretary' && $target['sub_role'] === 'captain') {
        send_response(false, "Secretaries cannot edit Chairman accounts.");
    }
    // Cannot change your own sub_role
    if ($id === $actor_id && $sub_role !== '' && $sub_role !== $target['sub_role']) {
        send_response(false, "You cannot change your own sub-role.");
    }
}
// PCF scope check
if ($is_pcf) {
    if ($target['role'] !== 'pcf') {
        send_response(false, "You can only edit PCF users.");
    }
    $actor_sub = strtolower($actor['sub_role'] ?? '');
    if ($actor_sub === 'mdr_kalibo' && $target['sub_role'] !== 'mdr_kalibo') {
        send_response(false, "You can only edit MDR-Kalibo users.");
    }
    if ($actor_sub === 'mdr_ibajay' && $target['sub_role'] !== 'mdr_ibajay') {
        send_response(false, "You can only edit MDR-Ibajay users.");
    }
    // Cannot change your own sub_role
    if ($id === $actor_id && $sub_role !== '' && $sub_role !== $target['sub_role']) {
        send_response(false, "You cannot change your own sub-role.");
    }
}
// PHO Admin scope check
if ($is_pho) {
    if ($target['role'] !== 'pho' || !in_array($target['sub_role'], ['pdrrmo', 'governor'], true)) {
        send_response(false, "You can only edit PDRRMO and Governor accounts.");
    }
    if ($id === $actor_id) {
        send_response(false, "You cannot edit your own account.");
    }
}

// ── Superadmin-specific checks ──
if ($is_superadmin) {
    $role = trim($input['role'] ?? $target['role']);
    $allowed_roles = ['superadmin', 'pcf', 'pho', 'barangay'];
    if (!in_array($role, $allowed_roles, true)) send_response(false, "Invalid role.");
    if ($id === $actor_id && $role !== $target['role']) send_response(false, "You cannot change your own role.");
    if ($target['role'] === 'superadmin' && $role !== 'superadmin' && $target['status'] === 'Active') {
        if (count_active_superadmins($connection, $id) === 0) send_response(false, "You cannot remove the last active Super Admin.");
    }
    if ($role === 'barangay') {
        $barangay_id = ($input['barangay_id'] ?? null) !== null ? (int)$input['barangay_id'] : 0;
        if ($barangay_id <= 0) send_response(false, "Please choose a barangay.");
    } elseif ($role === 'pcf') {
        $barangay_id = null;
        $allowed_pcf_sub = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
        $tmp_sub = $sub_role !== '' ? $sub_role : $target['sub_role'];
        if (!in_array($tmp_sub, $allowed_pcf_sub, true)) {
            send_response(false, "Invalid PCF sub-role.");
        }
    } else {
        $barangay_id = null;
    }
    // PHO accounts always have an empty sub-role (default PHO Admin).
    if ($role === 'pho') {
        $sub_role_val = '';
    } else {
        $sub_role_val = $sub_role !== '' ? $sub_role : $target['sub_role'];
    }
} elseif ($is_pcf) {
    $role = 'pcf';
    $barangay_id = null;
    $sub_role_val = $sub_role !== '' ? $sub_role : $target['sub_role'];
    $allowed_pcf_sub = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
    if ($sub_role_val !== '' && !in_array($sub_role_val, $allowed_pcf_sub, true)) {
        send_response(false, "Invalid PCF sub-role.");
    }
    // Only mdr_admin may create/edit mayor accounts.
    $actor_sub = strtolower($actor['sub_role'] ?? '');
    if ($actor_sub !== 'mdr_admin' && $target['role'] === 'pcf' && in_array($target['sub_role'], ['mayor_kalibo', 'mayor_ibajay'], true)) {
        send_response(false, "Only the MDR Admin can manage Mayor accounts.");
    }
    // mdr_kalibo/mdr_ibajay cannot change sub_role to something else
    if ($actor_sub !== 'mdr_admin' && $sub_role_val !== '' && $sub_role_val !== $target['sub_role']) {
        send_response(false, "You cannot change this user's sub-role.");
    }
} elseif ($is_pho) {
    $role = 'pho';
    $barangay_id = null;
    $sub_role_val = $sub_role !== '' ? $sub_role : $target['sub_role'];
    if (!in_array($sub_role_val, ['pdrrmo', 'governor'], true)) {
        send_response(false, "PHO Admin can only manage PDRRMO and Governor accounts.");
    }
} else {
    $role = 'barangay';
    $barangay_id = (int)$target['barangay_id'];
    $sub_role_val = $sub_role !== '' ? $sub_role : $target['sub_role'];
    $allowed_sub = ['captain', 'secretary', 'tanod'];
    if ($sub_role_val !== '' && !in_array($sub_role_val, $allowed_sub, true)) {
        send_response(false, "Invalid sub-role.");
    }
    // One Chairman per barangay: promoting to captain is only allowed when
    // the target is the existing chairman or the barangay has no chairman yet.
    if ($sub_role_val === 'captain' && $sub_role_val !== $target['sub_role']) {
        $cchk = mysqli_prepare($connection, "SELECT id FROM users WHERE role = 'barangay' AND sub_role = 'captain' AND barangay_id = ? LIMIT 1");
        mysqli_stmt_bind_param($cchk, "i", $barangay_id);
        mysqli_stmt_execute($cchk);
        if (mysqli_fetch_assoc(mysqli_stmt_get_result($cchk))) {
            send_response(false, "This barangay already has a Chairman. Each barangay can only have one Chairman.");
        }
    }
}

// ── Check duplicate username ──
$uchk = mysqli_prepare($connection, "SELECT id FROM users WHERE username = ? AND id <> ? LIMIT 1");
mysqli_stmt_bind_param($uchk, "si", $username, $id);
mysqli_stmt_execute($uchk);
if (mysqli_fetch_assoc(mysqli_stmt_get_result($uchk))) send_response(false, "That username is already taken.");

// ── Compute can_manage_users from role + sub_role ──
// Default (empty) sub-roles — like PHO Admin — manage users. PDRRMO / MDR-Kalibo / MDR-Ibajay do not.
$can_manage_val = in_array($sub_role_val, ['captain', 'secretary', 'mdr_admin'], true) || $sub_role_val === '' ? 1 : 0;
$cm = (string)$can_manage_val;

// ── Update ──
$name_s = (string)$name;
$username_s = (string)$username;
$role_s = (string)$role;
$sub_s = (string)$sub_role_val;
$bid = $barangay_id;
$uid = (int)$id;

$up = mysqli_prepare($connection,
    "UPDATE users SET name = ?, username = ?, role = ?, sub_role = ?, can_manage_users = ?, barangay_id = ? WHERE id = ?");
mysqli_stmt_bind_param($up, "sssssii", $name_s, $username_s, $role_s, $sub_s, $cm, $bid, $uid);
if (!mysqli_stmt_execute($up)) send_response(false, "Could not update the user. Please try again.");

log_user_action($connection, $actor_id, $actor['name'], 'update', $id, $username, "Updated user details");
send_response(true, "User updated successfully.");
?>
