<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
function table_exists($connection, $table) { $t=mysqli_real_escape_string($connection,$table); $r=mysqli_query($connection,"SHOW TABLES LIKE '$t'"); return $r && mysqli_num_rows($r)>0; }
function column_exists($connection, $table, $column) { $t=mysqli_real_escape_string($connection,$table); $c=mysqli_real_escape_string($connection,$column); $r=mysqli_query($connection,"SHOW COLUMNS FROM `$t` LIKE '$c'"); return $r && mysqli_num_rows($r)>0; }
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");
$user_id = (int)($input['user_id'] ?? 0);
$barangay_id = (int)($input['barangay_id'] ?? 0);
$alert_ids = $input['alert_ids'] ?? [];
if ($user_id <= 0 || $barangay_id <= 0) send_response(false, "User ID and barangay ID are required.");
if (!table_exists($connection, 'alert_reads')) send_response(false, "alert_reads table not found. Run config/migration.sql.");
if (!is_array($alert_ids) || count($alert_ids) === 0) send_response(true, "No alerts to mark as read.");
$stmt = mysqli_prepare($connection, "INSERT IGNORE INTO alert_reads (alert_id, user_id, barangay_id, read_at) VALUES (?, ?, ?, NOW())");
if (!$stmt) send_response(false, fail_message("Failed to prepare read update.", mysqli_error($connection)));
$count = 0;
foreach ($alert_ids as $alert_id) {
    $alert_id = (int)$alert_id;
    if ($alert_id > 0) {
        mysqli_stmt_bind_param($stmt, "iii", $alert_id, $user_id, $barangay_id);
        if (mysqli_stmt_execute($stmt)) $count++;
    }
}
send_response(true, "Alerts marked as read.", ["count" => $count]);
?>
