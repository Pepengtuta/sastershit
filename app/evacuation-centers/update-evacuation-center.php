<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";
include "../includes/functions.php";

if (!isset($_SESSION['user_id']) || !can_manage_evacuation_centers($_SESSION['role'], $_SESSION['sub_role'] ?? '')) {
    header("Location: ../../public/evacuation-centers.php?denied=1");
    exit;
}

$V_ID = (int)($_GET['id'] ?? 0);
$V_barangay_id = (int)($_POST['N_barangay_id'] ?? 0);

// Barangay chairmen may only update centers inside their own barangay.
if (($_SESSION['role'] ?? '') === 'barangay') {
    if ((int)($_SESSION['barangay_id'] ?? 0) !== $V_barangay_id) {
        header("Location: ../../public/evacuation-centers.php?denied=1");
        exit;
    }
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM evacuation_centers WHERE id = ? AND barangay = ? LIMIT 1");
    $V_actor_barangay_name = $_SESSION['barangay_name'] ?? '';
    mysqli_stmt_bind_param($scopeStmt, "is", $V_ID, $V_actor_barangay_name);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        header("Location: ../../public/evacuation-centers.php?denied=1");
        exit;
    }
}

// MDR sub-roles may only update centers in their own municipality.
$V_ec_muni = mdr_municipality($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '');
if ($V_ec_muni) {
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM evacuation_centers WHERE id = ? AND municipality = ? LIMIT 1");
    mysqli_stmt_bind_param($scopeStmt, "is", $V_ID, $V_ec_muni);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        header("Location: ../../public/evacuation-centers.php?denied=1");
        exit;
    }
}
$V_center_name = trim($_POST['N_center_name'] ?? '');
$V_center_type = trim($_POST['N_center_type'] ?? '');
$V_capacity = (int)($_POST['N_capacity'] ?? 0);
$V_current_evacuees = (int)($_POST['N_current_evacuees'] ?? 0);
$V_contact_person = trim($_POST['N_contact_person'] ?? '');
$V_contact_number = trim($_POST['N_contact_number'] ?? '');
$V_status = $_POST['N_status'] ?? 'Available';

// Server-side hardening: reject invalid numbers instead of silently coercing to 0.
foreach (['N_capacity' => 'Capacity', 'N_current_evacuees' => 'Current Evacuees'] as $V_field => $V_label) {
    if (isset($_POST[$V_field]) && (!is_numeric($_POST[$V_field]) || (float)$_POST[$V_field] < 0)) {
        header("Location: ../../public/edit-evacuation-center.php?id=" . $V_ID . "&error=number");
        exit;
    }
}
// Contact number must contain at least one digit when non-empty.
if ($V_contact_number !== '' && !preg_match('/[0-9]/', $V_contact_number)) {
    header("Location: ../../public/edit-evacuation-center.php?id=" . $V_ID . "&error=number");
    exit;
}

// Resolve barangay name and municipality from barangay_id
$V_barangay = '';
$V_municipality = '';
if ($V_barangay_id > 0) {
    $brgy_stmt = mysqli_prepare($connection, "SELECT name, municipality FROM barangays WHERE id = ? LIMIT 1");
    if ($brgy_stmt) {
        mysqli_stmt_bind_param($brgy_stmt, "i", $V_barangay_id);
        mysqli_stmt_execute($brgy_stmt);
        $brgy_result = mysqli_stmt_get_result($brgy_stmt);
        if ($brgy_row = mysqli_fetch_assoc($brgy_result)) {
            $V_barangay = $brgy_row['name'];
            $V_municipality = $brgy_row['municipality'];
        }
    }
}

$V_allowed_status = ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];

if (!in_array($V_status, $V_allowed_status)) {
    $V_status = 'Available';
}

if ($V_capacity < 0) $V_capacity = 0;
if ($V_current_evacuees < 0) $V_current_evacuees = 0;

if ($V_ID <= 0 || $V_barangay == '' || $V_center_name == '') {
    header("Location: ../../public/evacuation-centers.php?error=1");
    exit;
}

$UpdateQuery = "UPDATE evacuation_centers SET
                barangay = ?,
                municipality = ?,
                center_name = ?,
                center_type = ?,
                capacity = ?,
                current_evacuees = ?,
                status = ?,
                contact_person = ?,
                contact_number = ?
                WHERE id = ?";

$stmt = mysqli_prepare($connection, $UpdateQuery);
mysqli_stmt_bind_param($stmt, "ssssiisssi", $V_barangay, $V_municipality, $V_center_name, $V_center_type, $V_capacity, $V_current_evacuees, $V_status, $V_contact_person, $V_contact_number, $V_ID);

if (mysqli_stmt_execute($stmt)) {
    header("Location: ../../public/evacuation-centers.php?updated=1");
    exit;
}

echo fail_message("Something went wrong. Please try again.", "DB error: " . mysqli_error($connection));
?>
