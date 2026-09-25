<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
function col_exists($conn, $table, $col) { $t=mysqli_real_escape_string($conn,$table); $c=mysqli_real_escape_string($conn,$col); $r=mysqli_query($conn,"SHOW COLUMNS FROM `$t` LIKE '$c'"); return $r && mysqli_num_rows($r)>0; }
$input = json_decode(file_get_contents("php://input"), true) ?: [];
$role = strtolower(trim($input['role'] ?? ''));
$barangay_id = $input['barangay_id'] ?? null;
$user_id = $input['user_id'] ?? null;
$municipality_filter = trim($input['municipality'] ?? '');

// MDR sub-role municipality override: look up actor's sub_role from DB and force scope.
if ($role === 'pcf' && $user_id !== null && $user_id !== '') {
    $actor_stmt = mysqli_prepare($connection, "SELECT sub_role FROM users WHERE id = ? AND role = 'pcf' LIMIT 1");
    if ($actor_stmt) {
        $uid = (int)$user_id;
        mysqli_stmt_bind_param($actor_stmt, "i", $uid);
        mysqli_stmt_execute($actor_stmt);
        $actor_row = mysqli_fetch_assoc(mysqli_stmt_get_result($actor_stmt));
        if ($actor_row) {
            $actor_sub = strtolower(trim($actor_row['sub_role'] ?? ''));
            if ($actor_sub === 'mdr_kalibo') $municipality_filter = 'Kalibo';
            elseif ($actor_sub === 'mdr_ibajay') $municipality_filter = 'Ibajay';
        }
    }
}

$barangay_lat = col_exists($connection, 'barangays', 'latitude') ? 'latitude' : (col_exists($connection, 'barangays', 'lat') ? 'lat' : null);
$barangay_lng = col_exists($connection, 'barangays', 'longitude') ? 'longitude' : (col_exists($connection, 'barangays', 'lng') ? 'lng' : null);

// Build WHERE for barangay halls: optionally filter by municipality
$barangay_where_parts = [];
if (col_exists($connection, 'barangays', 'status')) {
    $barangay_where_parts[] = "status='Active'";
}
if ($municipality_filter !== '') {
    $barangay_where_parts[] = "municipality = '" . mysqli_real_escape_string($connection, $municipality_filter) . "'";
}
$barangay_status_clause = count($barangay_where_parts) > 0 ? "WHERE " . implode(" AND ", $barangay_where_parts) : "";

$barangay_halls = [];
if ($barangay_lat && $barangay_lng) {
    $q = "SELECT id, name, municipality, `$barangay_lat` AS latitude, `$barangay_lng` AS longitude FROM barangays $barangay_status_clause ORDER BY name ASC";
    $res = mysqli_query($connection, $q);
    if (!$res) send_response(false, fail_message("Failed to load barangay halls.", mysqli_error($connection)));
    while ($row = mysqli_fetch_assoc($res)) {
        if ($row['latitude'] !== null && $row['longitude'] !== null && $row['latitude'] !== '' && $row['longitude'] !== '') {
            $barangay_halls[] = [
                'id'=>(int)$row['id'], 'name'=>$row['name'],
                'municipality'=>$row['municipality'],
                'latitude'=>(float)$row['latitude'], 'longitude'=>(float)$row['longitude'],
            ];
        }
    }
}

$ec_lat = col_exists($connection, 'evacuation_centers', 'latitude') ? 'latitude' : null;
$ec_lng = col_exists($connection, 'evacuation_centers', 'longitude') ? 'longitude' : null;
$evacuation_centers = [];
if ($ec_lat && $ec_lng) {
    // Filter evac centers by municipality directly
    if ($municipality_filter !== '') {
        $muni_escaped = mysqli_real_escape_string($connection, $municipality_filter);
        $q = "SELECT ec.id, ec.barangay, ec.center_name, ec.center_type, ec.status,
                     ec.`$ec_lat` AS latitude, ec.`$ec_lng` AS longitude
              FROM evacuation_centers ec
              WHERE ec.municipality = '$muni_escaped'
                AND (ec.`$ec_lat` IS NOT NULL AND ec.`$ec_lng` IS NOT NULL AND ec.`$ec_lat` <> '' AND ec.`$ec_lng` <> '')
              ORDER BY ec.barangay ASC, ec.center_name ASC";
    } else {
        $q = "SELECT id, barangay, center_name, center_type, status, `$ec_lat` AS latitude, `$ec_lng` AS longitude FROM evacuation_centers WHERE (`$ec_lat` IS NOT NULL AND `$ec_lng` IS NOT NULL AND `$ec_lat` <> '' AND `$ec_lng` <> '') ORDER BY barangay ASC, center_name ASC";
    }
    $res = mysqli_query($connection, $q);
    if (!$res) send_response(false, fail_message("Failed to load evacuation centers.", mysqli_error($connection)));
    while ($row = mysqli_fetch_assoc($res)) {
        $evacuation_centers[] = [
            'id'=>(int)$row['id'], 'barangay'=>$row['barangay'], 'center_name'=>$row['center_name'],
            'center_type'=>$row['center_type'], 'status'=>$row['status'],
            'latitude'=>(float)$row['latitude'], 'longitude'=>(float)$row['longitude'],
        ];
    }
}

// Primary care facilities — shown to every role/scope.
$pcf_facilities = [];
$pcf_q = "SELECT id, name, municipality, latitude, longitude
          FROM pcf_facilities
          WHERE latitude IS NOT NULL AND latitude <> ''
            AND longitude IS NOT NULL AND longitude <> ''
          ORDER BY municipality ASC, name ASC";
$pcf_res = mysqli_query($connection, $pcf_q);
if (!$pcf_res) send_response(false, fail_message("Failed to load primary care facilities.", mysqli_error($connection)));
while ($row = mysqli_fetch_assoc($pcf_res)) {
    $pcf_facilities[] = [
        'id'=>(int)$row['id'],
        'name'=>$row['name'],
        'municipality'=>$row['municipality'],
        'latitude'=>(float)$row['latitude'],
        'longitude'=>(float)$row['longitude'],
    ];
}

$where = "WHERE incident_reports.latitude IS NOT NULL AND incident_reports.longitude IS NOT NULL AND incident_reports.latitude <> '' AND incident_reports.longitude <> ''";
$params = []; $types = '';
if ($role === 'barangay' || $role === 'brgy') {
    if ($barangay_id !== null && $barangay_id !== '') { $where .= " AND incident_reports.barangay_id = ?"; $params[] = (int)$barangay_id; $types .= 'i'; }
}
if ($role === 'pho') {
    $where .= " AND (incident_reports.referred_to_pho = 1 OR incident_reports.status IN ('Referred to PHO','Under PHO Review','Forwarded to PHO','Forwarded to PCF','Under MDR Review','Verified','Responding'))";
}
if ($role === 'pcf') {
    $where .= " AND incident_reports.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')";
}
if ($municipality_filter !== '') {
    $where .= " AND barangays.municipality = '" . mysqli_real_escape_string($connection, $municipality_filter) . "'";
}
$q = "SELECT incident_reports.id, incident_reports.barangay_id, barangays.name AS barangay_name, barangays.municipality AS municipality, incident_reports.disaster_type, incident_reports.status, incident_reports.referred_to_pho, incident_reports.latitude, incident_reports.longitude, incident_reports.created_at FROM incident_reports LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id $where ORDER BY incident_reports.created_at DESC";
$stmt = mysqli_prepare($connection, $q);
if (!$stmt) send_response(false, fail_message("Failed to prepare incident map query.", mysqli_error($connection)));
if (!empty($params)) mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);
$res = mysqli_stmt_get_result($stmt);
$incidents = [];
while ($row = mysqli_fetch_assoc($res)) {
    $incidents[] = [
        'id'=>(int)$row['id'], 'barangay_id'=>(int)$row['barangay_id'], 'barangay_name'=>$row['barangay_name'],
        'municipality'=>$row['municipality'],
        'disaster_type'=>$row['disaster_type'], 'status'=>$row['status'],
        'referred_to_pho'=>(int)$row['referred_to_pho'],
        'latitude'=>(float)$row['latitude'], 'longitude'=>(float)$row['longitude'], 'created_at'=>$row['created_at'],
    ];
}

send_response(true, "Map data loaded successfully.", [
    'barangay_halls'=>$barangay_halls,
    'evacuation_centers'=>$evacuation_centers,
    'pcf_facilities'=>$pcf_facilities,
    'incidents'=>$incidents,
]);
?>
