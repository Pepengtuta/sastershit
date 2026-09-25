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

$V_role     = $_SESSION['role'];
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_id       = (int)($_POST['assistance_id'] ?? 0);
$V_action   = $_POST['action'] ?? '';

$LedgerStmt = mysqli_prepare($connection, "SELECT a.*, ec.municipality AS ec_muni FROM evac_assistance a INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id WHERE a.id = ? LIMIT 1");
mysqli_stmt_bind_param($LedgerStmt, "i", $V_id);
mysqli_stmt_execute($LedgerStmt);
$donation = mysqli_fetch_assoc(mysqli_stmt_get_result($LedgerStmt));

if (!$donation) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

// MDR sub-roles may only advance statuses inside their own municipality.
if (($V_muni = mdr_municipality($V_role, $V_sub_role)) && $donation['ec_muni'] !== $V_muni) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

$V_user_id = (int)($_SESSION['user_id'] ?? 0);

// Only the donor, a provincial office (PHO admin / PDRRMO - not the Governor),
// or superadmin DB owner may advance the status.
$V_prov_override = ($V_role === 'superadmin') || ($V_role === 'pho' && strtolower(trim((string)$V_sub_role)) !== 'governor');
if ((int)$donation['donor_user_id'] !== $V_user_id && !$V_prov_override) {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

if ($V_action === 'send') {
    if ($donation['status'] !== 'Pledged') {
        header("Location: ../../public/assistance.php?denied=1");
        exit;
    }
    // sent_at is set once (NULL-safe) so a re-submit can't rewrite history.
    $Update = "UPDATE evac_assistance SET status = 'Sent', sent_at = COALESCE(sent_at, NOW()) WHERE id = ?";
} elseif ($V_action === 'deliver') {
    if ($donation['status'] === 'Delivered') {
        header("Location: ../../public/assistance.php?denied=1");
        exit;
    }
    $Update = "UPDATE evac_assistance
               SET status = 'Delivered',
                   sent_at = COALESCE(sent_at, NOW()),
                   delivered_at = COALESCE(delivered_at, NOW())
               WHERE id = ?";
} else {
    header("Location: ../../public/assistance.php?denied=1");
    exit;
}

$stmt = mysqli_prepare($connection, $Update);
mysqli_stmt_bind_param($stmt, "i", $V_id);

if (mysqli_stmt_execute($stmt)) {
    header("Location: ../../public/assistance.php?updated=1");
    exit;
}

echo fail_message("Something went wrong updating the status.", "DB error: " . mysqli_error($connection));
?>