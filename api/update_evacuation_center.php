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

// Role enforcement: Superadmin, Provincial Office, or Municipal (PCF/MDR) may update evacuation centers.
// Barangay Chairmen (captain) may update centers ONLY within their own barangay.
$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
$V_allowed_actor = ['superadmin', 'pho', 'pcf'];
if ($actorRow && $actorRow['role'] === 'barangay' && in_array(($actorRow['sub_role'] ?? ''), ['captain', 'secretary'], true)) {
    $V_allowed_actor[] = 'barangay';
}
if (!$actorRow || $actorRow['status'] !== 'Active' || !in_array($actorRow['role'], $V_allowed_actor)) {
    send_response(false, "You are not authorized to update evacuation centers.");
}
// Read-only observers (mayors + Governor) cannot manage evacuation centers.
if ($actorRow['role'] === 'pcf' && in_array($actorRow['sub_role'] ?? '', ['mayor_kalibo', 'mayor_ibajay'], true)
        || ($actorRow['role'] === 'pho' && ($actorRow['sub_role'] ?? '') === 'governor')) {
    send_response(false, "You are not authorized to update evacuation centers.");
}

$id               = (int)($input['id'] ?? 0);
$barangay         = trim($input['barangay'] ?? '');
$barangay_id      = (int)($input['barangay_id'] ?? 0);
$center_name      = trim($input['center_name'] ?? '');
$center_type      = trim($input['center_type'] ?? 'Evacuation Center');
$capacity         = (int)($input['capacity'] ?? 0);
$current_evacuees = (int)($input['current_evacuees'] ?? 0);
$status           = trim($input['status'] ?? 'Available');
$contact_person   = trim($input['contact_person'] ?? '');
$contact_number   = trim($input['contact_number'] ?? '');
$municipality     = trim($input['municipality'] ?? '');

// Server-side hardening: reject invalid numbers instead of silently coercing to 0.
foreach (['capacity', 'current_evacuees'] as $field) {
    if (isset($input[$field]) && (!is_numeric($input[$field]) || (int)$input[$field] < 0)) {
        send_response(false, ucfirst(str_replace('_', ' ', $field)) . " must be a valid non-negative number.");
    }
}
// Contact number must contain at least one digit when non-empty.
if ($contact_number !== '' && !preg_match('/[0-9]/', $contact_number)) {
    send_response(false, "Contact number must contain at least one digit.");
}

// Resolve barangay name and municipality from barangay_id
if ($barangay_id > 0) {
    $q = mysqli_prepare($connection, "SELECT name, municipality FROM barangays WHERE id=? LIMIT 1");
    if ($q) { mysqli_stmt_bind_param($q, "i", $barangay_id); mysqli_stmt_execute($q); $res=mysqli_stmt_get_result($q); if ($row=mysqli_fetch_assoc($res)) { $barangay=$row['name']; if ($municipality === '') $municipality=$row['municipality']; } }
}
if ($barangay === '' && $barangay_id > 0) {
    $q = mysqli_prepare($connection, "SELECT name FROM barangays WHERE id=? LIMIT 1");
    if ($q) { mysqli_stmt_bind_param($q, "i", $barangay_id); mysqli_stmt_execute($q); $res=mysqli_stmt_get_result($q); if ($row=mysqli_fetch_assoc($res)) $barangay=$row['name']; }
}

if ($id <= 0) send_response(false, "Invalid evacuation center ID.");
if ($barangay === '' || $center_name === '') send_response(false, "Barangay and center name are required.");

// Barangay chairmen may only update centers inside their own barangay.
if ($actorRow['role'] === 'barangay') {
    if ((int)($actorRow['barangay_id'] ?? 0) !== $barangay_id) {
        send_response(false, "You may only update evacuation centers in your own barangay.");
    }
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM evacuation_centers WHERE id = ? AND barangay = ? LIMIT 1");
    mysqli_stmt_bind_param($scopeStmt, "is", $id, $barangay);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        send_response(false, "You may only update evacuation centers in your own barangay.");
    }
}

// MDR sub-roles may only update centers within their own municipality.
$mdr_muni = ['mdr_kalibo' => 'Kalibo', 'mdr_ibajay' => 'Ibajay'][$actorRow['sub_role']] ?? null;
if ($actorRow['role'] === 'pcf' && $mdr_muni !== null) {
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM evacuation_centers WHERE id = ? AND municipality = ? LIMIT 1");
    mysqli_stmt_bind_param($scopeStmt, "is", $id, $mdr_muni);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        send_response(false, "You may only update evacuation centers in " . $mdr_muni . ".");
    }
    if ($municipality !== $mdr_muni) send_response(false, "You may only update evacuation centers in " . $mdr_muni . ".");
}

$allowed_status = ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];
if (!in_array($status, $allowed_status)) $status = 'Available';

$stmt = mysqli_prepare($connection,
    "UPDATE evacuation_centers SET
        barangay = ?,
        municipality = ?,
        center_name = ?,
        center_type = ?,
        capacity = ?,
        current_evacuees = ?,
        status = ?,
        contact_person = ?,
        contact_number = ?
     WHERE id = ?"
);
if (!$stmt) send_response(false, "Failed to prepare evacuation center update.");
mysqli_stmt_bind_param($stmt, "ssssiisssi",
    $barangay, $municipality, $center_name, $center_type, $capacity, $current_evacuees,
    $status, $contact_person, $contact_number, $id
);
if (!mysqli_stmt_execute($stmt)) send_response(false, "Failed to update evacuation center: " . mysqli_error($connection));
send_response(true, "Evacuation center updated successfully.", ["id" => $id]);
?>
