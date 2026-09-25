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

function public_file_url($file_path) {
    $file_path = trim((string)$file_path);
    if ($file_path === '') return '';

    // Already a full URL — return as-is.
    if (preg_match('/^https?:\/\//i', $file_path)) {
        return $file_path;
    }

    $file_path = str_replace('\\', '/', $file_path);
    $file_path = preg_replace('#^\.\.\/#', '', $file_path);
    $file_path = ltrim($file_path, '/');

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    if (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') $scheme = 'https';
    $host   = $_SERVER['HTTP_HOST'] ?? 'localhost';

    // Build the project root from SCRIPT_NAME:
    // e.g. /sastergpt/api/get_report_attachments.php  → /sastergpt
    // e.g. /vsp/sastergpt/api/...                     → /vsp/sastergpt
    $script = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
    // Go up two levels from /project/api/script.php → /project
    $base_path = rtrim(dirname(dirname($script)), '/');

    // Evidence files are stored as: uploads/incidents/report_X/file.jpg
    // OR already prefixed with public/uploads/...
    if (stripos($file_path, 'public/') === 0) {
        return $scheme . '://' . $host . $base_path . '/' . $file_path;
    }
    return $scheme . '://' . $host . $base_path . '/public/' . $file_path;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_response(false, "Invalid request method. Use POST.");
}

$input = json_decode(file_get_contents("php://input"), true);
if (!$input) {
    send_response(false, "Invalid JSON input.");
}

$report_id = (int)($input['report_id'] ?? 0);
if ($report_id <= 0) {
    send_response(false, "Report ID is required.");
}

if (!table_exists($connection, 'incident_attachments')) {
    send_response(true, "No evidence table found.", []);
}

$incident_column = column_exists($connection, 'incident_attachments', 'incident_report_id')
    ? 'incident_report_id'
    : (column_exists($connection, 'incident_attachments', 'incident_id') ? 'incident_id' : null);

if ($incident_column === null) {
    send_response(false, "No incident reference column found in incident_attachments.");
}

$file_name_select = column_exists($connection, 'incident_attachments', 'file_name') ? 'file_name' : 'file_path';
$file_path_select = column_exists($connection, 'incident_attachments', 'file_path') ? 'file_path' : null;
$file_type_select = column_exists($connection, 'incident_attachments', 'file_type') ? 'file_type' : "'file'";
$file_size_select = column_exists($connection, 'incident_attachments', 'file_size') ? 'file_size' : 'NULL';
$created_select = column_exists($connection, 'incident_attachments', 'created_at')
    ? 'created_at'
    : (column_exists($connection, 'incident_attachments', 'uploaded_at') ? 'uploaded_at' : 'NULL');

if ($file_path_select === null) {
    send_response(false, "No file_path column found in incident_attachments.");
}

$query = "
    SELECT
        id,
        `$file_name_select` AS file_name,
        `$file_path_select` AS file_path,
        $file_type_select AS file_type,
        $file_size_select AS file_size,
        $created_select AS created_at
    FROM incident_attachments
    WHERE `$incident_column` = ?
    ORDER BY id DESC
";

$stmt = mysqli_prepare($connection, $query);
if (!$stmt) {
    send_response(false, fail_message("Failed to prepare evidence query.", mysqli_error($connection)));
}

mysqli_stmt_bind_param($stmt, "i", $report_id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

$files = [];
while ($row = mysqli_fetch_assoc($result)) {
    $files[] = [
        "id" => (int)$row["id"],
        "file_name" => $row["file_name"],
        "file_path" => $row["file_path"],
        "file_url" => public_file_url($row["file_path"]),
        "file_type" => $row["file_type"],
        "file_size" => $row["file_size"] !== null ? (int)$row["file_size"] : null,
        "created_at" => $row["created_at"]
    ];
}

send_response(true, "Evidence loaded successfully.", $files);
?>
