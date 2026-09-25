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

// Role enforcement: Superadmin / PHO / PCF may view any center's needs.
// Barangay Chairmen (captain) may view ONLY their own barangay's centers.
$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active') {
    send_response(false, "You are not authorized to view center needs.");
}
$V_role = $actorRow['role'];
$V_sub_role = $actorRow['sub_role'] ?? '';
$allowed = in_array($V_role, ['superadmin', 'pho', 'pcf'], true)
    || ($V_role === 'barangay' && in_array($V_sub_role, ['captain', 'secretary'], true));
if (!$allowed) {
    send_response(false, "You are not authorized to view center needs.");
}
// Read-only observers may VIEW, so allow them here (matching can_view_assistance).

$V_center_id = (int)($input['evac_center_id'] ?? 0);
if ($V_center_id <= 0) send_response(false, "Evacuation center ID is required.");

$CenterStmt = mysqli_prepare($connection, "SELECT id, center_name, barangay, municipality FROM evacuation_centers WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($CenterStmt, "i", $V_center_id);
mysqli_stmt_execute($CenterStmt);
$center = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterStmt));
if (!$center) send_response(false, "Evacuation center not found.");

// Chairmen only their own barangay.
if ($V_role === 'barangay') {
    if ((int)($actorRow['barangay_id'] ?? 0) <= 0) send_response(false, "Barangay account is missing a barangay.");
    $brgyStmt = mysqli_prepare($connection, "SELECT name FROM barangays WHERE id = ? LIMIT 1");
    $V_actor_barangay_id = (int)$actorRow['barangay_id'];
    mysqli_stmt_bind_param($brgyStmt, "i", $V_actor_barangay_id);
    mysqli_stmt_execute($brgyStmt);
    $brgyRow = mysqli_fetch_assoc(mysqli_stmt_get_result($brgyStmt));
    if (!$brgyRow || $center['barangay'] !== $brgyRow['name']) {
        send_response(false, "You may only view centers in your own barangay.");
    }
}
// MDR sub-roles only their own municipality.
$mdr_muni = ['mdr_kalibo' => 'Kalibo', 'mdr_ibajay' => 'Ibajay'][$V_sub_role] ?? null;
if ($V_role === 'pcf' && $mdr_muni !== null && $center['municipality'] !== $mdr_muni) {
    send_response(false, "You may only view centers in " . $mdr_muni . ".");
}

$profile = null;
$ProfileStmt = mysqli_prepare($connection, "SELECT * FROM evac_center_profile WHERE evac_center_id = ? LIMIT 1");
mysqli_stmt_bind_param($ProfileStmt, "i", $V_center_id);
mysqli_stmt_execute($ProfileStmt);
$ProfileRes = mysqli_stmt_get_result($ProfileStmt);
if ($ProfileRes) {
    if ($prow = mysqli_fetch_assoc($ProfileRes)) {
        $profile = $prow;
    }
    mysqli_free_result($ProfileRes);
}
mysqli_stmt_free_result($ProfileStmt);

$needs = [];
$NeedsStmt = mysqli_prepare($connection, "SELECT id, item, unit, qty_needed FROM evac_center_needs WHERE evac_center_id = ? ORDER BY id ASC");
mysqli_stmt_bind_param($NeedsStmt, "i", $V_center_id);
mysqli_stmt_execute($NeedsStmt);
$NeedsRes = mysqli_stmt_get_result($NeedsStmt);
if ($NeedsRes) {
    while ($n = mysqli_fetch_assoc($NeedsRes)) {
        $needs[] = [
            "id" => (int)$n['id'],
            "item" => $n['item'],
            "unit" => $n['unit'],
            "qty_needed" => (int)$n['qty_needed'],
        ];
    }
    mysqli_free_result($NeedsRes);
}
mysqli_stmt_free_result($NeedsStmt);

// Fulfillment status per need: pledged / sent / delivered / received + who is helping.
$fulfillment = [];
$FullStmt = mysqli_prepare($connection, "SELECT need_id,
                       SUM(CASE WHEN status = 'Pledged' THEN qty ELSE 0 END) AS pledged_qty,
                       SUM(CASE WHEN status = 'Sent' THEN qty ELSE 0 END) AS sent_qty,
                       SUM(CASE WHEN status = 'Delivered' THEN qty ELSE 0 END) AS delivered_qty,
                       SUM(CASE WHEN received_at IS NOT NULL THEN COALESCE(qty_received, qty) ELSE 0 END) AS received_qty,
                       GROUP_CONCAT(DISTINCT donor_label ORDER BY donor_label SEPARATOR ', ') AS helpers
                   FROM evac_assistance
                   WHERE evac_center_id = ?
                   GROUP BY need_id");
mysqli_stmt_bind_param($FullStmt, "i", $V_center_id);
mysqli_stmt_execute($FullStmt);
$FullRes = mysqli_stmt_get_result($FullStmt);
if ($FullRes) {
    while ($f = mysqli_fetch_assoc($FullRes)) {
        $fulfillment[] = [
            "need_id" => $f['need_id'] !== null ? (int)$f['need_id'] : null,
            "pledged" => (int)$f['pledged_qty'],
            "sent" => (int)$f['sent_qty'],
            "delivered" => (int)$f['delivered_qty'],
            "received" => (int)$f['received_qty'],
            "helpers" => $f['helpers'] ?? '',
        ];
    }
    mysqli_free_result($FullRes);
}
mysqli_stmt_free_result($FullStmt);

// Per-donation ledger for this center (read-only): who donated what, when.
$ledger = [];
$LedgerStmt = mysqli_prepare($connection, "SELECT a.id, a.donor_label, a.item, a.unit, a.qty, a.qty_received, a.status,
                     a.remarks, a.over_pledge_flag, a.pledged_at, a.sent_at, a.delivered_at,
                     a.received_at, a.confirmed_by_user_id,
                     n.item AS need_item
              FROM evac_assistance a
              LEFT JOIN evac_center_needs n ON n.id = a.need_id
              WHERE a.evac_center_id = ?
              ORDER BY a.created_at DESC, a.id DESC");
if ($LedgerStmt) {
    mysqli_stmt_bind_param($LedgerStmt, "i", $V_center_id);
    if (mysqli_stmt_execute($LedgerStmt)) {
        $LedgerRes = mysqli_stmt_get_result($LedgerStmt);
        if ($LedgerRes) {
            while ($d = mysqli_fetch_assoc($LedgerRes)) {
                $ledger[] = [
                    "id" => (int)$d['id'],
                    "donor_label" => $d['donor_label'],
                    "item" => $d['item'],
                    "unit" => $d['unit'],
                    "qty" => (int)$d['qty'],
                    "qty_received" => $d['qty_received'] !== null ? (int)$d['qty_received'] : null,
                    "status" => $d['status'],
                    "remarks" => $d['remarks'],
                    "for_item" => $d['need_item'],
                    "over_pledge" => (int)$d['over_pledge_flag'],
                    "pledged_at" => $d['pledged_at'],
                    "sent_at" => $d['sent_at'],
                    "delivered_at" => $d['delivered_at'],
                    "received_at" => $d['received_at'],
                    "confirmed_by_user_id" => $d['confirmed_by_user_id'],
                ];
            }
            mysqli_free_result($LedgerRes);
        }
    }
    mysqli_stmt_free_result($LedgerStmt);
}

// The incident this center is backed by, if any (null when needs are unverified).
$incident = credited_incident_for_center($connection, $V_center_id);
if ($incident) {
    $incident['status_label'] = incident_status_label($incident['status'], $center['municipality'] ?? '');
}

// Read-only reference headcount from credited linked reports (never overwrites profile).
$computed_headcount = computed_headcount_for_center($connection, $V_center_id);

send_response(true, "Center needs loaded successfully.", [
    "center" => $center,
    "profile" => $profile,
    "computed_headcount" => $computed_headcount,
    "needs" => $needs,
    "fulfillment" => $fulfillment,
    "ledger" => $ledger,
    "incident" => $incident,
]);
?>