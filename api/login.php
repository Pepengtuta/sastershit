<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
if ($_SERVER["REQUEST_METHOD"] !== "POST") send_response(false, "Invalid request method. Use POST.");
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");
$username = trim($input["username"] ?? "");
$password = trim($input["password"] ?? "");
if ($username === "" || $password === "") send_response(false, "Username and password are required.");
$query = "SELECT users.id, users.name, users.username, users.password, users.role, users.sub_role, users.can_manage_users, users.barangay_id, users.status, barangays.name AS barangay_name, barangays.municipality AS municipality, barangays.population AS population FROM users LEFT JOIN barangays ON users.barangay_id = barangays.id WHERE users.username = ? LIMIT 1";
$stmt = mysqli_prepare($connection, $query);
// FIX: generic error message (was leaking mysqli_error()).
if (!$stmt) send_response(false, "Login is unavailable right now. Please try again.");
mysqli_stmt_bind_param($stmt, "s", $username);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$user = mysqli_fetch_assoc($result);
if (!$user) send_response(false, "Invalid username or password.");
if (isset($user["status"]) && strtolower($user["status"]) !== "active") send_response(false, "This account is inactive.");
// FIX: removed the plain-text password fallback. Only bcrypt-verified passwords are accepted.
$password_ok = password_verify($password, $user["password"]);
if (!$password_ok) send_response(false, "Invalid username or password.");
$role = strtolower($user["role"]);
if ($role === "pfc") $role = "pcf";
send_response(true, "Login successful.", ["id"=>(int)$user["id"], "name"=>$user["name"], "username"=>$user["username"], "role"=>$role, "sub_role"=>$user["sub_role"], "can_manage_users"=>(bool)$user["can_manage_users"], "barangay_id"=>$user["barangay_id"] !== null ? (int)$user["barangay_id"] : null, "barangay_name"=>$user["barangay_name"], "municipality"=>$user["municipality"], "population"=>(int)($user["population"] ?? 0)]);
?>
