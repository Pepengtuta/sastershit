<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
require_once "user_audit.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }

define('POPULATION_MAX', 5000000);

$input = json_decode(file_get_contents("php://input"), true) ?: [];
$actor = verify_actor($connection, $input['acting_user_id'] ?? 0);
if (!$actor) send_response(false, "You are not authorized to update population.");

// superadmin may pick any barangay; barangay captain/secretary only their own.
$is_superadmin = (strtolower($actor['role'] ?? '') === 'superadmin');
$my_barangay = (int)($actor['barangay_id'] ?? 0);

if ($is_superadmin) {
    $target_barangay = (int)($input['barangay_id'] ?? 0);
} else {
    if (!in_array($actor['sub_role'] ?? '', ['captain', 'secretary'], true)) {
        send_response(false, "You are not authorized to update population.");
    }
    $target_barangay = $my_barangay;
}

if ($target_barangay <= 0) {
    send_response(false, "No barangay selected.");
}

// Validation: non-negative whole number within the sane bound.
$raw = trim((string)($input['population'] ?? ''));
if ($raw === '') send_response(false, "Population is required.");
if (!preg_match('/^\d+$/', $raw)) {
    send_response(false, "Population must be a whole number — no commas, letters, or symbols.");
}
$population = (int)$raw;
if ($population > POPULATION_MAX) {
    send_response(false, "Population is too large (max " . number_format(POPULATION_MAX) . ").");
}

// Verify the target barangay exists.
$check = mysqli_prepare($connection, "SELECT id FROM barangays WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($check, "i", $target_barangay);
mysqli_stmt_execute($check);
if (!mysqli_fetch_assoc(mysqli_stmt_get_result($check))) {
    send_response(false, "Selected barangay does not exist.");
}

$update = mysqli_prepare($connection, "UPDATE barangays SET population = ? WHERE id = ?");
mysqli_stmt_bind_param($update, "ii", $population, $target_barangay);
if (!mysqli_stmt_execute($update)) {
    send_response(false, "Failed to update population.");
}

session_start();
if (isset($_SESSION['barangay_id']) && (int)$_SESSION['barangay_id'] === $target_barangay) {
    $_SESSION['population'] = $population;
}

send_response(true, "Population updated successfully.", ["barangay_id" => $target_barangay, "population" => $population]);
?>