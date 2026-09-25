<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
require_once "user_audit.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }

$input = json_decode(file_get_contents("php://input"), true) ?: [];
$search = trim($input['search'] ?? '');
$actor_id = (int)($input['acting_user_id'] ?? 0);

// ── Scope: require a valid actor, then scope users by actor type ──
$actor = verify_actor($connection, $actor_id);
if (!$actor) send_response(false, "You are not authorized to manage users.");

$where = "WHERE 1=1";
$params = [];
$types  = '';

if ($actor['role'] === 'barangay') {
    $where .= " AND users.barangay_id = ?";
    $params[] = (int)$actor['barangay_id'];
    $types  .= 'i';
} elseif ($actor['role'] === 'pcf') {
    $where .= " AND users.role = 'pcf'";
    $actor_sub = strtolower($actor['sub_role'] ?? '');
    if ($actor_sub === 'mdr_kalibo') {
        $where .= " AND users.sub_role = ?";
        $params[] = 'mdr_kalibo';
        $types  .= 's';
    } elseif ($actor_sub === 'mdr_ibajay') {
        $where .= " AND users.sub_role = ?";
        $params[] = 'mdr_ibajay';
        $types  .= 's';
    }
    // mdr_admin: no additional filter, sees all pcf users
} elseif ($actor['role'] === 'pho') {
    // PHO Admin: sees PDRRMO and Governor accounts only.
    $where .= " AND users.role = 'pho' AND users.sub_role IN ('pdrrmo', 'governor')";
}

if ($search !== '') {
    $where .= " AND (users.name LIKE ? OR users.username LIKE ? OR users.role LIKE ? OR users.sub_role LIKE ? OR barangays.name LIKE ?)";
    $like = "%$search%";
    array_push($params, $like, $like, $like, $like, $like);
    $types .= 'sssss';
}

$q = "SELECT users.id, users.name, users.username, users.role, users.sub_role,
             users.can_manage_users, users.status, users.barangay_id,
             barangays.name AS barangay_name, users.created_at
      FROM users
      LEFT JOIN barangays ON users.barangay_id = barangays.id
      $where
      ORDER BY users.sub_role ASC, users.name ASC";

$stmt = mysqli_prepare($connection, $q);
if (!$stmt) send_response(false, "Could not load users. Please try again.");
if (!empty($params)) mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);
$res = mysqli_stmt_get_result($stmt);

$data = [];
while ($row = mysqli_fetch_assoc($res)) $data[] = $row;

send_response(true, "Users loaded successfully.", $data);
?>
