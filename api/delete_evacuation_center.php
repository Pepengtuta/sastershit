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

// Role enforcement: Superadmin, Provincial Office, or Municipal (PCF/MDR) may delete evacuation centers.
// Barangay Chairmen (captain) may delete centers ONLY within their own barangay.
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
    send_response(false, "You are not authorized to delete evacuation centers.");
}
// Read-only observers (mayors + Governor) cannot manage evacuation centers.
if ($actorRow['role'] === 'pcf' && in_array($actorRow['sub_role'] ?? '', ['mayor_kalibo', 'mayor_ibajay'], true)
        || ($actorRow['role'] === 'pho' && ($actorRow['sub_role'] ?? '') === 'governor')) {
    send_response(false, "You are not authorized to delete evacuation centers.");
}

$id = (int)($input['id'] ?? 0);
if ($id <= 0) send_response(false, "Invalid evacuation center ID.");

// Barangay chairmen may only delete centers inside their own barangay.
if ($actorRow['role'] === 'barangay') {
    $V_actor_barangay_id = (int)$actorRow['barangay_id'];
    $scopeStmt = mysqli_prepare($connection,
        "SELECT 1 FROM evacuation_centers ec JOIN barangays b ON b.name = ec.barangay WHERE ec.id = ? AND b.id = ? LIMIT 1");
    mysqli_stmt_bind_param($scopeStmt, "ii", $id, $V_actor_barangay_id);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        send_response(false, "You may only delete evacuation centers in your own barangay.");
    }
}

// MDR sub-roles may only delete centers within their own municipality.
$mdr_muni = ['mdr_kalibo' => 'Kalibo', 'mdr_ibajay' => 'Ibajay'][$actorRow['sub_role']] ?? null;
if ($actorRow['role'] === 'pcf' && $mdr_muni !== null) {
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM evacuation_centers WHERE id = ? AND municipality = ? LIMIT 1");
    mysqli_stmt_bind_param($scopeStmt, "is", $id, $mdr_muni);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        send_response(false, "You may only delete evacuation centers in " . $mdr_muni . ".");
    }
}

$stmt = mysqli_prepare($connection, "DELETE FROM evacuation_centers WHERE id = ?");
if (!$stmt) send_response(false, "Failed to prepare delete.");
mysqli_stmt_bind_param($stmt, "i", $id);
if (!mysqli_stmt_execute($stmt)) send_response(false, "Failed to delete evacuation center.");
if (mysqli_affected_rows($connection) === 0) send_response(false, "Evacuation center not found.");
send_response(true, "Evacuation center deleted successfully.");
?>
