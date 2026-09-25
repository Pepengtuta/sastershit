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

$id = (int)($input['user_id'] ?? 0);
$password = (string)($input['password'] ?? '');
if ($id <= 0 || $password === '') send_response(false, "Please enter a new password.");
if (strlen($password) < 6) send_response(false, "Password must be at least 6 characters.");

$tstmt = mysqli_prepare($connection, "SELECT username, role, sub_role, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($tstmt, "i", $id);
mysqli_stmt_execute($tstmt);
$target = mysqli_fetch_assoc(mysqli_stmt_get_result($tstmt));
if (!$target) send_response(false, "User not found.");

// ── Scope check ──
$is_superadmin = ($actor['role'] === 'superadmin');
$is_pcf = ($actor['role'] === 'pcf');
$is_pho = (strtolower($actor['role'] ?? '') === 'pho');
if (!$is_superadmin && !$is_pcf && !$is_pho) {
    if ((int)$target['barangay_id'] !== (int)$actor['barangay_id']) {
        send_response(false, "You can only manage users in your own barangay.");
    }
    // Secretary cannot reset Chairman passwords
    if ($actor['sub_role'] === 'secretary' && $target['sub_role'] === 'captain') {
        send_response(false, "Secretaries cannot reset Chairman passwords.");
    }
}
// PCF scope check
if ($is_pcf) {
    if ($target['role'] !== 'pcf') {
        send_response(false, "You can only manage PCF users.");
    }
    $actor_sub = strtolower($actor['sub_role'] ?? '');
    if ($actor_sub === 'mdr_kalibo' && $target['sub_role'] !== 'mdr_kalibo') {
        send_response(false, "You can only manage MDR-Kalibo users.");
    }
    if ($actor_sub === 'mdr_ibajay' && $target['sub_role'] !== 'mdr_ibajay') {
        send_response(false, "You can only manage MDR-Ibajay users.");
    }
}
// PHO Admin scope check
if ($is_pho) {
    if ($target['role'] !== 'pho' || !in_array($target['sub_role'], ['pdrrmo', 'governor'], true)) {
        send_response(false, "You can only manage PDRRMO and Governor accounts.");
    }
}

$hash = password_hash($password, PASSWORD_DEFAULT);
$uid = (int)$id;

$up = mysqli_prepare($connection, "UPDATE users SET password = ? WHERE id = ?");
mysqli_stmt_bind_param($up, "si", $hash, $uid);
if (!mysqli_stmt_execute($up)) send_response(false, "Could not reset the password. Please try again.");

log_user_action($connection, (int)$actor['id'], $actor['name'], 'reset_password', $id, $target['username'], "Reset password");
send_response(true, "Password reset successfully.");
?>
