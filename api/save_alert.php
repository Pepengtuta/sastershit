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

function send_response($success, $message, $data = []) {
    echo json_encode([
        "success" => $success,
        "message" => $message,
        "data" => $data
    ]);
    exit;
}

function table_exists($connection, $table) {
    $table = mysqli_real_escape_string($connection, $table);
    $result = mysqli_query($connection, "SHOW TABLES LIKE '$table'");
    return $result && mysqli_num_rows($result) > 0;
}

function column_exists($connection, $table, $column) {
    $table = mysqli_real_escape_string($connection, $table);
    $column = mysqli_real_escape_string($connection, $column);
    $result = mysqli_query($connection, "SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $result && mysqli_num_rows($result) > 0;
}

function ensure_alert_schema($connection) {
    // These are safe local demo migrations. They make alert targeting reliable.
    if (!column_exists($connection, 'alerts', 'alert_type')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN alert_type VARCHAR(100) NULL AFTER title");
    }
    if (!column_exists($connection, 'alerts', 'severity')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN severity VARCHAR(50) NULL DEFAULT 'Low' AFTER alert_type");
    }
    if (!column_exists($connection, 'alerts', 'instructions')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN instructions TEXT NULL AFTER message");
    }
    if (!column_exists($connection, 'alerts', 'status')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'Active' AFTER instructions");
    }
    if (!column_exists($connection, 'alerts', 'start_datetime')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN start_datetime DATETIME NULL AFTER status");
    }
    if (!column_exists($connection, 'alerts', 'end_datetime')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN end_datetime DATETIME NULL AFTER start_datetime");
    }
    if (!column_exists($connection, 'alerts', 'target_type')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN target_type VARCHAR(30) NOT NULL DEFAULT 'all' AFTER end_datetime");
    }
    if (!column_exists($connection, 'alerts', 'created_by')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN created_by INT NULL AFTER target_type");
    }
    if (!column_exists($connection, 'alerts', 'created_at')) {
        mysqli_query($connection, "ALTER TABLE alerts ADD COLUMN created_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP");
    }

    mysqli_query($connection, "
        CREATE TABLE IF NOT EXISTS alert_barangays (
            id INT AUTO_INCREMENT PRIMARY KEY,
            alert_id INT NOT NULL,
            barangay_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_alert_barangay (alert_id, barangay_id)
        )
    ");

    mysqli_query($connection, "
        CREATE TABLE IF NOT EXISTS alert_reads (
            id INT AUTO_INCREMENT PRIMARY KEY,
            alert_id INT NOT NULL,
            user_id INT NOT NULL,
            barangay_id INT NOT NULL,
            read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_alert_read_user (alert_id, user_id)
        )
    ");
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_response(false, "Invalid request method. Use POST.");
}

// ensure_alert_schema() removed: the schema is now managed by config/migration.sql

$input = json_decode(file_get_contents("php://input"), true);
if (!$input) {
    send_response(false, "Invalid JSON input.");
}

$created_by = (int)($input['created_by'] ?? 0);
$title = trim($input['title'] ?? '');
$alert_type = trim($input['alert_type'] ?? 'Other');
$severity = trim($input['severity'] ?? 'Low');
$message = trim($input['message'] ?? '');
$instructions = trim($input['instructions'] ?? '');
$start_datetime = trim($input['start_datetime'] ?? date('Y-m-d H:i:s'));
$end_datetime = trim($input['end_datetime'] ?? date('Y-m-d H:i:s', strtotime('+3 days')));
$target_type = strtolower(trim($input['target_type'] ?? 'all'));
$barangay_ids = $input['barangay_ids'] ?? [];

if ($created_by <= 0) send_response(false, "Created by is required.");
if ($title === '') send_response(false, "Alert title is required.");
if ($message === '') send_response(false, "Alert message is required.");

// Role enforcement: only an Active PCF or PHO account may publish alerts.
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $created_by);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active' || !in_array($actorRow['role'], ['pcf', 'pho'], true)) {
    send_response(false, "You are not authorized to publish alerts.");
}
// Read-only observers (mayors + Governor) cannot publish alerts.
if ($actorRow['role'] === 'pcf' && in_array($actorRow['sub_role'] ?? '', ['mayor_kalibo', 'mayor_ibajay'], true)
        || ($actorRow['role'] === 'pho' && ($actorRow['sub_role'] ?? '') === 'governor')) {
    send_response(false, "You are not authorized to publish alerts.");
}

if (!is_array($barangay_ids)) {
    $barangay_ids = [];
}

$barangay_ids = array_values(array_unique(array_filter(array_map('intval', $barangay_ids), function($id) {
    return $id > 0;
})));

// MDR / Mayor sub-roles may only target barangays in their own municipality.
// Derived from the DB sub_role (never trusted from client params).
$actor_sub_role = strtolower(trim($actorRow['sub_role'] ?? ''));
$alert_muni = null;
if ($actorRow['role'] === 'pcf') {
    if (in_array($actor_sub_role, ['mdr_kalibo', 'mayor_kalibo'], true)) $alert_muni = 'Kalibo';
    elseif (in_array($actor_sub_role, ['mdr_ibajay', 'mayor_ibajay'], true)) $alert_muni = 'Ibajay';
}
if ($alert_muni !== null && count($barangay_ids) > 0) {
    $scopeStmt = mysqli_prepare($connection, "SELECT id FROM barangays WHERE municipality = ? AND status = 'Active'");
    mysqli_stmt_bind_param($scopeStmt, "s", $alert_muni);
    mysqli_stmt_execute($scopeStmt);
    $scopeResult = mysqli_stmt_get_result($scopeStmt);
    $allowed = [];
    while ($scopeRow = mysqli_fetch_assoc($scopeResult)) $allowed[] = (int)$scopeRow['id'];
    mysqli_stmt_close($scopeStmt);
    $foreign = array_values(array_diff($barangay_ids, $allowed));
    if (count($foreign) > 0) {
        send_response(false, "You may only target barangays in $alert_muni.");
    }
}

// If the Flutter side sends barangay_ids, treat it as a selected-barangay alert
// even if target_type was accidentally sent as "all".
if (count($barangay_ids) > 0) {
    $target_type = 'selected';
} elseif ($target_type === 'selected') {
    send_response(false, "Select at least one barangay or choose All Barangays.");
} else {
    $target_type = 'all';
}

$query = "
    INSERT INTO alerts (
        title,
        alert_type,
        severity,
        message,
        instructions,
        status,
        start_datetime,
        end_datetime,
        target_type,
        created_by,
        created_at
    )
    VALUES (?, ?, ?, ?, ?, 'Active', ?, ?, ?, ?, NOW())
";

$stmt = mysqli_prepare($connection, $query);
if (!$stmt) send_response(false, "Failed to prepare alert insert: ");

mysqli_stmt_bind_param(
    $stmt,
    "ssssssssi",
    $title,
    $alert_type,
    $severity,
    $message,
    $instructions,
    $start_datetime,
    $end_datetime,
    $target_type,
    $created_by
);

if (!mysqli_stmt_execute($stmt)) {
    send_response(false, "Failed to save alert: ");
}

$alert_id = mysqli_insert_id($connection);

if ($target_type === 'selected') {
    $link = mysqli_prepare($connection, "INSERT IGNORE INTO alert_barangays (alert_id, barangay_id) VALUES (?, ?)");
    if (!$link) send_response(false, "Alert was saved, but targets could not be prepared: ");

    foreach ($barangay_ids as $barangay_id) {
        $barangay_id = (int)$barangay_id;
        if ($barangay_id > 0) {
            mysqli_stmt_bind_param($link, "ii", $alert_id, $barangay_id);
            mysqli_stmt_execute($link);
        }
    }
}

send_response(true, "Alert created successfully.", [
    "alert_id" => (int)$alert_id,
    "target_type" => $target_type,
    "barangay_ids" => array_values($barangay_ids),
    "created_by" => $created_by
]);
?>
