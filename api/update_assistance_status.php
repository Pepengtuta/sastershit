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
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active') {
    send_response(false, "You are not authorized to update assistance status.");
}
$V_role = $actorRow['role'];
$V_sub_role = $actorRow['sub_role'] ?? '';
if (!in_array($V_role, ['superadmin', 'pho', 'pcf'], true)) {
    send_response(false, "You are not authorized to update assistance status.");
}

$V_id = (int)($input['assistance_id'] ?? 0);
$V_action = trim($input['action'] ?? '');

$LedgerStmt = mysqli_prepare($connection, "SELECT a.*, ec.municipality AS ec_muni FROM evac_assistance a INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id WHERE a.id = ? LIMIT 1");
mysqli_stmt_bind_param($LedgerStmt, "i", $V_id);
mysqli_stmt_execute($LedgerStmt);
$donation = mysqli_fetch_assoc(mysqli_stmt_get_result($LedgerStmt));
if (!$donation) send_response(false, "Assistance record not found.");

// MDR/mayor sub-roles only inside their own municipality (DB sub_role check).
// The Governor (pho) is exempt and can update any municipality.
if ($V_role === 'pcf') {
    $sub = strtolower(trim($V_sub_role));
    if ($sub === 'mdr_kalibo' && $donation['ec_muni'] !== 'Kalibo') send_response(false, "You may only update statuses in Kalibo.");
    if ($sub === 'mdr_ibajay' && $donation['ec_muni'] !== 'Ibajay') send_response(false, "You may only update statuses in Ibajay.");
    if ($sub === 'mayor_kalibo' && $donation['ec_muni'] !== 'Kalibo') send_response(false, "You may only update statuses in Kalibo.");
    if ($sub === 'mayor_ibajay' && $donation['ec_muni'] !== 'Ibajay') send_response(false, "You may only update statuses in Ibajay.");
}

// Only the donor, a provincial office (PHO admin / PDRRMO - not the Governor),
// or superadmin DB owner may advance the status.
$V_prov_override = ($V_role === 'superadmin') || ($V_role === 'pho' && strtolower(trim((string)$V_sub_role)) !== 'governor');
if ((int)$donation['donor_user_id'] !== $acting_user_id && !$V_prov_override) {
    send_response(false, "Only the donor or a provincial/superadmin user may update this status.");
}

if ($V_action === 'send') {
    if ($donation['status'] !== 'Pledged') send_response(false, "Only a Pledged donation can be marked Sent.");
    // sent_at is set once (NULL-safe) so a re-submit can't rewrite history.
    $Update = "UPDATE evac_assistance SET status = 'Sent', sent_at = COALESCE(sent_at, NOW()) WHERE id = ?";
} elseif ($V_action === 'deliver') {
    if ($donation['status'] === 'Delivered') send_response(false, "This donation is already Delivered.");
    $Update = "UPDATE evac_assistance
               SET status = 'Delivered',
                   sent_at = COALESCE(sent_at, NOW()),
                   delivered_at = COALESCE(delivered_at, NOW())
               WHERE id = ?";
} else {
    send_response(false, "Unknown action. Use 'send' or 'deliver'.");
}

$stmt = mysqli_prepare($connection, $Update);
mysqli_stmt_bind_param($stmt, "i", $V_id);
if (mysqli_stmt_execute($stmt)) {
    $next = ($V_action === 'send') ? 'Sent' : 'Delivered';
    send_response(true, "Assistance status updated to $next.", ["id" => $V_id]);
}
send_response(false, "Failed to update assistance status.");
?>