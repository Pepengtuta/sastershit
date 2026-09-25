<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");

// Role enforcement: Superadmin and PCF may delete hotlines.
$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active' || !in_array($actorRow['role'], ['superadmin', 'pcf', 'pho'], true)) {
    send_response(false, "You are not authorized to delete hotlines.");
}
// Read-only observers (mayors + Governor) cannot manage hotlines.
if ($actorRow['role'] === 'pcf' && in_array($actorRow['sub_role'] ?? '', ['mayor_kalibo', 'mayor_ibajay'], true)
        || ($actorRow['role'] === 'pho' && ($actorRow['sub_role'] ?? '') === 'governor')) {
    send_response(false, "You are not authorized to delete hotlines.");
}

$id = (int)($input['id'] ?? 0);
if ($id <= 0) send_response(false, "Invalid hotline ID.");

$stmt = mysqli_prepare($connection, "DELETE FROM emergency_hotlines WHERE id = ?");
if (!$stmt) send_response(false, "Failed to prepare delete.");
mysqli_stmt_bind_param($stmt, "i", $id);
if (!mysqli_stmt_execute($stmt)) send_response(false, "Failed to delete hotline.");
if (mysqli_affected_rows($connection) === 0) send_response(false, "Hotline not found.");
send_response(true, "Hotline deleted successfully.");
?>
