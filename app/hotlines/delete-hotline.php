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

// Deletes must be POST (a click on a plain link should never delete data).
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: ../../public/hotlines.php");
    exit;
}

$V_ID = (int)($_POST['id'] ?? 0);

if ($V_ID > 0) {
    $DeleteQuery = "DELETE FROM emergency_hotlines WHERE id = ?";
    $stmt = mysqli_prepare($connection, $DeleteQuery);
    mysqli_stmt_bind_param($stmt, "i", $V_ID);
    mysqli_stmt_execute($stmt);
}

header("Location: ../../public/hotlines.php?deleted=1");
exit;
?>
