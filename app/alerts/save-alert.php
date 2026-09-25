<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";

if (!isset($_SESSION['user_id']) || ($_SESSION['role'] != 'pcf' && $_SESSION['role'] != 'pho')) {
    header("Location: ../../public/login.php");
    exit;
}

// Mayor observers cannot publish alerts.
require_once dirname(__DIR__, 2) . "/includes/functions.php";
if (is_readonly_role($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '')) {
    header("Location: ../../public/dashboard.php");
    exit;
}

// MDR municipality scope (defense in depth): mdr_kalibo/mdr_ibajay may only
// target barangays within their own municipality. mdr_admin sees all.
$V_mdr_scope = null;
if (($_SESSION['role'] ?? '') === 'pcf' && in_array(($_SESSION['sub_role'] ?? ''), ['mdr_kalibo', 'mdr_ibajay'], true)) {
    $V_mdr_scope = ($_SESSION['sub_role'] === 'mdr_kalibo') ? 'Kalibo' : 'Ibajay';
}

function build_alert_datetime($date, $hour, $minute, $ampm) {
    $date = trim($date ?? '');
    $hour = (int)($hour ?? 0);
    $minute = trim($minute ?? '');
    $ampm = trim($ampm ?? '');

    if ($date == '' || $hour < 1 || $hour > 12 || !preg_match('/^[0-5][0-9]$/', $minute)) {
        return null;
    }

    if ($ampm != 'AM' && $ampm != 'PM') {
        return null;
    }

    if ($ampm == 'PM' && $hour != 12) {
        $hour += 12;
    }

    if ($ampm == 'AM' && $hour == 12) {
        $hour = 0;
    }

    return $date . ' ' . str_pad($hour, 2, '0', STR_PAD_LEFT) . ':' . $minute . ':00';
}

$V_title = trim($_POST['N_title'] ?? '');
$V_alert_type = trim($_POST['N_alert_type'] ?? '');
$V_severity = trim($_POST['N_severity'] ?? 'Low');
$V_message = trim($_POST['N_message'] ?? '');
$V_instructions = trim($_POST['N_instructions'] ?? '');
$V_status = trim($_POST['N_status'] ?? 'Active');
$V_created_by = (int)$_SESSION['user_id'];
$V_barangays = $_POST['N_barangays'] ?? [];

// Provincial advisories always target every active barangay (choosing specific barangays is Municipal-only).
// PDRRMO (pho + sub-role pdrrmo) is excluded: it selects specific barangays via the municipality filter.
$V_is_pho_admin = (($_SESSION['role'] ?? '') === 'pho' && ($_SESSION['sub_role'] ?? '') !== 'pdrrmo');
if ($V_is_pho_admin) {
    $V_barangays = [];
    $V_all_barangays = mysqli_query($connection, "SELECT id FROM barangays WHERE status = 'Active'");
    if ($V_all_barangays) {
        while ($V_brgy_row = mysqli_fetch_assoc($V_all_barangays)) {
            $V_barangays[] = (int)$V_brgy_row['id'];
        }
    }
}

// Scope enforcement: drop any barangay outside the MDR actor's municipality.
if ($V_mdr_scope !== null && is_array($V_barangays)) {
    $V_valid_ids = [];
    $V_scope_esc = mysqli_real_escape_string($connection, $V_mdr_scope);
    $V_scope_result = mysqli_query($connection, "SELECT id FROM barangays WHERE status = 'Active' AND municipality = '$V_scope_esc'");
    if ($V_scope_result) {
        while ($V_row = mysqli_fetch_assoc($V_scope_result)) {
            $V_valid_ids[(int)$V_row['id']] = true;
        }
    }
    $V_barangays = array_values(array_filter($V_barangays, function ($V_id) use ($V_valid_ids) {
        return isset($V_valid_ids[(int)$V_id]);
    }));
}

$V_start_datetime = build_alert_datetime(
    $_POST['N_start_date'] ?? '',
    $_POST['N_start_hour'] ?? '',
    $_POST['N_start_minute'] ?? '',
    $_POST['N_start_ampm'] ?? ''
);

$V_end_datetime = build_alert_datetime(
    $_POST['N_end_date'] ?? '',
    $_POST['N_end_hour'] ?? '',
    $_POST['N_end_minute'] ?? '',
    $_POST['N_end_ampm'] ?? ''
);

$V_allowed_severity = ['Low', 'Moderate', 'High', 'Critical'];
$V_allowed_status = ['Active', 'Inactive', 'Expired'];

if (!in_array($V_severity, $V_allowed_severity)) {
    $V_severity = 'Low';
}

if (!in_array($V_status, $V_allowed_status)) {
    $V_status = 'Active';
}

if ($V_title == '' || $V_alert_type == '' || $V_message == '' || $V_start_datetime === null || $V_end_datetime === null || !is_array($V_barangays) || count($V_barangays) == 0) {
    header("Location: ../../public/add-alert.php?error=1");
    exit;
}

mysqli_begin_transaction($connection);

try {
    $V_insert_alert = "INSERT INTO alerts
                       (title, alert_type, severity, message, instructions, status, start_datetime, end_datetime, created_by)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = mysqli_prepare($connection, $V_insert_alert);
    mysqli_stmt_bind_param($stmt, "ssssssssi", $V_title, $V_alert_type, $V_severity, $V_message, $V_instructions, $V_status, $V_start_datetime, $V_end_datetime, $V_created_by);

    if (!mysqli_stmt_execute($stmt)) {
        throw new Exception(mysqli_error($connection));
    }

    $V_alert_id = mysqli_insert_id($connection);

    $V_insert_barangay = "INSERT INTO alert_barangays (alert_id, barangay_id) VALUES (?, ?)";
    $stmt_barangay = mysqli_prepare($connection, $V_insert_barangay);

    foreach ($V_barangays as $V_barangay_id) {
        $V_barangay_id = (int)$V_barangay_id;

        if ($V_barangay_id <= 0) {
            continue;
        }

        mysqli_stmt_bind_param($stmt_barangay, "ii", $V_alert_id, $V_barangay_id);

        if (!mysqli_stmt_execute($stmt_barangay)) {
            throw new Exception(mysqli_error($connection));
        }
    }

    mysqli_commit($connection);
    header("Location: ../../public/alert.php?success=1");
    exit;
} catch (Exception $e) {
    mysqli_rollback($connection);
    error_log("Transaction error: " . $e->getMessage());
    echo "Something went wrong. Please try again.";
}
?>
