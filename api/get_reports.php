<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
function column_exists($connection, $table, $column) { $t=mysqli_real_escape_string($connection,$table); $c=mysqli_real_escape_string($connection,$column); $r=mysqli_query($connection,"SHOW COLUMNS FROM `$t` LIKE '$c'"); return $r && mysqli_num_rows($r)>0; }
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");
$role = strtolower(trim($input['role'] ?? ''));
$barangay_id = $input['barangay_id'] ?? null;
$user_id = $input['user_id'] ?? null;
$municipality = trim($input['municipality'] ?? '');
$month = (isset($input['month']) && $input['month'] !== '') ? (int)$input['month'] : null;
$year  = (isset($input['year'])  && $input['year']  !== '') ? (int)$input['year']  : null;
$disaster_type = trim($input['disaster_type'] ?? '');
$governor_scope = !empty($input['governor_scope']);
$mayor_scope = !empty($input['mayor_scope']);

// MDR sub-role municipality override: look up actor's sub_role from DB and force scope.
$pcf_sub_role = '';
if ($role === 'pcf' && $user_id !== null && $user_id !== '') {
    $actor_stmt = mysqli_prepare($connection, "SELECT sub_role FROM users WHERE id = ? AND role = 'pcf' LIMIT 1");
    if ($actor_stmt) {
        $uid = (int)$user_id;
        mysqli_stmt_bind_param($actor_stmt, "i", $uid);
        mysqli_stmt_execute($actor_stmt);
        $actor_row = mysqli_fetch_assoc(mysqli_stmt_get_result($actor_stmt));
        if ($actor_row) {
            $pcf_sub_role = strtolower(trim($actor_row['sub_role'] ?? ''));
            if ($pcf_sub_role === 'mdr_kalibo' || $pcf_sub_role === 'mayor_kalibo') $municipality = 'Kalibo';
            elseif ($pcf_sub_role === 'mdr_ibajay' || $pcf_sub_role === 'mayor_ibajay') $municipality = 'Ibajay';
        }
    }
}

// Governor drill-down scope: province-wide, all non-dismissed statuses. Honored
// only when the actor's sub_role is actually 'governor' (verified from DB,
// mirroring the pcf sub_role override above). Read-only: never grants writes.
$governor_scope_active = false;
if ($governor_scope && $role === 'pho' && $user_id !== null && $user_id !== '') {
    $actor_stmt = mysqli_prepare($connection, "SELECT sub_role FROM users WHERE id = ? AND role = 'pho' LIMIT 1");
    if ($actor_stmt) {
        $uid = (int)$user_id;
        mysqli_stmt_bind_param($actor_stmt, "i", $uid);
        mysqli_stmt_execute($actor_stmt);
        $actor_row = mysqli_fetch_assoc(mysqli_stmt_get_result($actor_stmt));
        if ($actor_row && strtolower(trim($actor_row['sub_role'] ?? '')) === 'governor') {
            $governor_scope_active = true;
        }
    }
}
if ($governor_scope_active && ($month === null || $year === null)) {
    send_response(false, "Month and year are required for Governor scope.");
}

// Mayor evidence drill-down scope: all non-dismissed reports in the Mayor's own
// municipality (barangay-level included). Honored only when the actor's pcf
// sub_role is actually a Mayor (DB-verified above). Read-only: never grants writes.
$mayor_scope_active = $mayor_scope && $role === 'pcf'
    && ($pcf_sub_role === 'mayor_kalibo' || $pcf_sub_role === 'mayor_ibajay');
if ($mayor_scope_active && ($month === null || $year === null)) {
    send_response(false, "Month and year are required for Mayor scope.");
}

$where = ""; $params = []; $types = "";
if ($role === 'barangay' || $role === 'brgy') {
    if ($barangay_id === null || $barangay_id === '') send_response(false, "Barangay ID is required.");
    $where = "WHERE incident_reports.barangay_id = ?"; $params[] = (int)$barangay_id; $types .= "i";
    if ($user_id !== null && $user_id !== '') {
        $where .= " AND incident_reports.user_id = ?"; $params[] = (int)$user_id; $types .= "i";
    }
}
if ($role === 'pho') {
    if ($governor_scope_active) {
        // Governor evidence drill-down: province-wide, every status except
        // dismissed, windowed to the evidence card's month/year below.
        $where = "WHERE LOWER(COALESCE(incident_reports.status, '')) NOT LIKE '%dismiss%'";
    } else {
        $where = "WHERE (incident_reports.referred_to_pho = 1 OR incident_reports.status IN ('Referred to PHO','Under PHO Review','Forwarded to PHO'))";
    }
}
if ($role === 'pcf') {
    if ($mayor_scope_active) {
        // Mayor evidence drill-down: all non-dismissed municipal reports in the
        // month/year window (municipality is forced by the sub_role override).
        $where = "WHERE LOWER(COALESCE(incident_reports.status, '')) NOT LIKE '%dismiss%'";
    } else {
        $where = "WHERE incident_reports.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')";
    }
}
if ($mayor_scope_active && $barangay_id !== null && $barangay_id !== '') {
    // Per-barangay drill within the Mayor's own town (municipality filter still
    // applies below, so a foreign barangay_id can never leak outside the town).
    $where .= " AND incident_reports.barangay_id = ?";
    $params[] = (int)$barangay_id;
    $types .= "i";
}
// Governor/Mayor drill-down window + disaster-type filter (matches the evidence card).
$evidence_scope_active = $governor_scope_active || $mayor_scope_active;
if ($evidence_scope_active) {
    $evidence_date_expr = column_exists($connection, 'incident_reports', 'incident_datetime')
        ? "COALESCE(incident_reports.incident_datetime, incident_reports.created_at)"
        : "incident_reports.created_at";
    $where .= " AND MONTH($evidence_date_expr) = ? AND YEAR($evidence_date_expr) = ?";
    $params[] = $month; $types .= "i";
    $params[] = $year;  $types .= "i";
}
if ($evidence_scope_active && $disaster_type !== '') {
    // 'Others' mirrors functions.php governor_province_evidence() so the chip's
    // aggregate and its drill-down list always match.
    if (strtolower($disaster_type) === 'others') {
        $where .= " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT IN ('typhoon','flood','storm surge','earthquake','landslide','fire','disease outbreak')"
            . " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT LIKE '%drought%'"
            . " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT LIKE '%el nino%'"
            . " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT LIKE '%el ni%o%'"
            . " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT LIKE '%accident%'"
            . " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT LIKE '%mass casualty%'"
            . " AND LOWER(COALESCE(incident_reports.disaster_type, '')) NOT IN ('', 'other', 'others')";
    } else {
        $where .= " AND incident_reports.disaster_type = ?";
        $params[] = $disaster_type; $types .= "s";
    }
}
// Municipality filter for admin roles (pcf, pho, superadmin)
$admin_roles = ['pcf', 'pho', 'superadmin'];
if (in_array($role, $admin_roles) && $municipality !== '') {
    $prefix = ($where === '') ? 'WHERE' : 'AND';
    $where .= " $prefix barangays.municipality = ?";
    $params[] = $municipality;
    $types .= "s";
}
$incident_datetime_select = column_exists($connection, 'incident_reports', 'incident_datetime') ? "incident_reports.incident_datetime," : "NULL AS incident_datetime,";
$assistance_select = column_exists($connection, 'incident_reports', 'assistance_needed') ? "incident_reports.assistance_needed," : "NULL AS assistance_needed,";
$evac_hh_select = column_exists($connection, 'incident_reports', 'evac_households') ? "incident_reports.evac_households, incident_reports.evac_adults, incident_reports.evac_children, incident_reports.evac_members," : "0 AS evac_households, 0 AS evac_adults, 0 AS evac_children, 0 AS evac_members,";
$road_select = column_exists($connection, 'incident_reports', 'road_status') ? "incident_reports.road_status, incident_reports.road_blockage_causes, incident_reports.road_location," : "NULL AS road_status, NULL AS road_blockage_causes, NULL AS road_location,";
$query = "SELECT incident_reports.id, incident_reports.user_id, incident_reports.barangay_id, barangays.name AS barangay_name, barangays.municipality AS municipality, users.name AS creator_name, incident_reports.disaster_type, incident_reports.evacuation_needed, incident_reports.evacuation_center_id, evacuation_centers.center_name AS evacuation_center_name, $incident_datetime_select $assistance_select $evac_hh_select $road_select incident_reports.description, incident_reports.exact_location, incident_reports.latitude, incident_reports.longitude, incident_reports.affected_people, incident_reports.injured, incident_reports.dead, incident_reports.missing, incident_reports.status, incident_reports.referred_to_pho, incident_reports.created_at FROM incident_reports LEFT JOIN barangays ON incident_reports.barangay_id=barangays.id LEFT JOIN evacuation_centers ON incident_reports.evacuation_center_id=evacuation_centers.id LEFT JOIN users ON incident_reports.user_id=users.id $where ORDER BY incident_reports.created_at DESC";
$stmt = mysqli_prepare($connection, $query);
// FIX: generic error message (was leaking mysqli_error()).
if (!$stmt) send_response(false, "Could not load reports. Please try again.");
if (!empty($params)) mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$data = [];
while ($row = mysqli_fetch_assoc($result)) {
    $data[] = [
        "id"=>(int)$row["id"], "user_id"=>(int)$row["user_id"], "barangay_id"=>(int)$row["barangay_id"], "barangay_name"=>$row["barangay_name"], "municipality"=>$row["municipality"], "creator_name"=>$row["creator_name"],
        "disaster_type"=>$row["disaster_type"], "evacuation_needed"=>$row["evacuation_needed"], "evacuation_center_id"=>$row["evacuation_center_id"] !== null ? (int)$row["evacuation_center_id"] : null, "evacuation_center_name"=>$row["evacuation_center_name"],
        "evac_households"=>(int)($row["evac_households"] ?? 0), "evac_adults"=>(int)($row["evac_adults"] ?? 0), "evac_children"=>(int)($row["evac_children"] ?? 0), "evac_members"=>(int)($row["evac_members"] ?? 0),
        "incident_datetime"=>$row["incident_datetime"], "assistance_needed"=>$row["assistance_needed"], "description"=>$row["description"], "exact_location"=>$row["exact_location"], "latitude"=>$row["latitude"], "longitude"=>$row["longitude"],
        "road_status"=>$row["road_status"], "road_blockage_causes"=>$row["road_blockage_causes"], "road_location"=>$row["road_location"],
        "affected_people"=>(int)$row["affected_people"], "injured"=>(int)$row["injured"], "dead"=>(int)$row["dead"], "missing"=>(int)$row["missing"], "status"=>$row["status"], "referred_to_pho"=>(int)$row["referred_to_pho"], "created_at"=>$row["created_at"]
    ];
}
send_response(true, "Reports loaded successfully.", $data);
?>
