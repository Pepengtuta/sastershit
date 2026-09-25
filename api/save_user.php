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

// ── 1. Verify the actor (superadmin OR barangay admin) ──
$actor_id = (int)($input['acting_user_id'] ?? 0);
$actor = verify_actor($connection, $actor_id);
if (!$actor) send_response(false, "You are not authorized to manage users.");

// Mayor observers cannot manage users.
if (is_readonly_role_api($actor['role'], $actor['sub_role'] ?? '')) {
    send_response(false, "You are not authorized to manage users.");
}

// ── 2. Read input ──
$name     = trim($input['name'] ?? '');
$username = trim($input['username'] ?? '');
$password = (string)($input['password'] ?? '');
$sub_role = trim($input['sub_role'] ?? '');

if ($name === '' || $username === '' || $password === '') {
    send_response(false, "Name, username, and password are required.");
}
if (strlen($password) < 6) {
    send_response(false, "Password must be at least 6 characters.");
}

// ── 3. Pre-initialize bind variables (required for bind_param by-reference) ──
$role         = 'barangay';
$barangay_id  = 0;
$sub_role_val = null;
$can_manage   = 0;

// ── 4. Determine role + barangay_id + sub_role based on actor type ──
$is_superadmin = ($actor['role'] === 'superadmin');

if ($is_superadmin) {
    $role = trim($input['role'] ?? '');
    $allowed_roles = ['superadmin', 'pcf', 'pho', 'barangay'];
    if (!in_array($role, $allowed_roles, true)) {
        send_response(false, "Invalid role.");
    }

    if ($role === 'barangay') {
        $barangay_id  = ($input['barangay_id'] ?? null) !== null ? (int)$input['barangay_id'] : 0;
        if ($barangay_id <= 0) send_response(false, "Please choose a barangay.");
        $sub_role_val = $sub_role !== '' ? $sub_role : 'captain';
        $can_manage   = ($sub_role_val === 'captain' || $sub_role_val === 'secretary') ? 1 : 0;
    } elseif ($role === 'pcf') {
        $barangay_id = null;
        $allowed_pcf = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
        if ($sub_role === '' || !in_array($sub_role, $allowed_pcf, true)) {
            send_response(false, "Please choose a valid PCF sub-role.");
        }
        $sub_role_val = $sub_role;
        $can_manage   = ($sub_role === 'mdr_admin') ? 1 : 0;
    } elseif ($role === 'pho') {
        // Superadmin-created PHO accounts are default PHO Admins.
        $barangay_id = null;
        $sub_role_val = '';
        $can_manage   = 1;
    }
} elseif ($actor['role'] === 'pcf') {
    // PCF MDR: always creates pcf users, scoped by sub_role.
    // mayor_* accounts may only be created by mdr_admin (or superadmin).
    $role = 'pcf';
    $barangay_id = null;
    $actor_sub = strtolower($actor['sub_role'] ?? '');

    $allowed_pcf_sub = ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
    if (!in_array($sub_role, $allowed_pcf_sub, true)) {
        send_response(false, "Please choose a valid PCF sub-role.");
    }
    if ($actor_sub !== 'mdr_admin' && in_array($sub_role, ['mayor_kalibo', 'mayor_ibajay'], true)) {
        send_response(false, "Only the MDR Admin can create Mayor accounts.");
    }

    // Scope: mdr_kalibo can only create mdr_kalibo, etc.
    if ($actor_sub === 'mdr_kalibo' && $sub_role !== 'mdr_kalibo') {
        send_response(false, "MDR-Kalibo can only create MDR-Kalibo accounts.");
    }
    if ($actor_sub === 'mdr_ibajay' && $sub_role !== 'mdr_ibajay') {
        send_response(false, "MDR-Ibajay can only create MDR-Ibajay accounts.");
    }
    // mdr_admin can create any pcf sub_role — no restriction needed

    $sub_role_val = $sub_role;
    $can_manage   = ($sub_role === 'mdr_admin') ? 1 : 0;
} elseif (strtolower($actor['role']) === 'pho') {
    // PHO Admin: creates PDRRMO and Governor accounts (role pho).
    $role = 'pho';
    $barangay_id = null;
    if (!in_array($sub_role, ['pdrrmo', 'governor'], true)) {
        send_response(false, "PHO Admin can only create PDRRMO and Governor accounts.");
    }
    $sub_role_val = $sub_role;
    $can_manage   = 0;
} else {
    // Barangay admin: always creates role='barangay', scoped to own barangay
    $role = 'barangay';
    $barangay_id = (int)$actor['barangay_id'];

    // Scope enforcement
    $input_barangay = ($input['barangay_id'] ?? null) !== null ? (int)$input['barangay_id'] : 0;
    if ($input_barangay > 0 && $input_barangay !== $barangay_id) {
        send_response(false, "You can only manage users in your own barangay.");
    }

    // Validate sub_role
    $allowed_sub = ['captain', 'secretary', 'tanod'];
    if (!in_array($sub_role, $allowed_sub, true)) {
        send_response(false, "Please choose a valid sub-role: Chairman, Secretary, or BHERT.");
    }

    // Chairman can create any sub-role; Secretary can only create Tanod
    if ($actor['sub_role'] === 'secretary' && $sub_role !== 'tanod') {
        send_response(false, "Secretaries can only create BHERT accounts.");
    }

    // One Chairman per barangay.
    if ($sub_role === 'captain') {
        $cchk = mysqli_prepare($connection, "SELECT id FROM users WHERE role = 'barangay' AND sub_role = 'captain' AND barangay_id = ? LIMIT 1");
        mysqli_stmt_bind_param($cchk, "i", $barangay_id);
        mysqli_stmt_execute($cchk);
        if (mysqli_fetch_assoc(mysqli_stmt_get_result($cchk))) {
            send_response(false, "This barangay already has a Chairman. Each barangay can only have one Chairman.");
        }
    }

    $sub_role_val = $sub_role;
    $can_manage   = ($sub_role_val === 'captain' || $sub_role_val === 'secretary') ? 1 : 0;
}

// ── 5. Check for duplicate username ──
$chk = mysqli_prepare($connection, "SELECT id FROM users WHERE username = ? LIMIT 1");
mysqli_stmt_bind_param($chk, "s", $username);
mysqli_stmt_execute($chk);
if (mysqli_fetch_assoc(mysqli_stmt_get_result($chk))) {
    send_response(false, "That username is already taken.");
}

// ── 6. Insert ──
$hash = password_hash($password, PASSWORD_DEFAULT);

// Copy into fresh locals — bind_param passes by reference and
// variables set inside if/else blocks can lose their binding.
// NOTE: ENUM columns (role, sub_role, can_manage_users) use 's';
//       barangay_id is nullable int (NULL for non-barangay roles, so the FK holds).
$sr = (string)$sub_role_val;
$cm = (string)$can_manage;
$bi = $barangay_id;

$ins = mysqli_prepare($connection,
    "INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'Active', NOW())");
mysqli_stmt_bind_param($ins, "ssssssi", $name, $username, $hash, $role, $sr, $cm, $bi);
if (!mysqli_stmt_execute($ins)) {
    send_response(false, "Could not create the user. Please try again.");
}
$new_id = (int)mysqli_insert_id($connection);

log_user_action($connection, (int)$actor['id'], $actor['name'], 'create', $new_id, $username,
    "Created $role/$sub_role_val account");

send_response(true, "User created successfully.", ["id" => $new_id]);
?>
