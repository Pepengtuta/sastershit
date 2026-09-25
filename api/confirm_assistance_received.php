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

$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active') {
    send_response(false, "You are not authorized to confirm received donations.");
}
$V_role = $actorRow['role'];
$V_sub_role = $actorRow['sub_role'] ?? '';
// Only the receiving barangay (Captain/Secretary) may confirm receipt.
if ($V_role !== 'barangay' || !in_array($V_sub_role, ['captain', 'secretary'], true)) {
    send_response(false, "Only a barangay Chairman or Secretary can confirm received donations.");
}
if ((int)($actorRow['barangay_id'] ?? 0) <= 0) {
    send_response(false, "Barangay account is missing a barangay.");
}

$V_id = (int)($input['assistance_id'] ?? 0);
if ($V_id <= 0) send_response(false, "Assistance record ID is required.");

$qty_received = $input['qty_received'] ?? null;

// The donation must be Delivered, not yet confirmed, and belong to the actor's own barangay.
$LedgerStmt = mysqli_prepare($connection, "SELECT a.id, a.status, a.received_at, a.confirmed_by_user_id, a.qty,
                     ec.id AS center_id, ec.barangay AS center_barangay
              FROM evac_assistance a
              INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
              WHERE a.id = ? LIMIT 1");
mysqli_stmt_bind_param($LedgerStmt, "i", $V_id);
mysqli_stmt_execute($LedgerStmt);
$donation = mysqli_fetch_assoc(mysqli_stmt_get_result($LedgerStmt));
if (!$donation) send_response(false, "Assistance record not found.");
if ($donation['status'] !== 'Delivered') send_response(false, "Only a delivered donation can be confirmed as received.");
if ($donation['received_at'] !== null) send_response(false, "This donation is already confirmed as received.");

$brgy_id = (int)$actorRow['barangay_id'];
$brgyStmt = mysqli_prepare($connection, "SELECT name FROM barangays WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($brgyStmt, "i", $brgy_id);
mysqli_stmt_execute($brgyStmt);
$brgyRow = mysqli_fetch_assoc(mysqli_stmt_get_result($brgyStmt));
if (!$brgyRow || $donation['center_barangay'] !== $brgyRow['name']) {
    send_response(false, "You may only confirm received donations in your own barangay.");
}

// The count actually checked in at the center: 1 .. the donor's declared qty.
if ($qty_received === null || $qty_received === '' || filter_var($qty_received, FILTER_VALIDATE_INT) === false) {
    send_response(false, "Enter the quantity actually received.");
}
$qty_received = (int)$qty_received;
$V_declared = (int)($donation['qty'] ?? 0);
if ($qty_received < 1 || $qty_received > $V_declared) {
    send_response(false, "Received quantity must be between 1 and the donor's declared quantity ({$V_declared}).");
}

// Guard in the WHERE clause (not just app-level): a double-tap or race can
// never double-confirm or overwrite the original confirmation timestamp.
$Update = "UPDATE evac_assistance
           SET received_at = COALESCE(received_at, NOW()),
               confirmed_by_user_id = ?,
               qty_received = ?
           WHERE id = ? AND received_at IS NULL AND status = 'Delivered'";
$stmt = mysqli_prepare($connection, $Update);
mysqli_stmt_bind_param($stmt, "iii", $acting_user_id, $qty_received, $V_id);
if (mysqli_stmt_execute($stmt) && mysqli_stmt_affected_rows($stmt) === 1) {
    send_response(true, "Donation confirmed as received.", ["id" => $V_id, "qty_received" => $qty_received]);
}
send_response(false, "Failed to confirm the donation. It may have already been received.");
?>