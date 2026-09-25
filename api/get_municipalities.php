<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
$result = mysqli_query($connection, "SELECT DISTINCT municipality FROM barangays WHERE municipality IS NOT NULL AND municipality != '' ORDER BY municipality ASC");
$municipalities = [];
if ($result) { while ($row = mysqli_fetch_assoc($result)) { $municipalities[] = $row['municipality']; } }
send_response(true, "Municipalities loaded.", $municipalities);
?>