<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once "../config/db_connection.php";
require_once "../app/includes/functions.php";

function send_response($success, $message, $data = []) {
    echo json_encode([
        "success" => $success,
        "message" => $message,
        "data" => $data
    ]);
    exit;
}

function column_exists($connection, $table, $column) {
    $table = mysqli_real_escape_string($connection, $table);
    $column = mysqli_real_escape_string($connection, $column);
    $result = mysqli_query($connection, "SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $result && mysqli_num_rows($result) > 0;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_response(false, "Invalid request method. Use POST.");
}

$input = json_decode(file_get_contents("php://input"), true);
if (!$input) {
    send_response(false, "Invalid JSON input.");
}

$report_id = (int)($input['report_id'] ?? 0);
$user_id = (int)($input['user_id'] ?? 0);
$barangay_id = (int)($input['barangay_id'] ?? 0);
$disaster_type = trim($input['disaster_type'] ?? '');
$evacuation_needed = trim($input['evacuation_needed'] ?? 'No') === 'Yes' ? 'Yes' : 'No';
$evacuation_center_id = $input['evacuation_center_id'] ?? null;
$incident_datetime = trim($input['incident_datetime'] ?? '');
$description = trim($input['description'] ?? '');
$latitude = $input['latitude'] ?? null;
$longitude = $input['longitude'] ?? null;
$exact_location = trim($input['exact_location'] ?? '');
$assistance_needed = trim($input['assistance_needed'] ?? '');
$affected_people = (int)($input['affected_people'] ?? 0);
$injured = (int)($input['injured'] ?? 0);
$dead = (int)($input['dead'] ?? 0);
$missing = (int)($input['missing'] ?? 0);
$evac_households = max(0, (int)($input['evac_households'] ?? 0));
$evac_adults = max(0, (int)($input['evac_adults'] ?? 0));
$evac_children = max(0, (int)($input['evac_children'] ?? 0));
$evac_members = max(0, (int)($input['evac_members'] ?? 0));

// Road / Bridge Accessibility
$road_status = trim($input['road_status'] ?? 'Passable');
$road_status = in_array($road_status, ['Passable', 'Partially Passable', 'Obstructed'], true) ? $road_status : 'Passable';
$road_blockage_causes = trim($input['road_blockage_causes'] ?? '');
$road_location = trim($input['road_location'] ?? '');

// Server-side hardening: reject invalid numbers instead of silently coercing to 0.
foreach (['affected_people' => 'Affected people', 'injured' => 'Injured', 'dead' => 'Dead', 'missing' => 'Missing', 'evac_households' => 'Households', 'evac_adults' => 'Adults', 'evac_children' => 'Children', 'evac_members' => 'Family members'] as $field => $label) {
    if (isset($input[$field]) && (!is_numeric($input[$field]) || (int)$input[$field] < 0)) {
        send_response(false, $label . " must be a valid non-negative number.");
    }
}
// Latitude/Longitude are optional; when provided they must be numeric and in range.
if ($latitude !== null && $latitude !== '') {
    if (!is_numeric($latitude)) send_response(false, "Latitude must be a valid number.");
    if ((float)$latitude < -90 || (float)$latitude > 90) send_response(false, "Latitude must be between -90 and 90.");
}
if ($longitude !== null && $longitude !== '') {
    if (!is_numeric($longitude)) send_response(false, "Longitude must be a valid number.");
    if ((float)$longitude < -180 || (float)$longitude > 180) send_response(false, "Longitude must be between -180 and 180.");
}

if ($report_id <= 0) send_response(false, "Report ID is required.");
if ($user_id <= 0) send_response(false, "User ID is required.");
if ($barangay_id <= 0) send_response(false, "Barangay ID is required.");

// Role enforcement: only an Active barangay captain may edit incident reports.
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active' || $actorRow['role'] !== 'barangay') {
    send_response(false, "You are not authorized to edit incident reports.");
}
$actorSubRole = $actorRow['sub_role'] ?? '';
// Ownership is anchored to the actor's registered barangay (defense in depth:
// ignore any client-supplied barangay_id, so a user can never touch another
// barangay's reports even by tampering with the request).
$actorBarangayId = (int)($actorRow['barangay_id'] ?? 0);
if ($actorBarangayId <= 0) {
    send_response(false, "Your account is missing a barangay assignment.");
}
$barangay_id = $actorBarangayId;

if ($disaster_type === '') send_response(false, "Disaster type is required.");
if ($description === '') send_response(false, "Description is required.");
if ($incident_datetime === '') $incident_datetime = date('Y-m-d H:i:s');

// Confirm the report belongs to this barangay and is still editable (Pending).
$ownStmt = mysqli_prepare($connection, "SELECT status, user_id FROM incident_reports WHERE id = ? AND barangay_id = ? LIMIT 1");
mysqli_stmt_bind_param($ownStmt, "ii", $report_id, $barangay_id);
mysqli_stmt_execute($ownStmt);
$ownRow = mysqli_fetch_assoc(mysqli_stmt_get_result($ownStmt));
if (!$ownRow) {
    send_response(false, "Report not found for this barangay.");
}
if ($ownRow['status'] !== 'Pending') {
    send_response(false, "This report can no longer be edited because it is already being processed.");
}
// Only the report's own reporter or the Barangay Chairman may edit it.
$isReporter = ((int)($ownRow['user_id'] ?? 0) === $user_id);
if ($actorSubRole !== 'captain' && !$isReporter) {
    send_response(false, "Only the reporter or the Barangay Chairman can edit this incident report.");
}

// Evacuation center reference must be empty or a valid number (mirrors the web handler).
if ($evacuation_center_id !== null && $evacuation_center_id !== '' && !is_numeric($evacuation_center_id)) {
    send_response(false, "Evacuation center ID must be a number.");
}

if ($evacuation_needed === 'No' || $evacuation_center_id === null || $evacuation_center_id === '') {
    $evacuation_center_id = null;
} else {
    $evacuation_center_id = (int)$evacuation_center_id;
}

// Soft flag: does the saved pin fall outside the reporting barangay's boundary?
$pin_outside = incident_pin_outside_flag($connection, $barangay_id, '', $latitude, $longitude);
$has_pin_outside = column_exists($connection, 'incident_reports', 'pin_outside_area');
if ($pin_outside) {
    error_log("pin check: API update of report #{$report_id} for barangay_id={$barangay_id} saved with pin OUTSIDE boundary (lat={$latitude}, lng={$longitude})");
}

$has_incident_datetime = column_exists($connection, 'incident_reports', 'incident_datetime');
$has_assistance_needed = column_exists($connection, 'incident_reports', 'assistance_needed');
$has_latitude = column_exists($connection, 'incident_reports', 'latitude');
$has_longitude = column_exists($connection, 'incident_reports', 'longitude');
$has_exact_location = column_exists($connection, 'incident_reports', 'exact_location');
$has_road_fields = column_exists($connection, 'incident_reports', 'road_status')
    && column_exists($connection, 'incident_reports', 'road_blockage_causes')
    && column_exists($connection, 'incident_reports', 'road_location');

// Build the UPDATE dynamically so it matches whatever columns exist.
$assignments = [];
$types = '';
$values = [];

function add_set(&$assignments, &$types, &$values, $column, $type, $value) {
    $assignments[] = "`$column` = ?";
    $types .= $type;
    $values[] = $value;
}

add_set($assignments, $types, $values, 'disaster_type', 's', $disaster_type);
add_set($assignments, $types, $values, 'evacuation_needed', 's', $evacuation_needed);
add_set($assignments, $types, $values, 'evacuation_center_id', 'i', $evacuation_center_id);

$has_evac_households = column_exists($connection, 'incident_reports', 'evac_households');
if ($has_evac_households) {
    add_set($assignments, $types, $values, 'evac_households', 'i', $evac_households);
    add_set($assignments, $types, $values, 'evac_adults', 'i', $evac_adults);
    add_set($assignments, $types, $values, 'evac_children', 'i', $evac_children);
    add_set($assignments, $types, $values, 'evac_members', 'i', $evac_members);
}

if ($has_incident_datetime) {
    add_set($assignments, $types, $values, 'incident_datetime', 's', $incident_datetime);
}

add_set($assignments, $types, $values, 'description', 's', $description);

if ($has_latitude) {
    add_set($assignments, $types, $values, 'latitude', 's', $latitude);
}

if ($has_longitude) {
    add_set($assignments, $types, $values, 'longitude', 's', $longitude);
}

if ($has_exact_location) {
    add_set($assignments, $types, $values, 'exact_location', 's', $exact_location);
}

if ($has_road_fields) {
    $road_causes_to_save = ($road_status === 'Passable') ? '' : $road_blockage_causes;
    add_set($assignments, $types, $values, 'road_status', 's', $road_status);
    add_set($assignments, $types, $values, 'road_blockage_causes', 's', $road_causes_to_save);
    add_set($assignments, $types, $values, 'road_location', 's', $road_location);
}

if ($has_assistance_needed) {
    add_set($assignments, $types, $values, 'assistance_needed', 's', $assistance_needed);
}

add_set($assignments, $types, $values, 'affected_people', 'i', $affected_people);
add_set($assignments, $types, $values, 'injured', 'i', $injured);
add_set($assignments, $types, $values, 'dead', 'i', $dead);
add_set($assignments, $types, $values, 'missing', 'i', $missing);

if ($has_pin_outside) {
    add_set($assignments, $types, $values, 'pin_outside_area', 'i', $pin_outside);
}

$query = "UPDATE incident_reports SET " . implode(', ', $assignments) . " WHERE id = ? AND barangay_id = ? AND status = 'Pending'";
$types .= "ii";
$values[] = $report_id;
$values[] = $barangay_id;

$stmt = mysqli_prepare($connection, $query);
if (!$stmt) {
    send_response(false, "Failed to prepare incident update.");
}

mysqli_stmt_bind_param($stmt, $types, ...$values);

if (!mysqli_stmt_execute($stmt)) {
    send_response(false, "Failed to update incident report.");
}

if (mysqli_query($connection, "SHOW TABLES LIKE 'incident_status_logs'")) {
    $log_stmt = mysqli_prepare($connection, "INSERT INTO incident_status_logs (incident_report_id, old_status, new_status, remarks, updated_by, created_at) VALUES (?, 'Pending', 'Pending', 'Report edited by barangay from mobile app.', ?, NOW())");
    if ($log_stmt) {
        mysqli_stmt_bind_param($log_stmt, "ii", $report_id, $user_id);
        @mysqli_stmt_execute($log_stmt);
    }
}

send_response(true, "Incident report updated successfully.", [
    "report_id" => $report_id,
    "status" => "Pending",
    "pin_outside_area" => (int)$pin_outside
]);
?>
