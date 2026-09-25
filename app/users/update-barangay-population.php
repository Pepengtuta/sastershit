<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
require_once __DIR__ . "/../../config/db_connection.php";
require_once __DIR__ . "/../includes/functions.php";

function redirect_population($V_param, $V_msg, $V_status = 302) {
    http_response_code($V_status);
    header("Location: ../../public/manage-users.php?" . $V_param . "=" . urlencode($V_msg));
    exit;
}

// Sane upper bound for a single barangay population.
define('POPULATION_MAX', 5000000);

$V_role = $_SESSION['role'] ?? '';
$V_is_superadmin = ($V_role === 'superadmin');
$V_my_barangay = (int)($_SESSION['barangay_id'] ?? 0);

// Target barangay: superadmin chooses via dropdown; barangay admins use their own.
$V_target_barangay = $V_is_superadmin ? (int)($_POST['N_barangay_id'] ?? 0) : $V_my_barangay;

if ($V_target_barangay <= 0) {
    redirect_population('perr', 'No barangay selected.', 400);
}

// Permission check:
// - Superadmin can update any barangay.
// - Barangay Captain/Secretary can update only their own barangay.
if (!$V_is_superadmin) {
    $V_can_manage = (int)($_SESSION['can_manage_users'] ?? 0);
    if (!$V_can_manage || $V_my_barangay <= 0 || $V_target_barangay !== $V_my_barangay) {
        redirect_population('perr', 'You are not authorized to update this barangay population.', 403);
    }
}

// ---- Backend (authoritative) population validation ----
// Never trust client-side validation. Reject anything that is not a clean,
// non-negative integer within the sane bound BEFORE writing to the column.
$V_raw = trim((string)($_POST['N_population'] ?? ''));

if ($V_raw === '') {
    redirect_population('perr', 'Population is required.', 400);
}
if (!preg_match('/^\d+$/', $V_raw)) {
    redirect_population('perr', 'Population must be a whole number — no commas, letters, or symbols.', 400);
}

$V_population = (int)$V_raw;

if ($V_population > POPULATION_MAX) {
    redirect_population('perr', 'Population is too large (max ' . number_format(POPULATION_MAX) . ').', 400);
}

// Verify the target barangay actually exists.
$V_check = mysqli_prepare($connection, "SELECT id FROM barangays WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($V_check, "i", $V_target_barangay);
mysqli_stmt_execute($V_check);
$V_check_result = mysqli_stmt_get_result($V_check);
if (!mysqli_fetch_assoc($V_check_result)) {
    redirect_population('perr', 'Selected barangay does not exist.', 400);
}

$V_update = "UPDATE barangays SET population = ? WHERE id = ?";
$V_stmt = mysqli_prepare($connection, $V_update);
mysqli_stmt_bind_param($V_stmt, "ii", $V_population, $V_target_barangay);
if (!mysqli_stmt_execute($V_stmt)) {
    redirect_population('perr', 'Failed to update population.', 500);
}

// Refresh the logged-in user's session value so the UI and auto-fill reflect the
// new population immediately without a re-login (when they updated their own barangay).
if (isset($_SESSION['barangay_id']) && (int)$_SESSION['barangay_id'] === $V_target_barangay) {
    $_SESSION['population'] = $V_population;
}

redirect_population('p_ok', 'Population updated successfully.');
