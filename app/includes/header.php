<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

include_once __DIR__ . "/functions.php";
include_once __DIR__ . "/csrf.php";

if (!isset($V_page_title)) {
    $V_page_title = "Disaster Reporting System";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo h($V_page_title); ?> | Kalibo Disaster Reporting</title>
    <link rel="stylesheet" href="asset/vendor/bootstrap/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <link rel="stylesheet" href="asset/css/style.css?v=<?php echo @filemtime('asset/css/style.css'); ?>">
</head>
<body>
