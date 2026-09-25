<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";
include "../includes/functions.php";

if (!isset($_SESSION['user_id']) || !can_manage_hotlines($_SESSION['role'])) {
    header("Location: ../../public/hotlines.php?denied=1");
    exit;
}

$V_ID = (int)($_GET['id'] ?? 0);
$V_scope = trim($_POST['N_hotline_scope'] ?? 'Municipal');
$V_office_name = trim($_POST['N_office_name'] ?? '');
$V_municipality = trim($_POST['N_municipality'] ?? '');
$V_barangay_id = (int)($_POST['N_barangay_id'] ?? 0);
$V_category = trim($_POST['N_category'] ?? '');
$V_telephone_numbers = trim($_POST['N_telephone_numbers'] ?? '');
$V_cellphone_numbers = trim($_POST['N_cellphone_numbers'] ?? '');
$V_hotline_number = trim($_POST['N_hotline_number'] ?? '');
$V_remarks = trim($_POST['N_remarks'] ?? '');
$V_status = $_POST['N_status'] ?? 'Active';

if ($V_scope != 'Barangay' && $V_scope != 'Municipal') {
    $V_scope = 'Municipal';
}

if ($V_status != 'Active' && $V_status != 'Inactive') {
    $V_status = 'Active';
}

if ($V_scope == 'Barangay') {
    // Store the selected barangay's real municipality (not hardcoded).
    $V_brgy_muni = null;
    $BrgyMuniStmt = mysqli_prepare($connection, "SELECT municipality FROM barangays WHERE id = ? LIMIT 1");
    if ($BrgyMuniStmt) {
        mysqli_stmt_bind_param($BrgyMuniStmt, "i", $V_barangay_id);
        mysqli_stmt_execute($BrgyMuniStmt);
        $BrgyMuniResult = mysqli_stmt_get_result($BrgyMuniStmt);
        if ($BrgyMuniRow = mysqli_fetch_assoc($BrgyMuniResult)) {
            $V_brgy_muni = $BrgyMuniRow['municipality'];
        }
    }
    $V_municipality = $V_brgy_muni ?: 'Kalibo';

    if ($V_ID <= 0 || $V_office_name == '' || $V_category == '' || $V_barangay_id <= 0) {
        header("Location: ../../public/edit-hotline.php?id=$V_ID&error=1");
        exit;
    }
} else {
    $V_barangay_id = null;

    if ($V_ID <= 0 || $V_office_name == '' || $V_category == '' || $V_municipality == '') {
        header("Location: ../../public/edit-hotline.php?id=$V_ID&error=1");
        exit;
    }
}

$UpdateQuery = "UPDATE emergency_hotlines SET
                hotline_scope = ?,
                barangay_id = ?,
                office_name = ?,
                municipality = ?,
                category = ?,
                telephone_numbers = ?,
                cellphone_numbers = ?,
                hotline_number = ?,
                remarks = ?,
                status = ?
                WHERE id = ?";

$stmt = mysqli_prepare($connection, $UpdateQuery);
mysqli_stmt_bind_param($stmt, "sissssssssi", $V_scope, $V_barangay_id, $V_office_name, $V_municipality, $V_category, $V_telephone_numbers, $V_cellphone_numbers, $V_hotline_number, $V_remarks, $V_status, $V_ID);

if (mysqli_stmt_execute($stmt)) {
    header("Location: ../../public/hotlines.php?updated=1");
    exit;
}

echo fail_message("Something went wrong. Please try again.", "DB error: " . mysqli_error($connection));
?>
