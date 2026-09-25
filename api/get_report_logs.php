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
$report_id = (int)($input['report_id'] ?? 0);
if ($report_id <= 0) send_response(false, "Report ID is required.");
if (!table_exists($connection, 'incident_status_logs')) send_response(true, "No status timeline table found.", []);
$report_col = column_exists($connection, 'incident_status_logs', 'incident_report_id') ? 'incident_report_id' : 'incident_id';
$old_col = column_exists($connection, 'incident_status_logs', 'old_status') ? 'old_status' : 'status_from';
$new_col = column_exists($connection, 'incident_status_logs', 'new_status') ? 'new_status' : 'status_to';
$user_col = column_exists($connection, 'incident_status_logs', 'updated_by') ? 'updated_by' : 'action_by';
$query = "
    SELECT
        incident_status_logs.id,
        incident_status_logs.$old_col AS old_status,
        incident_status_logs.$new_col AS new_status,
        incident_status_logs.remarks,
        incident_status_logs.$user_col AS user_id,
        users.name AS user_name,
        users.role AS user_role,
        incident_status_logs.created_at
    FROM incident_status_logs
    LEFT JOIN users ON incident_status_logs.$user_col = users.id
    WHERE incident_status_logs.$report_col = ?
    ORDER BY incident_status_logs.created_at ASC
";
$stmt = mysqli_prepare($connection, $query);
if (!$stmt) send_response(false, fail_message("Failed to prepare status logs query.", mysqli_error($connection)));
mysqli_stmt_bind_param($stmt, "i", $report_id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$data = [];
while ($row = mysqli_fetch_assoc($result)) {
    $data[] = [
        "id" => (int)$row['id'],
        "old_status" => $row['old_status'],
        "new_status" => $row['new_status'],
        "remarks" => $row['remarks'],
        "user_id" => $row['user_id'] !== null ? (int)$row['user_id'] : null,
        "user_name" => $row['user_name'],
        "user_role" => $row['user_role'],
        "created_at" => $row['created_at']
    ];
}
send_response(true, "Status timeline loaded.", $data);
?>
