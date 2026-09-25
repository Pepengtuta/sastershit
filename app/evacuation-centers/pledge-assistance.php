<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";
include "../includes/functions.php";

if (!isset($_SESSION['user_id']) || !can_pledge_assistance($_SESSION['role'], $_SESSION['sub_role'] ?? '')) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

$V_role        = $_SESSION['role'];
$V_sub_role    = $_SESSION['sub_role'] ?? '';
$V_user_id     = (int)($_SESSION['user_id'] ?? 0);
$V_center_id   = (int)($_POST['evac_center_id'] ?? 0);
$V_need_id     = (int)($_POST['need_id'] ?? 0);
$V_item        = trim($_POST['item'] ?? '');
$V_unit        = trim($_POST['unit'] ?? 'pcs');
$V_qty         = (int)($_POST['qty'] ?? 0);
$V_remarks     = trim($_POST['remarks'] ?? '');

$allowed_units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];
if (!in_array($V_unit, $allowed_units, true)) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

// The center must exist (and, for MDR sub-roles, be inside their municipality).
$CenterStmt = mysqli_prepare($connection, "SELECT id, center_name, municipality FROM evacuation_centers WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($CenterStmt, "i", $V_center_id);
mysqli_stmt_execute($CenterStmt);
$center = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterStmt));
if (!$center) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}
if (($V_muni = mdr_municipality($V_role, $V_sub_role)) && $center['municipality'] !== $V_muni) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

// Validate the need belongs to the target center when one is supplied.
if ($V_need_id > 0) {
    $NeedCheck = mysqli_prepare($connection, "SELECT id FROM evac_center_needs WHERE id = ? AND evac_center_id = ? LIMIT 1");
    mysqli_stmt_bind_param($NeedCheck, "ii", $V_need_id, $V_center_id);
    mysqli_stmt_execute($NeedCheck);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($NeedCheck))) {
        $V_need_id = 0;
    }
}

if ($V_center_id <= 0 || $V_item === '' || $V_qty <= 0) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

// Soft over-pledge check (warn, never block): count committed supply against
// the declared need and flag the pledge when qty exceeds what's still unmet.
$V_over_pledge = 0;
if ($V_need_id > 0) {
    $V_remaining = pledge_remaining_for_need($connection, $V_need_id);
    $V_over_pledge = ($V_qty > $V_remaining) ? 1 : 0;
}

// Donor label shown on the ledger (who donated what to where).
if ($V_role === 'pcf') {
    $V_donor_muni = mdr_municipality($V_role, $V_sub_role);
    if ($V_donor_muni) {
        $V_donor_label = 'MDRRMO ' . $V_donor_muni;
    } elseif ($V_sub_role === 'mdr_admin') {
        $V_donor_label = 'MDR Admin';
    } else {
        $V_donor_label = 'Municipal Office';
    }
} elseif ($V_role === 'pho') {
    $V_donor_label = ($V_sub_role === 'pdrrmo') ? 'PDRRMO' : 'PHO Provincial Health Office';
} else {
    $V_donor_label = 'Super Admin';
}

$Insert = "INSERT INTO evac_assistance
    (evac_center_id, need_id, donor_user_id, donor_label, item, unit, qty, status, pledged_at, remarks, over_pledge_flag)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'Pledged', NOW(), ?, ?)";
$stmt = mysqli_prepare($connection, $Insert);
if (!$stmt) {
    echo fail_message("Something went wrong.", "DB error: " . mysqli_error($connection));
    exit;
}
mysqli_stmt_bind_param($stmt, "iiissiisi", $V_center_id, $V_need_id, $V_user_id, $V_donor_label, $V_item, $V_unit, $V_qty, $V_remarks, $V_over_pledge);

if (mysqli_stmt_execute($stmt)) {
    header("Location: ../../public/assistance.php?pledged=1");
    exit;
}

echo fail_message("Something went wrong recording the pledge.", "DB error: " . mysqli_error($connection));
?>