<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";

$V_username = trim($_POST['username'] ?? '');
$V_password = trim($_POST['password'] ?? '');

if ($V_username == '' || $V_password == '') {
    header("Location: ../../public/login.php?error=empty");
    exit;
}

$GetUser = "SELECT users.*, barangays.name AS barangay_name, barangays.municipality AS municipality, barangays.population AS population
            FROM users
            LEFT JOIN barangays ON users.barangay_id = barangays.id
            WHERE users.username = ?
            LIMIT 1";

$stmt = mysqli_prepare($connection, $GetUser);
mysqli_stmt_bind_param($stmt, "s", $V_username);
mysqli_stmt_execute($stmt);
$UserResult = mysqli_stmt_get_result($stmt);
$UserRow = mysqli_fetch_assoc($UserResult);

if (!$UserRow) {
    header("Location: ../../public/login.php?error=invalid");
    exit;
}

// FIX: removed the plain-text password fallback. Only bcrypt-verified passwords are accepted.
$V_password_ok = password_verify($V_password, $UserRow['password']);

if (!$V_password_ok) {
    header("Location: ../../public/login.php?error=invalid");
    exit;
}

// Deactivated accounts can authenticate but must not be allowed in.
if (($UserRow['status'] ?? 'Active') !== 'Active') {
    header("Location: ../../public/login.php?error=inactive");
    exit;
}

// FIX: regenerate the session ID on login to prevent session fixation.
session_regenerate_id(true);

$_SESSION['user_id'] = $UserRow['id'];
$_SESSION['name'] = $UserRow['name'];
$_SESSION['username'] = $UserRow['username'];
$_SESSION['role'] = $UserRow['role'];
$_SESSION['barangay_id'] = $UserRow['barangay_id'];
$_SESSION['barangay_name'] = $UserRow['barangay_name'];
$_SESSION['municipality'] = $UserRow['municipality'] ?? 'Kalibo';
$_SESSION['sub_role'] = $UserRow['sub_role'] ?? '';
$_SESSION['can_manage_users'] = (int)($UserRow['can_manage_users'] ?? 0);
$_SESSION['population'] = (int)($UserRow['population'] ?? 0);

// PHO accounts (PHO Admin + PDRRMO) default their municipality filter to Ibajay
// on every fresh login. Users can still switch to All/Kalibo during the session;
// the Ibajay default returns on the next login.
if (($_SESSION['role'] ?? '') === 'pho' && !isset($_SESSION['filter_municipality'])) {
    $_SESSION['filter_municipality'] = 'Ibajay';
}

header("Location: ../../public/dashboard.php");
exit;
?>
