<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";

function send_response($success, $message, $data = []) {
    echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]);
    exit;
}

$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");

$report_id = (int)($input['report_id'] ?? 0);
$user_id = (int)($input['user_id'] ?? 0);
$status = trim($input['status'] ?? '');
$remarks = trim($input['remarks'] ?? 'Status updated from mobile app.');
$referred_to_pho = (int)($input['referred_to_pho'] ?? 0);

if ($report_id <= 0 || $user_id <= 0 || $status === '') {
    send_response(false, "Report ID, user ID, and status are required.");
}

// Normalize legacy label.
if ($status === 'Forwarded to PHO') $status = 'Referred to PHO';

// FIX: only allow known status values (same list the web app already enforces).
$allowed_statuses = ['Pending','Reviewed','Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed'];
if (!in_array($status, $allowed_statuses, true)) {
    send_response(false, "Invalid status value.");
}

// FIX: look up the real role from the database using the user_id the app already sends.
// Never trust a role value sent by the client.
$actor_role = null;
$actor_sub_role = null;
$actor_stmt = mysqli_prepare($connection, "SELECT role, sub_role FROM users WHERE id = ? AND status = 'Active' LIMIT 1");
if ($actor_stmt) {
    mysqli_stmt_bind_param($actor_stmt, "i", $user_id);
    mysqli_stmt_execute($actor_stmt);
    $actor_res = mysqli_stmt_get_result($actor_stmt);
    if ($actor_row = mysqli_fetch_assoc($actor_res)) {
        $actor_role = strtolower($actor_row['role']);
        $actor_sub_role = strtolower($actor_row['sub_role'] ?? '');
    }
}
if ($actor_role === null) {
    send_response(false, "Your account was not found or is inactive.");
}

// FIX: only these roles may change a report status.
$allowed_roles = ['pcf', 'pho', 'barangay'];
if (!in_array($actor_role, $allowed_roles, true)) {
    send_response(false, "You do not have permission to update report status.");
}

// Read-only observers (mayors + Governor) cannot change report status.
if (($actor_role === 'pcf' && in_array($actor_sub_role, ['mayor_kalibo', 'mayor_ibajay'], true))
        || ($actor_role === 'pho' && $actor_sub_role === 'governor')) {
    send_response(false, "You do not have permission to update report status.");
}

// Chairman can only set: Reviewed, Forwarded to Municipal, Dismissed.
if ($actor_role === 'barangay' && $actor_sub_role === 'captain') {
    $captain_statuses = ['Reviewed', 'Forwarded to PCF', 'Dismissed'];
    if (!in_array($status, $captain_statuses, true)) {
        send_response(false, "Chairmen can only Review, Forward to Municipal, or Dismiss reports.");
    }
} elseif ($actor_role === 'barangay') {
    send_response(false, "Only Chairmen can update report status.");
}

// Get current status and confirm the report exists.
$old = null;
$old_stmt = mysqli_prepare($connection, "SELECT status FROM incident_reports WHERE id = ? LIMIT 1");
if ($old_stmt) {
    mysqli_stmt_bind_param($old_stmt, "i", $report_id);
    mysqli_stmt_execute($old_stmt);
    $old_res = mysqli_stmt_get_result($old_stmt);
    if ($old_row = mysqli_fetch_assoc($old_res)) $old = $old_row['status'];
}
if ($old === null) {
    send_response(false, "Report not found.");
}

// MDR review gate: a report still at 'Forwarded to PCF' has not been
// acknowledged. Municipal may only acknowledge it first ('Under MDR Review');
// Verify / Respond / Dismiss / Refer Provincial all require prior acknowledgment.
if ($actor_role === 'pcf') {
    if ($status === 'Under MDR Review' && $old !== 'Forwarded to PCF') {
        send_response(false, "This report is not awaiting acknowledgment and cannot be marked Under MDR Review.");
    }
    if ($old === 'Forwarded to PCF' && $status !== 'Under MDR Review') {
        send_response(false, "Acknowledge this report before acting on it.");
    }
}

// PHO review gate: mirrors the MDR gate. A referred report must be
// acknowledged ('Under PHO Review', with legacy 'Forwarded to PHO' as a
// valid ack source) before Respond / Resolve are allowed.
if ($actor_role === 'pho') {
    $awaiting_pho = ($old === 'Referred to PHO' || $old === 'Forwarded to PHO');
    if ($status === 'Under PHO Review' && !$awaiting_pho) {
        send_response(false, "This report is not awaiting acknowledgment and cannot be marked Under PHO Review.");
    }
    if ($awaiting_pho && $status !== 'Under PHO Review') {
        send_response(false, "Acknowledge this report before acting on it.");
    }
}

if ($status === 'Referred to PHO') $referred_to_pho = 1;

$stmt = mysqli_prepare($connection, "UPDATE incident_reports SET status = ?, referred_to_pho = IF(? = 1, 1, referred_to_pho) WHERE id = ?");
// FIX: generic error message (was leaking mysqli_error()).
if (!$stmt) send_response(false, "Could not update the report. Please try again.");
mysqli_stmt_bind_param($stmt, "sii", $status, $referred_to_pho, $report_id);
if (!mysqli_stmt_execute($stmt)) send_response(false, "Could not update the report. Please try again.");

$log = mysqli_prepare($connection, "INSERT INTO incident_status_logs (incident_report_id, old_status, new_status, remarks, updated_by, created_at) VALUES (?, ?, ?, ?, ?, NOW())");
if ($log) {
    mysqli_stmt_bind_param($log, "isssi", $report_id, $old, $status, $remarks, $user_id);
    mysqli_stmt_execute($log);
}

send_response(true, "Report status updated successfully.", ["report_id"=>$report_id, "status"=>$status, "referred_to_pho"=>$referred_to_pho]);
?>
