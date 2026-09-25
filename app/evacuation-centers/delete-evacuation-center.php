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

// Deletes must be POST (a click on a plain link should never delete data).
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: ../../public/evacuation-centers.php");
    exit;
}

$V_ID = (int)($_POST['id'] ?? 0);

// Barangay chairmen may only delete centers inside their own barangay.
if (($_SESSION['role'] ?? '') === 'barangay') {
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM evacuation_centers WHERE id = ? AND barangay = ? LIMIT 1");
    $V_actor_barangay_name = $_SESSION['barangay_name'] ?? '';
    mysqli_stmt_bind_param($scopeStmt, "is", $V_ID, $V_actor_barangay_name);
    mysqli_stmt_execute($scopeStmt);
    if (!mysqli_fetch_assoc(mysqli_stmt_get_result($scopeStmt))) {
        header("Location: ../../public/evacuation-centers.php?denied=1");
        exit;
    }
}

// MDR sub-roles may only delete centers in their own municipality.
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

if ($V_ID > 0) {
    $DeleteQuery = "DELETE FROM evacuation_centers WHERE id = ?";
    $stmt = mysqli_prepare($connection, $DeleteQuery);
    mysqli_stmt_bind_param($stmt, "i", $V_ID);
    mysqli_stmt_execute($stmt);
}

header("Location: ../../public/evacuation-centers.php?deleted=1");
exit;
?>
