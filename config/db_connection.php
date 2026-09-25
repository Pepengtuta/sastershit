<?php
// Loads the single DEBUG_MODE switch + error settings + fail_message().
require_once __DIR__ . "/app_config.php";

$connection = mysqli_connect("localhost", "root", "", "capstone");

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
