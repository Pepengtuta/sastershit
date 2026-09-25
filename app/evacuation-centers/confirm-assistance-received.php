<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";
include "../includes/functions.php";

if (!isset($_SESSION['user_id'])) {
    header("Location: ../../public/center-needs.php?denied=1");
    exit;
}

$V_user_id = (int)$_SESSION['user_id'];

// Only the receiving barangay (Captain/Secretary) may confirm receipt.
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $V_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active' || $actorRow['role'] !== 'barangay'
    || !in_array($actorRow['sub_role'] ?? '', ['captain', 'secretary'], true)) {
    header("Location: ../../public/center-needs.php?denied=1");
    exit;
}
if ((int)($actorRow['barangay_id'] ?? 0) <= 0) {
    header("Location: ../../public/center-needs.php?denied=1");
    exit;
}

$V_id = (int)($_POST['assistance_id'] ?? 0);
$V_center_id = (int)($_POST['center_id'] ?? 0);

$LedgerStmt = mysqli_prepare($connection, "SELECT a.id, a.status, a.received_at, a.qty, ec.id AS center_id, ec.barangay AS center_barangay
              FROM evac_assistance a
              INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
              WHERE a.id = ? LIMIT 1");
mysqli_stmt_bind_param($LedgerStmt, "i", $V_id);
mysqli_stmt_execute($LedgerStmt);
$donation = mysqli_fetch_assoc(mysqli_stmt_get_result($LedgerStmt));

$redirect = "Location: ../../public/center-needs.php?id=";
$redirect .= ($V_center_id > 0 ? (string)$V_center_id : (string)($donation['center_id'] ?? ''));
$redirect .= "&";

if (!$donation || $donation['status'] !== 'Delivered' || $donation['received_at'] !== null) {
    header($redirect . "denied=1");
    exit;
}

$brgy_id = (int)$actorRow['barangay_id'];
$brgyStmt = mysqli_prepare($connection, "SELECT name FROM barangays WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($brgyStmt, "i", $brgy_id);
mysqli_stmt_execute($brgyStmt);
$brgyRow = mysqli_fetch_assoc(mysqli_stmt_get_result($brgyStmt));
if (!$brgyRow || $donation['center_barangay'] !== $brgyRow['name']) {
    header($redirect . "denied=1");
    exit;
}

// The count actually checked in at the center: 1 .. the donor's declared qty.
$qty_received = $_POST['qty_received'] ?? null;
if ($qty_received === null || $qty_received === '' || filter_var($qty_received, FILTER_VALIDATE_INT) === false) {
    header($redirect . "invalid_qty=1");
    exit;
}
$qty_received = (int)$qty_received;
$V_declared = (int)($donation['qty'] ?? 0);
if ($qty_received < 1 || $qty_received > $V_declared) {
    header($redirect . "invalid_qty=1");
    exit;
}

$Update = "UPDATE evac_assistance
           SET received_at = COALESCE(received_at, NOW()),
               confirmed_by_user_id = ?,
               qty_received = ?
           WHERE id = ? AND received_at IS NULL AND status = 'Delivered'";
$stmt = mysqli_prepare($connection, $Update);
mysqli_stmt_bind_param($stmt, "iii", $V_user_id, $qty_received, $V_id);

if (mysqli_stmt_execute($stmt) && mysqli_stmt_affected_rows($stmt) === 1) {
    header($redirect . "received=1");
    exit;
}

header($redirect . "denied=1");
exit;
?>