<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
require_once "../app/includes/functions.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");

$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active') {
    send_response(false, "You are not authorized to pledge assistance.");
}
$V_role = $actorRow['role'];
$V_sub_role = $actorRow['sub_role'] ?? '';
if (!in_array($V_role, ['superadmin', 'pho', 'pcf'], true)) {
    send_response(false, "You are not authorized to pledge assistance.");
}
$V_center_id = (int)($input['evac_center_id'] ?? 0);
$V_need_id   = (int)($input['need_id'] ?? 0);
$V_item      = trim($input['item'] ?? '');
$V_unit      = trim($input['unit'] ?? 'pcs');
$V_qty       = (int)($input['qty'] ?? 0);
$V_remarks   = trim($input['remarks'] ?? '');

$allowed_units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];
if (!in_array($V_unit, $allowed_units, true)) send_response(false, "Invalid unit.");
if ($V_center_id <= 0 || $V_item === '' || $V_qty <= 0) {
    send_response(false, "Center, item, and a positive quantity are required.");
}

$CenterStmt = mysqli_prepare($connection, "SELECT id, municipality FROM evacuation_centers WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($CenterStmt, "i", $V_center_id);
mysqli_stmt_execute($CenterStmt);
$center = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterStmt));
if (!$center) send_response(false, "Evacuation center not found.");
// MDR/mayor sub-roles may only pledge to their own municipality (checked against DB sub_role).
// The Governor (pho) stays province-wide/unrestricted.
if ($V_role === 'pcf') {
    $sub = strtolower(trim($V_sub_role));
    if ($sub === 'mdr_kalibo' && $center['municipality'] !== 'Kalibo') send_response(false, "You may only pledge to centers in Kalibo.");
    if ($sub === 'mdr_ibajay' && $center['municipality'] !== 'Ibajay') send_response(false, "You may only pledge to centers in Ibajay.");
    if ($sub === 'mayor_kalibo' && $center['municipality'] !== 'Kalibo') send_response(false, "You may only pledge to centers in Kalibo.");
    if ($sub === 'mayor_ibajay' && $center['municipality'] !== 'Ibajay') send_response(false, "You may only pledge to centers in Ibajay.");
}

// Need must belong to the target center when supplied.
if ($V_need_id > 0) {
    $NeedCheck = mysqli_prepare($connection, "SELECT id FROM evac_center_needs WHERE id = ? AND evac_center_id = ? LIMIT 1");
    mysqli_stmt_bind_param($NeedCheck, "ii", $V_need_id, $V_center_id);
    mysqli_stmt_execute($NeedCheck);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($NeedCheck))) {
        $V_need_id = 0;
    }
}
if ($V_need_id === 0) $V_need_id = null;

// Soft over-pledge check (warn, never block): same committed-supply rule as the
// web path, so mobile pledges carry the same audit flag.
$V_over_pledge = 0;
if ($V_need_id > 0) {
    $V_remaining = pledge_remaining_for_need($connection, $V_need_id);
    $V_over_pledge = ($V_qty > $V_remaining) ? 1 : 0;
}

// Donor label shown on the ledger (who donated what to where).
if ($V_role === 'pcf') {
    if ($V_sub_role === 'mdr_kalibo') $V_donor_label = 'MDRRMO Kalibo';
    elseif ($V_sub_role === 'mdr_ibajay') $V_donor_label = 'MDRRMO Ibajay';
    elseif ($V_sub_role === 'mdr_admin') $V_donor_label = 'MDR Admin';
    elseif ($V_sub_role === 'mayor_kalibo') $V_donor_label = 'Mayor Kalibo';
    elseif ($V_sub_role === 'mayor_ibajay') $V_donor_label = 'Mayor Ibajay';
    else $V_donor_label = 'Municipal Office';
} elseif ($V_role === 'pho') {
    if ($V_sub_role === 'pdrrmo') $V_donor_label = 'PDRRMO';
    elseif ($V_sub_role === 'governor') $V_donor_label = 'Governor';
    else $V_donor_label = 'PHO Provincial Health Office';
} else {
    $V_donor_label = 'Super Admin';
}

$Insert = "INSERT INTO evac_assistance
    (evac_center_id, need_id, donor_user_id, donor_label, item, unit, qty, status, pledged_at, remarks, over_pledge_flag)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'Pledged', NOW(), ?, ?)";
$stmt = mysqli_prepare($connection, $Insert);
if (!$stmt) send_response(false, "Failed to prepare pledge insert.");
mysqli_stmt_bind_param($stmt, "iiissiisi", $V_center_id, $V_need_id, $acting_user_id, $V_donor_label, $V_item, $V_unit, $V_qty, $V_remarks, $V_over_pledge);

if (mysqli_stmt_execute($stmt)) {
    send_response(true, "Pledge recorded. Update its status once the supply is on its way or delivered.", [
        "id" => (int)mysqli_insert_id($connection),
        "over_pledge" => (bool)$V_over_pledge,
    ]);
}
send_response(false, "Failed to record the pledge.");
?>