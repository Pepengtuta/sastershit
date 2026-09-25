<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
$input = json_decode(file_get_contents("php://input"), true) ?: [];
$role = strtolower(trim($input['role'] ?? ''));
$barangay_id = $input['barangay_id'] ?? null;
$search = trim($input['search'] ?? '');
$category = trim($input['category'] ?? 'All');
$municipality = trim($input['municipality'] ?? '');
$where = "WHERE emergency_hotlines.status = 'Active'"; $params=[]; $types="";
if ($role === 'barangay' || $role === 'brgy') {
    if ($municipality !== '') {
        $where .= " AND (emergency_hotlines.municipality = ? OR (emergency_hotlines.municipality IS NULL AND emergency_hotlines.hotline_scope = 'Municipal'))";
        $params[] = $municipality; $types .= "s";
    } else {
        $where .= " AND (emergency_hotlines.hotline_scope = 'Municipal' OR emergency_hotlines.barangay_id = ? OR emergency_hotlines.barangay_id IS NULL)";
        $params[] = (int)$barangay_id; $types .= "i";
    }
}
// Municipality filter for admin roles
$admin_roles = ['pcf', 'pho', 'superadmin'];
if (in_array($role, $admin_roles) && $municipality !== '') {
    $where .= " AND (emergency_hotlines.municipality = ? OR (emergency_hotlines.municipality IS NULL AND emergency_hotlines.hotline_scope = 'Municipal'))"; $params[] = $municipality; $types .= "s";
}
if ($category !== '' && strtolower($category) !== 'all') {
    if (strtolower($category) === 'barangay' || strtolower($category) === 'municipal') {
        $where .= " AND emergency_hotlines.hotline_scope = ?"; $params[] = ucfirst(strtolower($category)); $types .= "s";
    } else {
        $where .= " AND emergency_hotlines.category LIKE ?"; $params[] = "%$category%"; $types .= "s";
    }
}
if ($search !== '') {
    $where .= " AND (emergency_hotlines.office_name LIKE ? OR emergency_hotlines.municipality LIKE ? OR emergency_hotlines.category LIKE ? OR emergency_hotlines.telephone_numbers LIKE ? OR emergency_hotlines.cellphone_numbers LIKE ? OR emergency_hotlines.hotline_number LIKE ?)";
    $like="%$search%"; array_push($params,$like,$like,$like,$like,$like,$like); $types .= "ssssss";
}
$query = "SELECT emergency_hotlines.id, emergency_hotlines.hotline_scope, emergency_hotlines.barangay_id, barangays.name AS barangay_name, emergency_hotlines.office_name, emergency_hotlines.municipality, emergency_hotlines.category, emergency_hotlines.telephone_numbers, emergency_hotlines.cellphone_numbers, emergency_hotlines.hotline_number, emergency_hotlines.remarks, emergency_hotlines.status FROM emergency_hotlines LEFT JOIN barangays ON emergency_hotlines.barangay_id = barangays.id $where ORDER BY emergency_hotlines.hotline_scope ASC, emergency_hotlines.office_name ASC";
$stmt = mysqli_prepare($connection, $query);
if (!$stmt) send_response(false, fail_message("Failed to prepare hotlines query.", mysqli_error($connection)));
if (!empty($params)) mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);
$result=mysqli_stmt_get_result($stmt);
$data=[];
while($row=mysqli_fetch_assoc($result)) $data[]=$row;
send_response(true, "Hotlines loaded successfully.", $data);
?>
