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

// Role enforcement: Superadmin and PCF may manage hotlines.
$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active' || !in_array($actorRow['role'], ['superadmin', 'pcf', 'pho'], true)) {
    send_response(false, "You are not authorized to manage hotlines.");
}
// Read-only observers (mayors + Governor) cannot manage hotlines.
if ($actorRow['role'] === 'pcf' && in_array($actorRow['sub_role'] ?? '', ['mayor_kalibo', 'mayor_ibajay'], true)
        || ($actorRow['role'] === 'pho' && ($actorRow['sub_role'] ?? '') === 'governor')) {
    send_response(false, "You are not authorized to manage hotlines.");
}
$scope = trim($input['hotline_scope'] ?? 'Municipal');
$barangay_id = $input['barangay_id'] ?? null;
$office_name = trim($input['office_name'] ?? '');
$municipality = trim($input['municipality'] ?? 'Kalibo');
$category = trim($input['category'] ?? 'Other');
$telephone_numbers = trim($input['telephone_numbers'] ?? '');
$cellphone_numbers = trim($input['cellphone_numbers'] ?? '');
$hotline_number = trim($input['hotline_number'] ?? '');
$remarks = trim($input['remarks'] ?? '');
$status = trim($input['status'] ?? 'Active');
if ($office_name === '') send_response(false, "Office name is required.");
if ($telephone_numbers === '' && $cellphone_numbers === '' && $hotline_number === '') send_response(false, "At least one phone number is required.");
if (strtolower($scope) !== 'barangay') $barangay_id = null;
else $barangay_id = ($barangay_id === null || $barangay_id === '') ? null : (int)$barangay_id;
$stmt = mysqli_prepare($connection, "INSERT INTO emergency_hotlines (hotline_scope, barangay_id, office_name, municipality, category, telephone_numbers, cellphone_numbers, hotline_number, remarks, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())");
if (!$stmt) send_response(false, "Failed to prepare hotline insert: ");
mysqli_stmt_bind_param($stmt, "sissssssss", $scope, $barangay_id, $office_name, $municipality, $category, $telephone_numbers, $cellphone_numbers, $hotline_number, $remarks, $status);
if (!mysqli_stmt_execute($stmt)) send_response(false, "Failed to save hotline: ");
send_response(true, "Hotline saved successfully.", ["id"=>(int)mysqli_insert_id($connection)]);
?>
