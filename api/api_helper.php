<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");

if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") {
    http_response_code(200);
    exit;
}

require_once __DIR__ . "/../config/db_connection.php";

function db() {
    global $connection;
    if (!isset($connection) || !$connection) {
        send_response(false, "Database connection not found.");
    }
    return $connection;
}

function send_response($success, $message, $data = []) {
    echo json_encode([
        "success" => $success,
        "message" => $message,
        "data" => $data
    ]);
    exit;
}

function read_json_input() {
    $raw_input = file_get_contents("php://input");
    $input = json_decode($raw_input, true);
    return is_array($input) ? $input : [];
}

// Read-only observer sub-roles: town mayors (PCF) and the Aklan Governor (PHO).
function is_readonly_role_api($role, $sub_role = '') {
    $role = strtolower((string)$role);
    $sub_role = strtolower((string)$sub_role);
    return ($role === 'pcf' && in_array($sub_role, ['mayor_kalibo', 'mayor_ibajay'], true))
        || ($role === 'pho' && $sub_role === 'governor');
}

function require_post() {
    if ($_SERVER["REQUEST_METHOD"] !== "POST") {
        send_response(false, "Invalid request method. Use POST.");
    }
}

function table_exists($table) {
    $table = mysqli_real_escape_string(db(), $table);
    $result = mysqli_query(db(), "SHOW TABLES LIKE '$table'");
    return $result && mysqli_num_rows($result) > 0;
}

function column_exists($table, $column) {
    $table = mysqli_real_escape_string(db(), $table);
    $column = mysqli_real_escape_string(db(), $column);
    $result = mysqli_query(db(), "SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $result && mysqli_num_rows($result) > 0;
}
?>
