<?php
// Loads the single DEBUG_MODE switch + error settings + fail_message().
require_once __DIR__ . "/app_config.php";
require_once __DIR__ . "/env.php";

env_load(dirname(__DIR__));

$db_host = env('DB_HOST', 'localhost');
$db_user = env('DB_USER', 'root');
$db_pass = env('DB_PASS', '');
$db_name = env('DB_NAME', 'capstone');
$db_port = (int) env('DB_PORT', 3306);

$connection = mysqli_connect($db_host, $db_user, $db_pass, $db_name, $db_port);

if (!$connection) {
    http_response_code(500);
    $message = fail_message(
        "Service temporarily unavailable.",
        "DB connection failed: " . mysqli_connect_error()
    );
    if (function_exists('send_response')) {
        send_response(false, $message);
    }
    die($message);
}

mysqli_set_charset($connection, "utf8mb4");
?>
