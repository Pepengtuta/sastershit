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
require_once "../app/includes/weather_helper.php";
require_once "../app/includes/functions.php";

function send_response($success, $message, $data = []) {
    echo json_encode([
        "success" => $success,
        "message" => $message,
        "data" => $data
    ]);
    exit;
}

function column_exists($connection, $table, $column) {
    $table = mysqli_real_escape_string($connection, $table);
    $column = mysqli_real_escape_string($connection, $column);
    $result = mysqli_query($connection, "SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $result && mysqli_num_rows($result) > 0;
}

function add_condition(&$conditions, &$params, &$types, $condition, $value = null, $type = '') {
    $conditions[] = $condition;
    if ($value !== null) {
        $params[] = $value;
        $types .= $type;
    }
}

function run_count_query($connection, $where_sql, $types, $params, $extra_condition = '') {
    $sql = "
        SELECT COUNT(*) AS total
        FROM incident_reports
        LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id
        WHERE $where_sql $extra_condition
    ";

    $stmt = mysqli_prepare($connection, $sql);
    if (!$stmt) return 0;

    if (!empty($params)) {
        mysqli_stmt_bind_param($stmt, $types, ...$params);
    }

    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);
    $row = mysqli_fetch_assoc($result);

    return (int)($row['total'] ?? 0);
}

function run_ec_count($connection, $role, $barangay_id, $municipality = '') {
    if ($role === 'barangay' || $role === 'brgy') {
        if ($barangay_id === null || $barangay_id === '') return 0;

        $name_stmt = mysqli_prepare($connection, "SELECT name, municipality FROM barangays WHERE id = ? LIMIT 1");
        if (!$name_stmt) return 0;
        $bid = (int)$barangay_id;
        mysqli_stmt_bind_param($name_stmt, 'i', $bid);
        mysqli_stmt_execute($name_stmt);
        $name_result = mysqli_stmt_get_result($name_stmt);
        $name_row = mysqli_fetch_assoc($name_result);
        if (!$name_row) return 0;

        $barangay_name = $name_row['name'];
        $barangay_muni = $name_row['municipality'];
        $stmt = mysqli_prepare($connection, "SELECT COUNT(*) AS total FROM evacuation_centers WHERE barangay = ? AND municipality = ?");
        if (!$stmt) return 0;
        mysqli_stmt_bind_param($stmt, 'ss', $barangay_name, $barangay_muni);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);
        $row = mysqli_fetch_assoc($result);
        return (int)($row['total'] ?? 0);
    }

    // Admin roles: filter by municipality directly
    if ($municipality !== '') {
        $stmt = mysqli_prepare($connection, "SELECT COUNT(*) AS total FROM evacuation_centers WHERE municipality = ?");
        if (!$stmt) return 0;
        mysqli_stmt_bind_param($stmt, 's', $municipality);
        mysqli_stmt_execute($stmt);
        $result = mysqli_stmt_get_result($stmt);
    } else {
        $result = mysqli_query($connection, "SELECT COUNT(*) AS total FROM evacuation_centers");
    }
    if (!$result) return 0;
    $row = mysqli_fetch_assoc($result);
    return (int)($row['total'] ?? 0);
}

if (!function_exists('status_display')) {
    function status_display($status) {
        $map = [
            'Forwarded to PCF' => '→ MNCPL',
            'Referred to PHO'  => '→ PRVCL',
            'Forwarded to PHO' => '→ PRVCL',
            'Under PHO Review' => 'Under Provincial (PDR) Review',
        ];
        return $map[$status] ?? $status;
    }
}

function normalize_disaster_type($value) {
    $raw = trim((string)$value);
    $lower = strtolower($raw);

    if ($raw === '') return 'Others';
    if ($lower === 'typhoon') return 'Typhoon';
    if ($lower === 'flood') return 'Flood';
    if ($lower === 'storm surge') return 'Storm Surge';
    if ($lower === 'earthquake') return 'Earthquake';
    if ($lower === 'landslide') return 'Landslide';
    if ($lower === 'fire') return 'Fire';
    if (str_contains($lower, 'drought') || str_contains($lower, 'el nino') || str_contains($lower, 'el niño') || str_contains($lower, 'el niho')) return 'Drought / El Niño';
    if ($lower === 'disease outbreak') return 'Disease Outbreak';
    if (str_contains($lower, 'accident') || str_contains($lower, 'mass casualty')) return 'Accident / Mass Casualty Incident';
    if ($lower === 'others' || $lower === 'other') return 'Others';

    return 'Others';
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_response(false, "Invalid request method. Use POST.");
}

$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");

$role = strtolower(trim($input['role'] ?? ''));
$barangay_id = $input['barangay_id'] ?? null;
$month = (int)($input['month'] ?? date('n'));
$year = (int)($input['year'] ?? date('Y'));
$sub_role = strtolower(trim($input['sub_role'] ?? ''));
$user_id = $input['user_id'] ?? null;
$municipality = trim($input['municipality'] ?? '');

// MDR + Mayor sub-role municipality override: look up actor's sub_role from DB and force scope.
$db_sub_role = '';
if ($role === 'pcf' && $user_id !== null && $user_id !== '') {
    $actor_stmt = mysqli_prepare($connection, "SELECT sub_role FROM users WHERE id = ? AND role = 'pcf' LIMIT 1");
    if ($actor_stmt) {
        $uid = (int)$user_id;
        mysqli_stmt_bind_param($actor_stmt, "i", $uid);
        mysqli_stmt_execute($actor_stmt);
        $actor_row = mysqli_fetch_assoc(mysqli_stmt_get_result($actor_stmt));
        if ($actor_row) {
            $db_sub_role = strtolower(trim($actor_row['sub_role'] ?? ''));
            if ($db_sub_role === 'mdr_kalibo' || $db_sub_role === 'mayor_kalibo') $municipality = 'Kalibo';
            elseif ($db_sub_role === 'mdr_ibajay' || $db_sub_role === 'mayor_ibajay') $municipality = 'Ibajay';
        }
    }
}

if ($month < 1 || $month > 12) $month = (int)date('n');
if ($year < 2000 || $year > 2100) $year = (int)date('Y');

$has_incident_datetime = column_exists($connection, 'incident_reports', 'incident_datetime');
$has_referred_to_pho = column_exists($connection, 'incident_reports', 'referred_to_pho');
$date_expr = $has_incident_datetime ? "COALESCE(incident_reports.incident_datetime, incident_reports.created_at)" : "incident_reports.created_at";

$conditions = [];
$params = [];
$types = '';

add_condition($conditions, $params, $types, "MONTH($date_expr) = ?", $month, 'i');
add_condition($conditions, $params, $types, "YEAR($date_expr) = ?", $year, 'i');
add_condition($conditions, $params, $types, "LOWER(COALESCE(incident_reports.status, '')) NOT LIKE '%dismiss%'");

$scope_label = 'All Barangays';

if ($role === 'barangay' || $role === 'brgy') {
    if ($barangay_id === null || $barangay_id === '') {
        send_response(false, "Barangay ID is required for barangay dashboard.");
    }

    add_condition($conditions, $params, $types, "incident_reports.barangay_id = ?", (int)$barangay_id, 'i');

    // BHERT (tanod) dashboards are isolated to the reports the BHERT
    // submitted themselves — mirrors the "My Reports" list scoping.
    if ($sub_role === 'tanod' && $user_id !== null && $user_id !== '') {
        add_condition($conditions, $params, $types, "incident_reports.user_id = ?", (int)$user_id, 'i');
    }

    $barangay_stmt = mysqli_prepare($connection, "SELECT name FROM barangays WHERE id = ? LIMIT 1");
    if ($barangay_stmt) {
        $bid = (int)$barangay_id;
        mysqli_stmt_bind_param($barangay_stmt, 'i', $bid);
        mysqli_stmt_execute($barangay_stmt);
        $barangay_result = mysqli_stmt_get_result($barangay_stmt);
        $barangay_row = mysqli_fetch_assoc($barangay_result);
        if ($barangay_row) $scope_label = $barangay_row['name'];
    }
}

if ($role === 'pho') {
    // Governor: province-wide evidence scope (ALL incidents, any referral
    // status) for the read-only decision-support card on the Reports screen.
    $governor_province_wide = ($sub_role === 'governor');
    if (!$governor_province_wide) {
        if ($has_referred_to_pho) {
            add_condition($conditions, $params, $types, "(incident_reports.referred_to_pho = 1 OR incident_reports.status IN ('Referred to PHO', 'Under PHO Review', 'Forwarded to PHO'))");
        } else {
            add_condition($conditions, $params, $types, "incident_reports.status IN ('Referred to PHO', 'Under PHO Review', 'Forwarded to PHO')");
        }
    }
    $scope_label = $governor_province_wide ? 'Province-wide' : 'Provincial Referred Reports';
}

if ($role === 'pcf') {
    $mayor_muni_wide = ($db_sub_role === 'mayor_kalibo' || $db_sub_role === 'mayor_ibajay');
    if (!$mayor_muni_wide) {
        add_condition($conditions, $params, $types, "incident_reports.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')");
    }
    // Mayors widen to every non-dismissed municipal report (barangay-level
    // included); the municipality filter below already scopes them to their town.
    $scope_label = $mayor_muni_wide ? $municipality : 'MDRRMO Forwarded Reports';
}

if ($role === 'superadmin' || $role === 'admin') {
    $scope_label = 'System Overview';
}

// Municipality filter for admin roles (pcf, pho, superadmin) — but never for
// the Governor, whose evidence card is always the whole province.
$admin_roles = ['pcf', 'pho', 'superadmin', 'admin'];
$is_province_wide = ($role === 'pho' && $sub_role === 'governor');
if (!$is_province_wide && in_array($role, $admin_roles) && $municipality !== '') {
    add_condition($conditions, $params, $types,
        "barangays.municipality = ?", $municipality, 's');
    $scope_label = $municipality;
}

$where_sql = implode(' AND ', $conditions);

$total_reports = run_count_query($connection, $where_sql, $types, $params);
$pending = run_count_query($connection, $where_sql, $types, $params, " AND LOWER(COALESCE(incident_reports.status, '')) LIKE '%pending%'");

$pho_condition = " AND incident_reports.status IN ('Referred to PHO', 'Under PHO Review', 'Forwarded to PHO')";
if ($has_referred_to_pho) {
    $pho_condition = " AND (incident_reports.referred_to_pho = 1 OR incident_reports.status IN ('Referred to PHO', 'Under PHO Review', 'Forwarded to PHO'))";
}
$forwarded_to_pho = run_count_query($connection, $where_sql, $types, $params, $pho_condition);
$evacuation_centers = run_ec_count($connection, $role, $barangay_id, $municipality);

// Status breakdown: how many reports sit at each stage this month.
$status_summary = [];
$status_sql = "SELECT incident_reports.status, COUNT(*) AS total
               FROM incident_reports
               LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id
               WHERE $where_sql
               GROUP BY incident_reports.status";
$status_stmt = mysqli_prepare($connection, $status_sql);
if ($status_stmt) {
    if (!empty($params)) mysqli_stmt_bind_param($status_stmt, $types, ...$params);
    mysqli_stmt_execute($status_stmt);
    $status_result = mysqli_stmt_get_result($status_stmt);
    while ($row = mysqli_fetch_assoc($status_result)) {
        $status_summary[] = [
            "label" => status_display($row['status'] ?? 'Unknown'),
            "count" => (int)($row['total'] ?? 0),
        ];
    }
}

// Human impact: total people affected this month.
$impact = ["affected" => 0, "injured" => 0, "dead" => 0, "missing" => 0];
$impact_sql = "SELECT
        COALESCE(SUM(incident_reports.affected_people), 0) AS affected,
        COALESCE(SUM(incident_reports.injured), 0) AS injured,
        COALESCE(SUM(incident_reports.dead), 0) AS dead,
        COALESCE(SUM(incident_reports.missing), 0) AS missing
    FROM incident_reports
    LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id
    WHERE $where_sql";
$impact_stmt = mysqli_prepare($connection, $impact_sql);
if ($impact_stmt) {
    if (!empty($params)) mysqli_stmt_bind_param($impact_stmt, $types, ...$params);
    mysqli_stmt_execute($impact_stmt);
    $impact_result = mysqli_stmt_get_result($impact_stmt);
    $impact_row = mysqli_fetch_assoc($impact_result);
    if ($impact_row) {
        $impact = [
            "affected" => (int)$impact_row['affected'],
            "injured" => (int)$impact_row['injured'],
            "dead" => (int)$impact_row['dead'],
            "missing" => (int)$impact_row['missing'],
        ];
    }
}

// Daily trend: reports per day so spikes are easy to spot.
$days_in_month = (int)date('t', mktime(0, 0, 0, $month, 1, $year));
$daily_counts = array_fill(1, $days_in_month, 0);
$trend_sql = "SELECT DAY($date_expr) AS day_number, COUNT(*) AS total
              FROM incident_reports
              LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id
              WHERE $where_sql
              GROUP BY DAY($date_expr)";
$trend_stmt = mysqli_prepare($connection, $trend_sql);
if ($trend_stmt) {
    if (!empty($params)) mysqli_stmt_bind_param($trend_stmt, $types, ...$params);
    mysqli_stmt_execute($trend_stmt);
    $trend_result = mysqli_stmt_get_result($trend_stmt);
    while ($row = mysqli_fetch_assoc($trend_result)) {
        $day_number = (int)($row['day_number'] ?? 0);
        if ($day_number >= 1 && $day_number <= $days_in_month) {
            $daily_counts[$day_number] = (int)($row['total'] ?? 0);
        }
    }
}
$daily_trend = [];
for ($d = 1; $d <= $days_in_month; $d++) {
    $daily_trend[] = ["day" => $d, "count" => $daily_counts[$d]];
}

$disaster_types = [
    'Typhoon',
    'Flood',
    'Storm Surge',
    'Earthquake',
    'Landslide',
    'Fire',
    'Drought / El Niño',
    'Disease Outbreak',
    'Accident / Mass Casualty Incident',
    'Others'
];

$disaster_summary = [];
foreach ($disaster_types as $type) {
    $disaster_summary[$type] = 0;
}

$disaster_sql = "
    SELECT incident_reports.disaster_type, COUNT(*) AS total
    FROM incident_reports
    LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id
    WHERE $where_sql
    GROUP BY incident_reports.disaster_type
";

$disaster_stmt = mysqli_prepare($connection, $disaster_sql);
if ($disaster_stmt) {
    if (!empty($params)) mysqli_stmt_bind_param($disaster_stmt, $types, ...$params);
    mysqli_stmt_execute($disaster_stmt);
    $disaster_result = mysqli_stmt_get_result($disaster_stmt);

    while ($row = mysqli_fetch_assoc($disaster_result)) {
        $label = normalize_disaster_type($row['disaster_type'] ?? 'Others');
        $disaster_summary[$label] += (int)($row['total'] ?? 0);
    }
}

$disaster_list = [];
foreach ($disaster_summary as $label => $count) {
    $abbr = match ($label) {
        'Typhoon' => 'TYP',
        'Flood' => 'FLD',
        'Storm Surge' => 'SS',
        'Earthquake' => 'EQ',
        'Landslide' => 'LS',
        'Fire' => 'FIRE',
        'Drought / El Niño' => 'DR',
        'Disease Outbreak' => 'DO',
        'Accident / Mass Casualty Incident' => 'MCI',
        default => 'OTH',
    };

    $disaster_list[] = [
        "label" => $label,
        "abbr" => $abbr,
        "count" => $count
    ];
}

// Weather block (Open-Meteo): same shape the web dashboard uses.
list($weather_lat, $weather_lon) = obilak_weather_coords($connection, $role, $barangay_id);
$weather = obilak_get_weather($weather_lat, $weather_lon);

// Secretary-specific: evacuation center status list.
$evac_centers_list = [];
if ($role === 'barangay' && $sub_role === 'secretary' && $barangay_id !== null) {
    $name_stmt = mysqli_prepare($connection, "SELECT name, municipality FROM barangays WHERE id = ? LIMIT 1");
    if ($name_stmt) {
        $bid = (int)$barangay_id;
        mysqli_stmt_bind_param($name_stmt, 'i', $bid);
        mysqli_stmt_execute($name_stmt);
        $name_result = mysqli_stmt_get_result($name_stmt);
        $name_row = mysqli_fetch_assoc($name_result);
        if ($name_row) {
            $bname = $name_row['name'];
            $bmuni = $name_row['municipality'];
            $ec_stmt = mysqli_prepare($connection, "SELECT center_name, status, capacity FROM evacuation_centers WHERE barangay = ? AND municipality = ? ORDER BY status ASC, center_name ASC");
            if ($ec_stmt) {
                mysqli_stmt_bind_param($ec_stmt, 'ss', $bname, $bmuni);
                mysqli_stmt_execute($ec_stmt);
                $ec_result = mysqli_stmt_get_result($ec_stmt);
                while ($ec_row = mysqli_fetch_assoc($ec_result)) {
                    $evac_centers_list[] = [
                        "name" => $ec_row['center_name'] ?? '',
                        "status" => $ec_row['status'] ?? '',
                        "capacity" => (int)($ec_row['capacity'] ?? 0),
                    ];
                }
            }
        }
    }
}

// Tanod-specific: count of reports submitted by this user.
$my_reports = 0;
if ($role === 'barangay' && $sub_role === 'tanod' && $user_id !== null) {
    $uid = (int)$user_id;
    $my_stmt = mysqli_prepare($connection, "SELECT COUNT(*) AS total FROM incident_reports WHERE user_id = ?");
    if ($my_stmt) {
        mysqli_stmt_bind_param($my_stmt, 'i', $uid);
        mysqli_stmt_execute($my_stmt);
        $my_result = mysqli_stmt_get_result($my_stmt);
        $my_row = mysqli_fetch_assoc($my_result);
        $my_reports = (int)($my_row['total'] ?? 0);
    }
}

// --- Needs & Assistance summary (PHO / PCF / Superadmin) ---------------------
// Fulfillment rule: only barangay-confirmed ('Received' = received_at set)
// counts toward a need; 'Pledged'/'Sent'/'Delivered' do NOT reduce the unmet
// quantity.
$unmet_needs = 0;
$incoming_pledges = 0;
$my_pledges = 0;
$zero_pledge_count = 0;
if (in_array($role, $admin_roles)) {
    $assist_muni_where = '';
    $assist_muni_types = '';
    if ($municipality !== '') {
        $assist_muni_where = " AND ec.municipality = ?";
        $assist_muni_types = 's';
    }

    // Each SELECT is fully consumed AND freed right away. Not freeing a result
    // before preparing the next statement triggers MySQL "Commands out of sync"
    // (prepared statements return false) during sequential summary queries.
    $unmet_sql = "SELECT COALESCE(SUM(GREATEST(n.qty_needed - COALESCE(r.received_qty, 0), 0)), 0) AS unmet
                  FROM evac_center_needs n
                  INNER JOIN evacuation_centers ec ON ec.id = n.evac_center_id
                  LEFT JOIN (SELECT need_id, SUM(COALESCE(qty_received, qty)) AS received_qty FROM evac_assistance
                             WHERE received_at IS NOT NULL GROUP BY need_id) r ON r.need_id = n.id
                  WHERE ec.status IN ('Open','Full','Needs Supplies','Available')$assist_muni_where";
    $unmet_stmt = mysqli_prepare($connection, $unmet_sql);
    $unmet_needs = 0;
    if ($unmet_stmt) {
        if ($assist_muni_types) mysqli_stmt_bind_param($unmet_stmt, $assist_muni_types, $municipality);
        mysqli_stmt_execute($unmet_stmt);
        $unmet_row = mysqli_fetch_assoc(mysqli_stmt_get_result($unmet_stmt));
        $unmet_needs = (int)($unmet_row['unmet'] ?? 0);
        mysqli_stmt_free_result($unmet_stmt);
    }

    $inc_sql = "SELECT COALESCE(SUM(a.qty), 0) AS incoming
                FROM evac_assistance a
                INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
                WHERE a.status = 'Pledged'$assist_muni_where";
    $inc_stmt = mysqli_prepare($connection, $inc_sql);
    $incoming_pledges = 0;
    if ($inc_stmt) {
        if ($assist_muni_types) mysqli_stmt_bind_param($inc_stmt, $assist_muni_types, $municipality);
        mysqli_stmt_execute($inc_stmt);
        $inc_row = mysqli_fetch_assoc(mysqli_stmt_get_result($inc_stmt));
        $incoming_pledges = (int)($inc_row['incoming'] ?? 0);
        mysqli_stmt_free_result($inc_stmt);
    }

    $my_sql = "SELECT COUNT(*) AS c FROM evac_assistance a
               INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
               WHERE a.donor_user_id = ?$assist_muni_where";
    $my_stmt = mysqli_prepare($connection, $my_sql);
    $my_pledges = 0;
    if ($my_stmt) {
        if ($assist_muni_types) {
            mysqli_stmt_bind_param($my_stmt, 'is', $user_id, $municipality);
        } else {
            mysqli_stmt_bind_param($my_stmt, 'i', $user_id);
        }
        mysqli_stmt_execute($my_stmt);
        $my_row = mysqli_fetch_assoc(mysqli_stmt_get_result($my_stmt));
        $my_pledges = (int)($my_row['c'] ?? 0);
        mysqli_stmt_free_result($my_stmt);
    }

    $zero_sql = "SELECT COUNT(*) AS c FROM evacuation_centers ec
                 WHERE (EXISTS (SELECT 1 FROM evac_center_profile p WHERE p.evac_center_id = ec.id)
                     OR EXISTS (SELECT 1 FROM evac_center_needs n WHERE n.evac_center_id = ec.id))
                   AND NOT EXISTS (SELECT 1 FROM evac_assistance a WHERE a.evac_center_id = ec.id)
                   AND ec.status IN ('" . implode("','", center_status_allowlist()) . "')
                   $assist_muni_where";
    $zero_stmt = mysqli_prepare($connection, $zero_sql);
    $zero_pledge_count = 0;
    if ($zero_stmt) {
        if ($assist_muni_types) mysqli_stmt_bind_param($zero_stmt, $assist_muni_types, $municipality);
        mysqli_stmt_execute($zero_stmt);
        $zero_row = mysqli_fetch_assoc(mysqli_stmt_get_result($zero_stmt));
        $zero_pledge_count = (int)($zero_row['c'] ?? 0);
        mysqli_stmt_free_result($zero_stmt);
    }
}

// Governor-only province-wide evidence summary (read-only decision support).
$province_evidence = null;
if ($role === 'pho' && $sub_role === 'governor') {
    $province_evidence = governor_province_evidence($connection, $month, $year);
}

// Mayor-only municipality evidence summary (same card, town-scoped, with a
// per-barangay breakdown). Sub_role is DB-verified above in the pcf override.
$municipality_evidence = null;
if (in_array($db_sub_role, ['mayor_kalibo', 'mayor_ibajay'], true) && $municipality !== '') {
    $municipality_evidence = governor_province_evidence($connection, $month, $year, $municipality);
}

send_response(true, "Dashboard summary loaded successfully.", [
    "scope_label" => $scope_label,
    "month" => $month,
    "year" => $year,
    "note" => "Dismissed reports are excluded.",
    "total_reports" => $total_reports,
    "pending" => $pending,
    "forwarded_to_pho" => $forwarded_to_pho,
    "evacuation_centers" => $evacuation_centers,
    "status_summary" => $status_summary,
    "impact" => $impact,
    "daily_trend" => $daily_trend,
    "disaster_summary" => $disaster_list,
    "weather" => $weather,
    "sub_role" => $sub_role,
    "evac_centers_list" => $evac_centers_list,
    "my_reports" => $my_reports,
    "unmet_needs" => $unmet_needs,
    "incoming_pledges" => $incoming_pledges,
    "my_pledges" => $my_pledges,
    "zero_pledge_count" => $zero_pledge_count,
    "province_evidence" => $province_evidence,
    "municipality_evidence" => $municipality_evidence,
]);
?>
