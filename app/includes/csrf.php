<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

function csrf_token() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function csrf_field() {
    return '<input type="hidden" name="csrf_token" value="'
        . htmlspecialchars(csrf_token(), ENT_QUOTES, 'UTF-8') . '">';
}

function csrf_verify() {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        return;
    }
    $token = $_POST['csrf_token'] ?? '';
    if (!is_string($token) || $token === ''
        || empty($_SESSION['csrf_token'])
        || !hash_equals($_SESSION['csrf_token'], $token)) {
        http_response_code(419);
        die('Invalid or expired form session. Please go back, refresh the page, and submit the form again.');
    }
}
?>
