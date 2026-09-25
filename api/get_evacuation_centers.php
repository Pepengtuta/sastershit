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
$barangay_name = trim($input['barangay_name'] ?? '');
$barangay_id = (int)($input['barangay_id'] ?? 0);
$search = trim($input['search'] ?? '');
$municipality = trim($input['municipality'] ?? '');
$where = "WHERE 1=1"; $params=[]; $types="";
if (($role === 'barangay' || $role === 'brgy') && $barangay_name !== '') {
    $where .= " AND evacuation_centers.barangay = ?"; $params[]=$barangay_name; $types.="s";
    // Scope by the barangay's municipality to prevent cross-municipality name collisions
    if ($barangay_id > 0) {
        $muni_q = mysqli_prepare($connection, "SELECT municipality FROM barangays WHERE id = ? LIMIT 1");
        if ($muni_q) {
            mysqli_stmt_bind_param($muni_q, 'i', $barangay_id);
            mysqli_stmt_execute($muni_q);
            $muni_res = mysqli_stmt_get_result($muni_q);
            if ($muni_row = mysqli_fetch_assoc($muni_res)) {
                $where .= " AND evacuation_centers.municipality = ?"; $params[]=$muni_row['municipality']; $types.="s";
            }
        }
    }
}
// Municipality filter for admin roles (direct column filter)
$admin_roles = ['pcf', 'pho', 'superadmin'];
if (in_array($role, $admin_roles) && $municipality !== '') {
    $where .= " AND evacuation_centers.municipality = ?"; $params[]=$municipality; $types.="s";
}
if ($search !== '') { $where .= " AND (evacuation_centers.center_name LIKE ? OR evacuation_centers.barangay LIKE ? OR evacuation_centers.status LIKE ? OR evacuation_centers.center_type LIKE ?)"; $like="%$search%"; array_push($params,$like,$like,$like,$like); $types.="ssss"; }
$query = "SELECT evacuation_centers.id, evacuation_centers.barangay, evacuation_centers.municipality, evacuation_centers.center_name, evacuation_centers.center_type, evacuation_centers.capacity, evacuation_centers.current_evacuees, evacuation_centers.status, evacuation_centers.contact_person, evacuation_centers.contact_number, evacuation_centers.latitude, evacuation_centers.longitude, evacuation_centers.created_at FROM evacuation_centers $where ORDER BY evacuation_centers.barangay ASC, evacuation_centers.center_name ASC";
$stmt = mysqli_prepare($connection, $query);
if (!$stmt) send_response(false, fail_message("Failed to prepare evacuation center query.", mysqli_error($connection)));
if (!empty($params)) mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$data=[];
while ($row=mysqli_fetch_assoc($result)) $data[]=$row;
send_response(true, "Evacuation centers loaded successfully.", $data);
?>
