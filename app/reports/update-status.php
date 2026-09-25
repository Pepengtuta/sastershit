<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";

if (!isset($_SESSION['user_id'])) {
    header("Location: ../../public/login.php");
    exit;
}

    // Municipal manages status on all reports. Chairman can review/forward/dismiss. Provincial can respond/resolve on referred reports.
$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';

// Mayor observers are read-only and cannot change report status.
require_once __DIR__ . "/../includes/functions.php";
if (is_readonly_role($V_role, $V_sub_role)) {
    header("Location: ../../public/incident-reports.php");
    exit;
}

$V_is_captain = ($V_role === 'barangay' && $V_sub_role === 'captain');
$V_is_pcf = ($V_role === 'pcf');
$V_is_pho = ($V_role === 'pho');

if (!$V_is_captain && !$V_is_pcf && !$V_is_pho) {
    header("Location: ../../public/incident-reports.php");
    exit;
}

$V_user_id = (int)$_SESSION['user_id'];
$V_report_id = (int)($_POST['report_id'] ?? 0);
$V_status = trim($_POST['status'] ?? '');
$V_remarks = trim($_POST['remarks'] ?? '');
$V_return_page = trim($_POST['return_page'] ?? 'incident-reports.php');

$V_allowed_pages = ['incident-reports.php', 'review-reports.php', 'health-reports.php', 'dashboard.php'];

if (!in_array($V_return_page, $V_allowed_pages)) {
    $V_return_page = 'incident-reports.php';
}

    // Chairman can only set: Reviewed, Forwarded to Municipal, Dismissed.
// Municipal can set: Verified, Responding, Referred to Provincial, Resolved, Dismissed.
// Provincial can set: Responding, Resolved.
$V_allowed_status = ['Pending', 'Reviewed', 'Forwarded to PCF', 'Under MDR Review', 'Verified', 'Responding', 'Referred to PHO', 'Under PHO Review', 'Resolved', 'Dismissed'];

if ($V_report_id <= 0 || !in_array($V_status, $V_allowed_status)) {
    header("Location: ../../public/$V_return_page?error=1");
    exit;
}

// Enforce role-specific status transitions.
if ($V_is_captain && !in_array($V_status, ['Reviewed', 'Forwarded to PCF', 'Dismissed'])) {
    header("Location: ../../public/$V_return_page?error=1");
    exit;
}

$GetOldQuery = "SELECT * FROM incident_reports WHERE id = ? LIMIT 1";
$get_stmt = mysqli_prepare($connection, $GetOldQuery);
mysqli_stmt_bind_param($get_stmt, "i", $V_report_id);
mysqli_stmt_execute($get_stmt);
$GetOldResult = mysqli_stmt_get_result($get_stmt);
$OldRow = mysqli_fetch_assoc($GetOldResult);

if (!$OldRow) {
    header("Location: ../../public/$V_return_page?error=1");
    exit;
}

$V_old_status = $OldRow['status'];

// MDR review gate: a report still at 'Forwarded to PCF' has not been
// acknowledged. Municipal may only acknowledge it first ('Under MDR Review');
// Verify / Respond / Dismiss / Send to Provincial all require prior acknowledgment.
if ($V_is_pcf) {
    if ($V_status === 'Under MDR Review' && $V_old_status !== 'Forwarded to PCF') {
        header("Location: ../../public/$V_return_page?error=1");
        exit;
    }
    if ($V_old_status === 'Forwarded to PCF' && $V_status !== 'Under MDR Review') {
        header("Location: ../../public/$V_return_page?error=1");
        exit;
    }
}

// PHO review gate: mirrors the MDR gate. A referred report must be
// acknowledged ('Under PHO Review', with legacy 'Forwarded to PHO' as a
// valid ack source) before Respond / Resolve are allowed.
if ($V_is_pho) {
    $V_awaiting_pho = ($V_old_status === 'Referred to PHO' || $V_old_status === 'Forwarded to PHO');
    if ($V_status === 'Under PHO Review' && !$V_awaiting_pho) {
        header("Location: ../../public/$V_return_page?error=1");
        exit;
    }
    if ($V_awaiting_pho && $V_status !== 'Under PHO Review') {
        header("Location: ../../public/$V_return_page?error=1");
        exit;
    }
}

mysqli_begin_transaction($connection);

try {
    if ($V_status == 'Referred to PHO') {
        $UpdateQuery = "UPDATE incident_reports SET status = ?, referred_to_pho = 1 WHERE id = ?";
    } else {
        $UpdateQuery = "UPDATE incident_reports SET status = ? WHERE id = ?";
    }

    $update_stmt = mysqli_prepare($connection, $UpdateQuery);
    mysqli_stmt_bind_param($update_stmt, "si", $V_status, $V_report_id);

    if (!mysqli_stmt_execute($update_stmt)) {
        throw new Exception(mysqli_error($connection));
    }

    if ($V_old_status != $V_status) {
        if ($V_remarks == '') {
            $V_remarks = "Status updated from $V_old_status to $V_status.";
        }

        $LogQuery = "INSERT INTO incident_status_logs
                     (incident_report_id, old_status, new_status, remarks, updated_by)
                     VALUES (?, ?, ?, ?, ?)";
        $log_stmt = mysqli_prepare($connection, $LogQuery);
        mysqli_stmt_bind_param($log_stmt, "isssi", $V_report_id, $V_old_status, $V_status, $V_remarks, $V_user_id);

        if (!mysqli_stmt_execute($log_stmt)) {
            throw new Exception(mysqli_error($connection));
        }
    }

    mysqli_commit($connection);
    header("Location: ../../public/$V_return_page?updated=1");
    exit;
} catch (Exception $e) {
    mysqli_rollback($connection);
    error_log("Transaction error: " . $e->getMessage());
    echo "Something went wrong. Please try again.";
}
?>
