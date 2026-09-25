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
if (!$actor) send_response(false, "You are not authorized to view activity.");
if ($actor['role'] !== 'superadmin' && $actor['role'] !== 'pho') {
    send_response(false, "You are not authorized to view activity.");
}

// Superadmin sees all activity; PHO Admin sees only Provincial (PHO) activity.
$where = '';
if ($actor['role'] === 'pho') {
    $where = "WHERE actor_id IN (SELECT id FROM users WHERE role = 'pho')";
}

$q = "SELECT id, actor_name, action, target_username, details, created_at FROM user_activity_logs $where ORDER BY created_at DESC LIMIT 300";
$res = mysqli_query($connection, $q);
if (!$res) send_response(false, "Could not load activity. Please try again.");
$data = [];
while ($row = mysqli_fetch_assoc($res)) $data[] = $row;
send_response(true, "Activity loaded successfully.", $data);
?>
