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
    echo json_encode(["success" => $success, "message" => $message, "data" => $data]);
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

$input = json_decode(file_get_contents("php://input"), true) ?: [];
$role = strtolower(trim($input['role'] ?? ''));
$barangay_id = $input['barangay_id'] ?? null;
$user_id = (int)($input['user_id'] ?? 0);
$search = trim($input['search'] ?? '');

$has_alert_type = column_exists($connection, 'alerts', 'alert_type');
$has_severity = column_exists($connection, 'alerts', 'severity');
$has_instructions = column_exists($connection, 'alerts', 'instructions');
$has_status = column_exists($connection, 'alerts', 'status');
$has_start = column_exists($connection, 'alerts', 'start_datetime');
$has_end = column_exists($connection, 'alerts', 'end_datetime');
$has_created_by = column_exists($connection, 'alerts', 'created_by');
$has_target_type = column_exists($connection, 'alerts', 'target_type');
$has_alert_barangays = table_exists($connection, 'alert_barangays');
$has_alert_reads = table_exists($connection, 'alert_reads');

$selects = [
    "alerts.id",
    "alerts.title",
    ($has_alert_type ? "alerts.alert_type" : "'Alert' AS alert_type"),
    ($has_severity ? "alerts.severity" : "'Alert' AS severity"),
    "alerts.message",
    ($has_instructions ? "alerts.instructions" : "'' AS instructions"),
    ($has_status ? "alerts.status" : "'Active' AS status"),
    ($has_start ? "alerts.start_datetime" : "NULL AS start_datetime"),
    ($has_end ? "alerts.end_datetime" : "NULL AS end_datetime"),
    ($has_created_by ? "alerts.created_by" : "NULL AS created_by"),
    ($has_target_type ? "alerts.target_type" : "'all' AS target_type"),
    "alerts.created_at"
];

$joins = [];
if ($has_created_by) {
    $joins[] = "LEFT JOIN users creator ON alerts.created_by = creator.id";
    $selects[] = "creator.name AS created_by_name";
    $selects[] = "creator.role AS created_by_role";
} else {
    $selects[] = "NULL AS created_by_name";
    $selects[] = "NULL AS created_by_role";
}

if ($has_alert_reads && $user_id > 0) {
    $joins[] = "LEFT JOIN alert_reads ON alerts.id = alert_reads.alert_id AND alert_reads.user_id = " . (int)$user_id;
    $selects[] = "CASE WHEN alert_reads.id IS NULL THEN 0 ELSE 1 END AS is_read";
} else {
    $selects[] = "0 AS is_read";
}

$where = [];
$params = [];
$types = "";

if ($has_status) {
    $where[] = "alerts.status = 'Active'";
}

if ($role === 'barangay' || $role === 'brgy') {
    if ($barangay_id === null || $barangay_id === '') {
        send_response(false, "Barangay ID is required.");
    }

    if ($has_target_type && $has_alert_barangays) {
        $where[] = "(
            LOWER(COALESCE(alerts.target_type, 'all')) = 'all'
            OR EXISTS (
                SELECT 1
                FROM alert_barangays ab
                WHERE ab.alert_id = alerts.id
                AND ab.barangay_id = ?
            )
        )";
        $params[] = (int)$barangay_id;
        $types .= "i";
    }
}

if ($search !== '') {
    $search_parts = ["alerts.title LIKE ?", "alerts.message LIKE ?"];
    $like = "%$search%";
    $params[] = $like;
    $params[] = $like;
    $types .= "ss";

    if ($has_alert_type) {
        $search_parts[] = "alerts.alert_type LIKE ?";
        $params[] = $like;
        $types .= "s";
    }

    if ($has_instructions) {
        $search_parts[] = "alerts.instructions LIKE ?";
        $params[] = $like;
        $types .= "s";
    }

    $where[] = "(" . implode(" OR ", $search_parts) . ")";
}

$where_sql = count($where) > 0 ? "WHERE " . implode(" AND ", $where) : "";
$query = "SELECT " . implode(', ', $selects) . " FROM alerts " . implode(' ', $joins) . " $where_sql ORDER BY alerts.created_at DESC";

$stmt = mysqli_prepare($connection, $query);
if (!$stmt) send_response(false, fail_message("Failed to prepare alerts query.", mysqli_error($connection)));
if (!empty($params)) mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);

$alerts = [];
while ($row = mysqli_fetch_assoc($result)) {
    $target_type = strtolower($row['target_type'] ?? 'all');
    if ($target_type !== 'selected') $target_type = 'all';
    $target_label = "All Barangays";

    if ($target_type === 'selected' && $has_alert_barangays) {
        $target_query = "
            SELECT barangays.name
            FROM alert_barangays
            INNER JOIN barangays ON alert_barangays.barangay_id = barangays.id
            WHERE alert_barangays.alert_id = " . (int)$row['id'] . "
            ORDER BY barangays.name ASC
        ";
        $target_result = mysqli_query($connection, $target_query);
        $target_names = [];
        if ($target_result) {
            while ($target_row = mysqli_fetch_assoc($target_result)) {
                $target_names[] = $target_row['name'];
            }
        }
        $target_label = count($target_names) > 0 ? implode(', ', $target_names) : 'Selected Barangays';
    }

    $now = time();
    $start_ts = !empty($row['start_datetime']) ? strtotime($row['start_datetime']) : null;
    $end_ts = !empty($row['end_datetime']) ? strtotime($row['end_datetime']) : null;
    $validity_status = 'Active';
    if ($start_ts !== null && $start_ts > $now) $validity_status = 'Upcoming';
    if ($end_ts !== null && $end_ts < $now) $validity_status = 'Expired';

    $created_by_name = $row['created_by_name'] ?? null;
    $created_by_role = strtolower($row['created_by_role'] ?? '');
    if ($created_by_role === 'pfc') $created_by_role = 'pcf';

    $alerts[] = [
        "id" => (int)$row['id'],
        "title" => $row['title'],
        "alert_type" => $row['alert_type'],
        "severity" => $row['severity'],
        "message" => $row['message'],
        "instructions" => $row['instructions'],
        "status" => $row['status'],
        "start_datetime" => $row['start_datetime'],
        "end_datetime" => $row['end_datetime'],
        "validity_status" => $validity_status,
        "created_by" => $row['created_by'],
        "created_by_name" => $created_by_name,
        "created_by_role" => $created_by_role,
        "target_type" => $target_type,
        "target_label" => $target_label,
        "is_read" => (int)$row['is_read'],
        "created_at" => $row['created_at']
    ];
}

send_response(true, "Alerts loaded successfully.", $alerts);
?>
