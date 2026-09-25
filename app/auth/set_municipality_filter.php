<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once "../auth/check_session.php";

$role = $_SESSION['role'] ?? '';
$sub_role = $_SESSION['sub_role'] ?? '';
$municipality = trim($_POST['municipality'] ?? 'all');

// Only admin roles can use the municipality filter.
if (!in_array($role, ['pcf', 'pho', 'superadmin'])) {
    header("Location: ../../public/dashboard.php");
    exit;
}

// MDR sub-roles are forced to their municipality — ignore user input.
require_once "../includes/functions.php";
$forced = mdr_municipality($role, $sub_role);
if ($forced === null) {
    $forced = mayor_municipality($role, $sub_role);
}
if ($forced !== null) {
    $_SESSION['filter_municipality'] = $forced;
} elseif ($municipality === '' || $municipality === 'all') {
    unset($_SESSION['filter_municipality']);
} else {
    $_SESSION['filter_municipality'] = $municipality;
}

// Redirect back to the referring page or dashboard.
$referer = $_SERVER['HTTP_REFERER'] ?? '../../public/dashboard.php';
header("Location: " . $referer);
exit;
?>
