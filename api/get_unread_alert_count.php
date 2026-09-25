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
$input = json_decode(file_get_contents("php://input"), true) ?: [];
$user_id = (int)($input['user_id'] ?? 0);
$barangay_id = (int)($input['barangay_id'] ?? 0);
if ($user_id <= 0 || $barangay_id <= 0) send_response(false, "User ID and barangay ID are required.");
$has_target_type = column_exists($connection, 'alerts', 'target_type');
$has_status = column_exists($connection, 'alerts', 'status');
$has_end = column_exists($connection, 'alerts', 'end_datetime');
$has_alert_barangays = table_exists($connection, 'alert_barangays');
$has_alert_reads = table_exists($connection, 'alert_reads');
if (!$has_alert_reads) send_response(true, "Unread count loaded.", ["count" => 0]);
$where = [];
if ($has_status) $where[] = "alerts.status = 'Active'";
if ($has_end) $where[] = "(alerts.end_datetime IS NULL OR alerts.end_datetime >= NOW())";
if ($has_target_type && $has_alert_barangays) {
    $where[] = "(LOWER(COALESCE(alerts.target_type, 'all')) = 'all' OR EXISTS (SELECT 1 FROM alert_barangays ab WHERE ab.alert_id = alerts.id AND ab.barangay_id = $barangay_id))";
}
$where[] = "NOT EXISTS (SELECT 1 FROM alert_reads ar WHERE ar.alert_id = alerts.id AND ar.user_id = $user_id)";
$where_sql = count($where) > 0 ? "WHERE " . implode(" AND ", $where) : "";
$query = "SELECT COUNT(DISTINCT alerts.id) AS unread_count FROM alerts $where_sql";
$result = mysqli_query($connection, $query);
if (!$result) send_response(false, fail_message("Failed to count unread alerts.", mysqli_error($connection)));
$row = mysqli_fetch_assoc($result);
send_response(true, "Unread count loaded.", ["count" => (int)($row['unread_count'] ?? 0)]);
?>
