<?php
$V_page_title = "Dashboard";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_role = $_SESSION['role'];
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_barangay_id = (int)($_SESSION['barangay_id'] ?? 0);
$V_barangay_name = $_SESSION['barangay_name'] ?? '';

// Municipality filter for admin roles (forces municipality for MDR sub-roles)
$V_filter_muni = is_admin_role($V_role) ? get_effective_municipality($V_role, $V_sub_role) : null;

// Weather card (open-Meteo): use the barangay's own location, or the town center.
include_once "../app/includes/weather_helper.php";
list($V_weather_lat, $V_weather_lon) = obilak_weather_coords($connection, $V_role, $V_barangay_id);
$V_weather = obilak_get_weather($V_weather_lat, $V_weather_lon);

$V_where = "1=1";

if ($V_role == 'barangay') {
    $V_where = "incident_reports.barangay_id = $V_barangay_id";
    // BHERT (tanod) dashboards are isolated to the reports the BHERT
    // submitted themselves — mirrors the "My Reports" list scoping.
    if ($V_sub_role == 'tanod') {
        $V_where .= " AND incident_reports.user_id = " . (int)($_SESSION['user_id'] ?? 0);
    }
}

if ($V_role == 'pho') {
    $V_where = "incident_reports.referred_to_pho = 1";
}

// Municipal Office (PCF / MDR) dashboards show only reports that have been
// forwarded into the MDR pipeline — not barangay-submitted reports still
// sitting as Pending and awaiting dispatch. This mirrors the app.
if ($V_role == 'pcf') {
    $V_where = "incident_reports.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')";
}

// Apply municipality filter for admin roles (requires barangays JOIN)
$V_dash_join = "INNER JOIN barangays ON incident_reports.barangay_id = barangays.id";
if ($V_filter_muni && is_admin_role($V_role)) {
    $V_where .= " AND barangays.municipality = '" . mysqli_real_escape_string($connection, $V_filter_muni) . "'";
} elseif ($V_role != 'barangay') {
    // Non-filter admin path still needs the JOIN; use LEFT JOIN to keep existing logic
    $V_dash_join = "LEFT JOIN barangays ON incident_reports.barangay_id = barangays.id";
}

$TotalQuery = mysqli_query($connection, "SELECT COUNT(*) AS total FROM incident_reports $V_dash_join WHERE $V_where");
$TotalRow = mysqli_fetch_assoc($TotalQuery);
$V_total_reports = $TotalRow['total'];

$PendingQuery = mysqli_query($connection, "SELECT COUNT(*) AS total FROM incident_reports $V_dash_join WHERE $V_where AND incident_reports.status = 'Pending'");
$PendingRow = mysqli_fetch_assoc($PendingQuery);
$V_pending_reports = $PendingRow['total'];

$ReviewQuery = mysqli_query($connection, "SELECT COUNT(*) AS total FROM incident_reports $V_dash_join WHERE $V_where AND incident_reports.status = 'Responding'");
$ReviewRow = mysqli_fetch_assoc($ReviewQuery);
$V_review_reports = $ReviewRow['total'];

$HealthQuery = mysqli_query($connection, "SELECT COUNT(*) AS total FROM incident_reports $V_dash_join WHERE $V_where AND incident_reports.referred_to_pho = 1");
$HealthRow = mysqli_fetch_assoc($HealthQuery);
$V_health_reports = $HealthRow['total'];

// Evac center count — admin: filtered by municipality; barangay: own barangay only
if ($V_filter_muni && is_admin_role($V_role)) {
    $CenterQuery = mysqli_prepare($connection,
        "SELECT COUNT(*) AS total FROM evacuation_centers
         WHERE evacuation_centers.status IN ('Available', 'Open')
           AND evacuation_centers.municipality = ?");
    mysqli_stmt_bind_param($CenterQuery, 's', $V_filter_muni);
    mysqli_stmt_execute($CenterQuery);
    $CenterRow = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterQuery));
} elseif ($V_role == 'barangay') {
    $CenterQuery = mysqli_prepare($connection,
        "SELECT COUNT(*) AS total FROM evacuation_centers
         WHERE evacuation_centers.status IN ('Available', 'Open')
           AND evacuation_centers.barangay = ?
           AND evacuation_centers.municipality = (SELECT municipality FROM barangays WHERE name = ? LIMIT 1)");
    mysqli_stmt_bind_param($CenterQuery, 'ss', $V_barangay_name, $V_barangay_name);
    mysqli_stmt_execute($CenterQuery);
    $CenterRow = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterQuery));
} else {
    $CenterResult = mysqli_query($connection, "SELECT COUNT(*) AS total FROM evacuation_centers WHERE status IN ('Available', 'Open')");
    $CenterRow = mysqli_fetch_assoc($CenterResult);
}
$V_evac_centers = (int)($CenterRow['total'] ?? 0);

$LatestQuery = "SELECT incident_reports.*, barangays.name AS barangay_name, users.name AS creator_name
                FROM incident_reports
                INNER JOIN barangays ON incident_reports.barangay_id = barangays.id
                LEFT JOIN users ON incident_reports.user_id = users.id
                WHERE $V_where
                ORDER BY incident_reports.created_at DESC
                LIMIT 8";
$LatestResult = mysqli_query($connection, $LatestQuery);


$V_selected_month = isset($_GET['month']) ? (int)$_GET['month'] : (int)date('n');
$V_selected_year = isset($_GET['year']) ? (int)$_GET['year'] : (int)date('Y');

if ($V_selected_month < 1 || $V_selected_month > 12) {
    $V_selected_month = (int)date('n');
}

if ($V_selected_year < 2000 || $V_selected_year > 2100) {
    $V_selected_year = (int)date('Y');
}

$V_chart_rows = [];

if ($V_role == 'barangay') {
    $V_chart_user_extra = ($V_sub_role == 'tanod')
        ? " AND incident_reports.user_id = ?"
        : "";
    $ChartQuery = "SELECT disaster_types.name AS disaster_type, COUNT(incident_reports.id) AS total
                   FROM disaster_types
                   LEFT JOIN incident_reports ON incident_reports.disaster_type = disaster_types.name
                       AND incident_reports.status != 'Dismissed'
                       AND MONTH(incident_reports.created_at) = ?
                       AND YEAR(incident_reports.created_at) = ?
                       AND incident_reports.barangay_id = ?
                       $V_chart_user_extra
                   WHERE disaster_types.status = 'Active'
                   GROUP BY disaster_types.id, disaster_types.name
                   ORDER BY disaster_types.id ASC";
    $chart_stmt = mysqli_prepare($connection, $ChartQuery);
    if ($V_sub_role == 'tanod') {
        $V_chart_uid = (int)($_SESSION['user_id'] ?? 0);
        mysqli_stmt_bind_param($chart_stmt, "iiii", $V_selected_month, $V_selected_year, $V_barangay_id, $V_chart_uid);
    } else {
        mysqli_stmt_bind_param($chart_stmt, "iii", $V_selected_month, $V_selected_year, $V_barangay_id);
    }
} elseif ($V_filter_muni && is_admin_role($V_role)) {
    // PCF/MDR chart uses the same forwarded-status scope as the app.
    // PHO gets the same referred-to-Provincial scope used everywhere else.
    $V_chart_status_extra = ($V_role == 'pcf')
        ? " AND ir2.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')"
        : ($V_role == 'pho' ? " AND ir2.referred_to_pho = 1" : "");
    $ChartQuery = "SELECT disaster_types.name AS disaster_type, COUNT(incident_reports.id) AS total
                   FROM disaster_types
                   LEFT JOIN incident_reports ON incident_reports.disaster_type = disaster_types.name
                       AND incident_reports.status != 'Dismissed'
                       AND MONTH(incident_reports.created_at) = ?
                       AND YEAR(incident_reports.created_at) = ?
                       AND incident_reports.id IN (
                           SELECT ir2.id FROM incident_reports ir2
                           INNER JOIN barangays b2 ON ir2.barangay_id = b2.id
                           WHERE b2.municipality = ?$V_chart_status_extra
                       )
                   WHERE disaster_types.status = 'Active'
                   GROUP BY disaster_types.id, disaster_types.name
                   ORDER BY disaster_types.id ASC";
    $chart_stmt = mysqli_prepare($connection, $ChartQuery);
    mysqli_stmt_bind_param($chart_stmt, "iis", $V_selected_month, $V_selected_year, $V_filter_muni);
} else {
    // No municipality filter (e.g. Governor / "All Municipalities"): PHO still
    // stays scoped to reports referred to Provincial, matching every other PHO view.
    $V_chart_global_extra = ($V_role == 'pho') ? " AND incident_reports.referred_to_pho = 1" : "";
    $ChartQuery = "SELECT disaster_types.name AS disaster_type, COUNT(incident_reports.id) AS total
                   FROM disaster_types
                   LEFT JOIN incident_reports ON incident_reports.disaster_type = disaster_types.name
                       AND incident_reports.status != 'Dismissed'
                       AND MONTH(incident_reports.created_at) = ?
                       AND YEAR(incident_reports.created_at) = ?$V_chart_global_extra
                   WHERE disaster_types.status = 'Active'
                   GROUP BY disaster_types.id, disaster_types.name
                   ORDER BY disaster_types.id ASC";
    $chart_stmt = mysqli_prepare($connection, $ChartQuery);
    mysqli_stmt_bind_param($chart_stmt, "ii", $V_selected_month, $V_selected_year);
}

mysqli_stmt_execute($chart_stmt);
$ChartResult = mysqli_stmt_get_result($chart_stmt);
$V_max_chart_total = 0;

while ($chart = mysqli_fetch_assoc($ChartResult)) {
    $chart['total'] = (int)$chart['total'];
    if ($chart['total'] > $V_max_chart_total) {
        $V_max_chart_total = $chart['total'];
    }
    $V_chart_rows[] = $chart;
}

// Build a fixed number scale for the chart so bar heights reflect the real
// count, instead of always making the biggest bar full height.
if ($V_max_chart_total <= 25) {
    $V_chart_step = 5;
} elseif ($V_max_chart_total <= 50) {
    $V_chart_step = 10;
} elseif ($V_max_chart_total <= 150) {
    $V_chart_step = 25;
} else {
    $V_chart_step = 50;
}
// Ceiling sits one step above the highest value, so the tallest bar always
// leaves a little headroom (it is never pinned to the very top).
$V_chart_ceiling = (intdiv(max($V_max_chart_total, 0), $V_chart_step) + 1) * $V_chart_step;
$V_chart_ticks = [];
for ($V_tick_value = $V_chart_ceiling; $V_tick_value >= 0; $V_tick_value -= $V_chart_step) {
    $V_chart_ticks[] = $V_tick_value;
}

// --- Monthly analytics (status, human impact, daily trend) ---
// These three sections all use the SAME month/year picked for the chart above,
// so the whole panel tells one consistent "for this month" story.
// Values below are all integers from the session, so they are safe to inline.
$V_month_where = "incident_reports.status != 'Dismissed'"
    . " AND MONTH(incident_reports.created_at) = $V_selected_month"
    . " AND YEAR(incident_reports.created_at) = $V_selected_year";

if ($V_role == 'barangay') {
    $V_month_where .= " AND incident_reports.barangay_id = $V_barangay_id";
    if ($V_sub_role == 'tanod') {
        $V_month_where .= " AND incident_reports.user_id = " . (int)($_SESSION['user_id'] ?? 0);
    }
} elseif ($V_role == 'pho') {
    $V_month_where .= " AND incident_reports.referred_to_pho = 1";
} elseif ($V_role == 'pcf') {
    // PCF/MDR monthly analytics also stay scoped to forwarded reports only.
    $V_month_where .= " AND incident_reports.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')";
}

// For admin roles, wrap the month queries with a JOIN-based subquery when filtered
$V_month_join = "";
if ($V_filter_muni && is_admin_role($V_role)) {
    $V_month_join = "INNER JOIN barangays ON incident_reports.barangay_id = barangays.id";
    $V_month_where .= " AND barangays.municipality = '" . mysqli_real_escape_string($connection, $V_filter_muni) . "'";
}

// Status breakdown: how many reports sit at each stage.
$V_status_rows = [];
$V_status_max = 0;
$StatusResult = mysqli_query($connection, "SELECT incident_reports.status AS status, COUNT(*) AS total FROM incident_reports $V_month_join WHERE $V_month_where GROUP BY incident_reports.status");
if ($StatusResult) {
    while ($status_row = mysqli_fetch_assoc($StatusResult)) {
        $status_row['total'] = (int)$status_row['total'];
        if ($status_row['total'] > $V_status_max) {
            $V_status_max = $status_row['total'];
        }
        $V_status_rows[] = $status_row;
    }
}

// Human impact: total people affected for the month.
$ImpactResult = mysqli_query($connection, "SELECT
        COALESCE(SUM(affected_people), 0) AS affected,
        COALESCE(SUM(injured), 0) AS injured,
        COALESCE(SUM(dead), 0) AS dead,
        COALESCE(SUM(missing), 0) AS missing
    FROM incident_reports $V_month_join WHERE $V_month_where");
$V_impact = mysqli_fetch_assoc($ImpactResult) ?: ['affected' => 0, 'injured' => 0, 'dead' => 0, 'missing' => 0];

// Daily trend: reports per day, so spikes are easy to spot.
$V_days_in_month = (int)date('t', mktime(0, 0, 0, $V_selected_month, 1, $V_selected_year));
$V_trend_counts = array_fill(1, $V_days_in_month, 0);
$V_trend_max = 0;
$TrendResult = mysqli_query($connection, "SELECT DAY(created_at) AS day_number, COUNT(*) AS total FROM incident_reports $V_month_join WHERE $V_month_where GROUP BY DAY(created_at)");
if ($TrendResult) {
    while ($trend_row = mysqli_fetch_assoc($TrendResult)) {
        $day_number = (int)$trend_row['day_number'];
        if ($day_number >= 1 && $day_number <= $V_days_in_month) {
            $V_trend_counts[$day_number] = (int)$trend_row['total'];
            if ($V_trend_counts[$day_number] > $V_trend_max) {
                $V_trend_max = $V_trend_counts[$day_number];
            }
        }
    }
}

// Build rounded "nice" number scales for the status + trend bars, the same way
// the disaster chart does, so a small count never fills the whole bar.
$V_status_step = $V_status_max <= 25 ? 5 : ($V_status_max <= 50 ? 10 : ($V_status_max <= 150 ? 25 : 50));
$V_status_ceiling = (intdiv(max($V_status_max, 0), $V_status_step) + 1) * $V_status_step;
$V_status_ticks = [];
for ($V_tick = 0; $V_tick <= $V_status_ceiling; $V_tick += $V_status_step) {
    $V_status_ticks[] = $V_tick;
}

$V_trend_step = $V_trend_max <= 25 ? 5 : ($V_trend_max <= 50 ? 10 : ($V_trend_max <= 150 ? 25 : 50));
$V_trend_ceiling = (intdiv(max($V_trend_max, 0), $V_trend_step) + 1) * $V_trend_step;
$V_trend_ticks = [];
for ($V_tick = $V_trend_ceiling; $V_tick >= 0; $V_tick -= $V_trend_step) {
    $V_trend_ticks[] = $V_tick;
}

$V_month_names = [
    1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
    5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August',
    9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
];
$V_chart_scope = ($V_role == 'barangay') ? ($V_barangay_name ?? 'Your Barangay') : ($V_filter_muni ? h($V_filter_muni) : 'All Barangays');

if (!function_exists('report_number')) {
    function report_number($id, $created_at) {
        $year = date('Y', strtotime($created_at));
        return $year . '-' . str_pad((int)$id, 4, '0', STR_PAD_LEFT);
    }
}

// Secretary-specific: evacuation center status list.
$V_evac_center_rows = [];
if ($V_role == 'barangay' && $V_sub_role == 'secretary') {
    $ECQuery = mysqli_prepare($connection, "SELECT center_name, status, capacity, barangay FROM evacuation_centers WHERE barangay = ? ORDER BY status ASC, center_name ASC");
    if ($ECQuery) {
        mysqli_stmt_bind_param($ECQuery, "s", $V_barangay_name);
        mysqli_stmt_execute($ECQuery);
        $ECResult = mysqli_stmt_get_result($ECQuery);
        while ($ec = mysqli_fetch_assoc($ECResult)) {
            $V_evac_center_rows[] = $ec;
        }
    }
}

// Tanod-specific: count of reports submitted by this user.
$V_my_reports = 0;
if ($V_role == 'barangay' && $V_sub_role == 'tanod') {
    $MyQuery = mysqli_prepare($connection, "SELECT COUNT(*) AS total FROM incident_reports WHERE user_id = ?");
    if ($MyQuery) {
        mysqli_stmt_bind_param($MyQuery, "i", $_SESSION['user_id']);
        mysqli_stmt_execute($MyQuery);
        $MyResult = mysqli_stmt_get_result($MyQuery);
        $MyRow = mysqli_fetch_assoc($MyResult);
        $V_my_reports = (int)($MyRow['total'] ?? 0);
    }
}

// --- Needs & Assistance panel (PCF / PHO / Superadmin) -----------------------
// Shows "what the centers still need", what is still just pledged (incoming),
// and a heads-up on centers that got no pledges yet. Fulfillment rule: only
// Sent/Delivered supply counts toward a need; Pledged is "incoming".
$V_unmet_total = 0;
$V_incoming_total = 0;
$V_my_pledges = 0;
$V_zero_pledge_centers = [];

if (can_view_assistance($V_role)) {
    $V_assist_muni_where = '';
    $V_assist_muni_bind = '';
    if ($V_filter_muni) {
        $V_assist_muni_where = " AND ec.municipality = ?";
        $V_assist_muni_bind = "s";
    }

    $UnmetSql = "SELECT COALESCE(SUM(GREATEST(n.qty_needed - COALESCE(s.sent_qty, 0), 0)), 0) AS unmet
                 FROM evac_center_needs n
                 INNER JOIN evacuation_centers ec ON ec.id = n.evac_center_id
                 LEFT JOIN (SELECT need_id, SUM(qty) AS sent_qty FROM evac_assistance
                            WHERE status IN ('Sent','Delivered') GROUP BY need_id) s ON s.need_id = n.id
                 WHERE ec.status IN ('Open','Full','Needs Supplies','Available')$V_assist_muni_where";
    $UnmetStmt = mysqli_prepare($connection, $UnmetSql);
    $V_unmet_total = 0;
    if ($UnmetStmt) {
        if ($V_assist_muni_bind) mysqli_stmt_bind_param($UnmetStmt, $V_assist_muni_bind, $V_filter_muni);
        mysqli_stmt_execute($UnmetStmt);
        $UnmetRes = mysqli_stmt_get_result($UnmetStmt);
        if ($UnmetRes) {
            $UnmetRow = mysqli_fetch_assoc($UnmetRes);
            $V_unmet_total = (int)($UnmetRow['unmet'] ?? 0);
            mysqli_free_result($UnmetRes);
        } else {
            error_log("dashboard: unmet query failed: " . mysqli_error($connection));
        }
        mysqli_stmt_free_result($UnmetStmt);
    }

    $IncSql = "SELECT COALESCE(SUM(a.qty), 0) AS incoming
               FROM evac_assistance a
               INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
               WHERE a.status = 'Pledged'$V_assist_muni_where";
    $IncStmt = mysqli_prepare($connection, $IncSql);
    $V_incoming_total = 0;
    if ($IncStmt) {
        if ($V_assist_muni_bind) mysqli_stmt_bind_param($IncStmt, $V_assist_muni_bind, $V_filter_muni);
        mysqli_stmt_execute($IncStmt);
        $IncRes = mysqli_stmt_get_result($IncStmt);
        if ($IncRes) {
            $IncRow = mysqli_fetch_assoc($IncRes);
            $V_incoming_total = (int)($IncRow['incoming'] ?? 0);
            mysqli_free_result($IncRes);
        } else {
            error_log("dashboard: incoming query failed: " . mysqli_error($connection));
        }
        mysqli_stmt_free_result($IncStmt);
    }

    $MySql = "SELECT COUNT(*) AS c FROM evac_assistance a
              INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
              WHERE a.donor_user_id = ?$V_assist_muni_where";
    $MyStmt = mysqli_prepare($connection, $MySql);
    $V_my_pledges = 0;
    if ($MyStmt) {
        $V_uid = (int)$_SESSION['user_id'];
        if ($V_assist_muni_bind) {
            mysqli_stmt_bind_param($MyStmt, "is", $V_uid, $V_filter_muni);
        } else {
            mysqli_stmt_bind_param($MyStmt, "i", $V_uid);
        }
        mysqli_stmt_execute($MyStmt);
        $MyRes = mysqli_stmt_get_result($MyStmt);
        if ($MyRes) {
            $MyRow = mysqli_fetch_assoc($MyRes);
            $V_my_pledges = (int)($MyRow['c'] ?? 0);
            mysqli_free_result($MyRes);
        } else {
            error_log("dashboard: my pledges query failed: " . mysqli_error($connection));
        }
        mysqli_stmt_free_result($MyStmt);
    }

    $ZeroSql = "SELECT ec.center_name, ec.barangay, ec.municipality
                FROM evacuation_centers ec
                WHERE (EXISTS (SELECT 1 FROM evac_center_profile p WHERE p.evac_center_id = ec.id)
                    OR EXISTS (SELECT 1 FROM evac_center_needs n WHERE n.evac_center_id = ec.id))
                  AND NOT EXISTS (SELECT 1 FROM evac_assistance a WHERE a.evac_center_id = ec.id)
                  AND ec.status IN ('" . implode("','", center_status_allowlist()) . "')
                  $V_assist_muni_where
                ORDER BY ec.municipality ASC, ec.barangay ASC, ec.center_name ASC
                LIMIT 3";
    $ZeroStmt = mysqli_prepare($connection, $ZeroSql);
    $V_zero_pledge_centers = [];
    if ($ZeroStmt) {
        if ($V_assist_muni_bind) mysqli_stmt_bind_param($ZeroStmt, $V_assist_muni_bind, $V_filter_muni);
        mysqli_stmt_execute($ZeroStmt);
        $Zres = mysqli_stmt_get_result($ZeroStmt);
        if ($Zres) {
            while ($zc = mysqli_fetch_assoc($Zres)) {
                $V_zero_pledge_centers[] = $zc;
            }
            mysqli_free_result($Zres);
        } else {
            error_log("dashboard: zero-pledge query failed: " . mysqli_error($connection));
        }
        mysqli_stmt_free_result($ZeroStmt);
    }
}
?>

<style>
/* Same red as the site theme, kept here so the see-through tint below
   matches and a future color change stays in one place. */
:root {
    --primary-rgb: 220, 53, 69;
}

.dashboard-chart-header {
    gap: 8px;
    flex-wrap: wrap;
    align-items: flex-start;
}

.dashboard-chart-filter {
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
    width: 100%;
    margin-top: 8px;
}

.dashboard-chart-filter select {
    min-width: 120px;
}

.disaster-chart-wrap {
    width: 100%;
    overflow-x: auto;
    padding-bottom: 6px;
}

.disaster-chart {
    min-width: 720px;
}

.disaster-chart-row {
    display: flex;
    gap: 10px;
    align-items: flex-end;
}

.disaster-chart-yaxis {
    flex: 0 0 34px;
    height: 220px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    align-items: flex-end;
    padding-right: 6px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted, #6b7280);
}

.disaster-plot {
    flex: 1 1 auto;
    height: 220px;
    display: flex;
    align-items: flex-end;
    gap: 16px;
    padding: 0 6px;
    border-left: 1px solid rgba(0, 0, 0, 0.12);
    border-bottom: 1px solid rgba(0, 0, 0, 0.12);
}

.disaster-column {
    flex: 1 0 80px;
    height: 100%;
    display: flex;
    align-items: flex-end;
    justify-content: center;
}

.disaster-column-fill {
    position: relative;
    width: 54px;
    max-width: 80%;
    min-height: 2px;
    background: var(--primary, #DC3545);
    border-radius: 8px 8px 0 0;
    box-shadow: 0 8px 18px rgba(var(--primary-rgb), 0.18);
}

.disaster-column-count {
    position: absolute;
    bottom: 100%;
    left: 0;
    right: 0;
    margin-bottom: 4px;
    text-align: center;
    font-weight: 700;
    font-size: 13px;
    color: var(--text, #212529);
}

.labels-row {
    align-items: flex-start;
    margin-top: 6px;
}

.disaster-chart-yaxis-spacer {
    flex: 0 0 34px;
}

.disaster-labels {
    flex: 1 1 auto;
    display: flex;
    gap: 16px;
    padding: 0 6px;
}

.disaster-label-col {
    flex: 1 0 80px;
    text-align: center;
    font-size: 13px;
    font-weight: 600;
    line-height: 1.2;
    color: var(--text-muted, #4b5563);
}

.disaster-chart-axis-note {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    color: var(--text-muted, #6b7280);
    font-size: 13px;
}

@media (max-width: 768px) {
    .disaster-chart,
    .disaster-labels {
        min-width: 620px;
    }

    .disaster-plot,
    .disaster-chart-yaxis {
        height: 200px;
    }

    .disaster-column {
        flex-basis: 70px;
    }

    .disaster-column-fill {
        width: 46px;
    }
}

.stat-grid-note {
    margin-bottom: 8px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-muted, #6b7280);
    text-transform: uppercase;
    letter-spacing: 0.04em;
}

/* Status breakdown */
.status-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.status-item {
    display: flex;
    align-items: center;
    gap: 12px;
}

.status-name {
    flex: 0 0 150px;
    font-size: 13px;
    font-weight: 600;
    color: var(--text, #212529);
}

.status-track {
    flex: 1 1 auto;
    height: 14px;
    background: rgba(0, 0, 0, 0.06);
    border-radius: 999px;
    overflow: hidden;
}

.status-fill {
    height: 100%;
    min-width: 2px;
    border-radius: 999px;
}

.status-count {
    flex: 0 0 34px;
    text-align: right;
    font-size: 13px;
    font-weight: 700;
    color: var(--text, #212529);
}

.status-axis {
    display: flex;
    justify-content: space-between;
    margin-top: 8px;
    margin-left: 162px;
    margin-right: 46px;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted, #6b7280);
}

/* Human impact tally */
.impact-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
}

.impact-box {
    padding: 14px;
    border-radius: 12px;
    background: var(--card, #ffffff);
    border: 1px solid var(--border, #dee2e6);
    text-align: center;
}

.impact-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-muted, #6b7280);
    text-transform: uppercase;
    letter-spacing: 0.03em;
}

.impact-number {
    margin-top: 4px;
    font-size: 24px;
    font-weight: 800;
    color: var(--text, #212529);
}

/* Daily trend */
.trend-row {
    display: flex;
    gap: 8px;
    align-items: flex-end;
}

.trend-yaxis {
    flex: 0 0 28px;
    height: 140px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    align-items: flex-end;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted, #6b7280);
}

.trend-plot {
    flex: 1 1 auto;
    display: flex;
    align-items: flex-end;
    gap: 3px;
    height: 140px;
    padding: 0 4px;
    border-left: 1px solid rgba(0, 0, 0, 0.12);
    border-bottom: 1px solid rgba(0, 0, 0, 0.12);
}

.trend-bar-wrap {
    flex: 1 1 auto;
    height: 100%;
    display: flex;
    align-items: flex-end;
}

.trend-bar {
    width: 100%;
    min-height: 1px;
    background: var(--primary, #DC3545);
    border-radius: 3px 3px 0 0;
}

.trend-labels {
    display: flex;
    justify-content: space-between;
    margin-top: 6px;
    margin-left: 36px;
    font-size: 11px;
    color: var(--text-muted, #6b7280);
}

@media (max-width: 768px) {
    .impact-grid {
        grid-template-columns: repeat(2, 1fr);
    }

    .status-name {
        flex-basis: 110px;
    }

    .status-axis {
        margin-left: 122px;
    }
}
/* Weather card */
.weather-card { margin-bottom: 16px; }
.weather-alert { border-radius: 8px; padding: 10px 14px; margin-bottom: 12px; font-weight: 600; font-size: 14px; }
.weather-alert.warning { background: #FEE2E2; color: #991B1B; }
.weather-alert.watch { background: #FEF3C7; color: #92400E; }
.weather-top { display: flex; flex-wrap: wrap; gap: 16px; align-items: center; justify-content: space-between; }
.weather-now { display: flex; align-items: center; gap: 14px; }
.weather-emoji { font-size: 44px; line-height: 1; }
.weather-temp { font-size: 34px; font-weight: 700; color: #1f2937; }
.weather-meta { font-size: 13px; color: #6b7280; }
.weather-meta .weather-cond { font-weight: 600; color: #374151; display: block; margin-bottom: 2px; }
.weather-days { display: flex; gap: 8px; flex-wrap: wrap; flex: 1; }
.weather-day { text-align: center; flex: 1; min-width: 64px; padding: 8px 6px; border: 1px solid #eceff3; border-radius: 8px; }
.weather-day .wd-label { font-size: 12px; font-weight: 600; color: #374151; }
.weather-day .wd-emoji { font-size: 22px; margin: 2px 0; }
.weather-day .wd-temp { font-size: 12px; color: #4b5563; }
.weather-day .wd-rain { font-size: 11px; color: #2563eb; }
.weather-updated { margin-top: 10px; font-size: 11px; color: #9ca3af; }
@media (max-width: 768px) { .weather-top { justify-content: flex-start; } }
</style>

<?php if (!empty($V_weather['available'])): ?>
<div class="panel-card weather-card">
    <?php if (!empty($V_weather['alert']) && $V_weather['alert']['level'] !== 'none'): ?>
        <div class="weather-alert <?php echo h($V_weather['alert']['level']); ?>">
            <?php echo ($V_weather['alert']['level'] === 'warning' ? '⚠️ ' : '🌧️ '); ?><?php echo h($V_weather['alert']['message']); ?>
        </div>
    <?php endif; ?>
    <div class="weather-top">
        <div class="weather-now">
            <div class="weather-emoji"><?php echo $V_weather['current']['emoji']; ?></div>
            <div>
                <div class="weather-temp"><?php echo h($V_weather['current']['temp']); ?>&deg;C</div>
                <div class="weather-meta">
                    <span class="weather-cond"><?php echo h($V_weather['current']['condition']); ?></span>
                    Feels <?php echo h($V_weather['current']['feels_like']); ?>&deg; &middot; Humidity <?php echo h($V_weather['current']['humidity']); ?>% &middot; Wind <?php echo h($V_weather['current']['wind']); ?> km/h
                </div>
            </div>
        </div>
        <div class="weather-days">
            <?php foreach ($V_weather['days'] as $wd): ?>
            <div class="weather-day">
                <div class="wd-label"><?php echo h($wd['label']); ?></div>
                <div class="wd-emoji"><?php echo $wd['emoji']; ?></div>
                <div class="wd-temp"><?php echo h($wd['temp_max']); ?>&deg; / <?php echo h($wd['temp_min']); ?>&deg;</div>
                <div class="wd-rain">💧 <?php echo h($wd['rain_chance']); ?>%</div>
            </div>
            <?php endforeach; ?>
        </div>
    </div>
    <div class="weather-updated">Weather for <?php echo h($V_barangay_name ?: 'Kalibo'); ?> &middot; Updated <?php echo h($V_weather['updated_at']); ?><?php echo !empty($V_weather['stale']) ? ' (offline &mdash; last saved)' : ''; ?> &middot; Source: Open-Meteo</div>
</div>
<?php endif; ?>

<?php if ($V_role == 'barangay' && $V_sub_role == 'secretary'): ?>
<div class="stat-grid-note">Barangay Overview</div>
<div class="stat-grid">
    <div class="stat-box warning">
        <div class="stat-label">Pending Reports</div>
        <div class="stat-number"><?php echo $V_pending_reports; ?></div>
    </div>
    <div class="stat-box danger">
        <div class="stat-label">Active Alerts</div>
        <div class="stat-number"><?php echo $V_health_reports; ?></div>
    </div>
    <div class="stat-box success">
        <div class="stat-label">Evac Centers</div>
        <div class="stat-number"><?php echo $V_evac_centers; ?></div>
    </div>
    <div class="stat-box info">
        <div class="stat-label">People Affected</div>
        <div class="stat-number"><?php echo (int)($V_impact['affected'] ?? 0); ?></div>
    </div>
</div>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Evacuation Center Status</h2>
            <p>Current status of evacuation centers in <?php echo h($V_barangay_name); ?>.</p>
        </div>
        <a class="btn btn-emergency btn-sm" href="evacuation-centers.php">Manage Centers</a>
    </div>
    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Center Name</th>
                    <th>Status</th>
                    <th>Capacity</th>
                </tr>
            </thead>
            <tbody>
                <?php if (count($V_evac_center_rows) > 0): ?>
                    <?php foreach ($V_evac_center_rows as $ec): ?>
                        <tr>
                            <td><strong><?php echo h($ec['center_name']); ?></strong></td>
                            <td>
                                <span class="soft-badge <?php echo h(center_status_badge_class($ec['status'])); ?>"><?php echo h($ec['status']); ?></span>
                            </td>
                            <td><?php echo (int)($ec['capacity'] ?? 0); ?></td>
                        </tr>
                    <?php endforeach; ?>
                <?php else: ?>
                    <tr><td colspan="3" class="empty-state">No evacuation centers found.</td></tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php elseif ($V_role == 'barangay' && $V_sub_role == 'tanod'): ?>
<div class="stat-grid-note">My Field Summary</div>
<div class="stat-grid">
    <div class="stat-box info">
        <div class="stat-label">My Reports</div>
        <div class="stat-number"><?php echo $V_my_reports; ?></div>
    </div>
    <div class="stat-box success">
        <div class="stat-label">People Affected</div>
        <div class="stat-number"><?php echo (int)($V_impact['affected'] ?? 0); ?></div>
    </div>
    <div class="stat-box warning">
        <div class="stat-label">Pending</div>
        <div class="stat-number"><?php echo $V_pending_reports; ?></div>
    </div>
    <div class="stat-box danger">
        <div class="stat-label">Active Alerts</div>
        <div class="stat-number"><?php echo $V_health_reports; ?></div>
    </div>
</div>

<div class="panel-card">
    <div class="panel-body text-center" style="padding: 30px;">
        <h3>Submit a Disaster Report</h3>
        <p class="text-muted mb-3">Spotted something? File an incident report right away.</p>
        <a class="btn btn-emergency btn-lg" href="create-incident-report.php">Create Report</a>
    </div>
</div>

<?php else: ?>
<div class="stat-grid-note">All-time totals</div>
<div class="stat-grid">
    <div class="stat-box info">
        <div class="stat-label">Total Reports</div>
        <div class="stat-number"><?php echo $V_total_reports; ?></div>
    </div>
    <div class="stat-box warning">
        <div class="stat-label">Pending</div>
        <div class="stat-number"><?php echo $V_pending_reports; ?></div>
    </div>
    <div class="stat-box danger">
        <div class="stat-label"><?php echo ($V_role == 'pho') ? 'Provincial Cases' : 'Provincial'; ?></div>
        <div class="stat-number"><?php echo $V_health_reports; ?></div>
    </div>
    <div class="stat-box success">
        <div class="stat-label"><?php echo ($V_role == 'pcf') ? 'Responding' : 'Evac Centers'; ?></div>
        <div class="stat-number"><?php echo ($V_role == 'pcf') ? $V_review_reports : $V_evac_centers; ?></div>
    </div>
</div>

<?php endif; ?>

<?php if (can_view_assistance($V_role)): ?>
<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Evacuation Center Needs &amp; Assistance</h2>
            <p>What centers still need, what is pledged, and the centers nobody has pledged to yet.</p>
        </div>
        <a class="btn btn-emergency btn-sm" href="assistance.php">Open Needs Board</a>
    </div>

    <?php if (count($V_zero_pledge_centers) > 0): ?>
        <div class="zero-pledge-banner" style="background:#FEF3C7;border:1px solid #FDE68A;color:#92400E;border-radius:10px;padding:10px 14px;margin:0 0 12px;font-size:14px;">
            <strong>No pledges yet:</strong>
            <?php
            $Z_names = [];
            foreach ($V_zero_pledge_centers as $zc) {
                $Z_names[] = h($zc['center_name']) . ' (' . h($zc['barangay']) . ', ' . h($zc['municipality']) . ')';
            }
            echo implode(' · ', $Z_names);
            if (count($V_zero_pledge_centers) === 3) echo ' …';
            ?>
        </div>
    <?php endif; ?>

    <div class="stat-grid">
        <div class="stat-box danger">
            <div class="stat-label">Still Needed</div>
            <div class="stat-number"><?php echo (int)$V_unmet_total; ?></div>
        </div>
        <div class="stat-box warning">
            <div class="stat-label">Incoming Pledges</div>
            <div class="stat-number"><?php echo (int)$V_incoming_total; ?></div>
        </div>
        <div class="stat-box success">
            <div class="stat-label">My Pledges</div>
            <div class="stat-number"><?php echo (int)$V_my_pledges; ?></div>
        </div>
        <div class="stat-box info">
            <div class="stat-label">Zero-Pledge Centers</div>
            <div class="stat-number"><?php echo count($V_zero_pledge_centers) === 3 ? '3+' : count($V_zero_pledge_centers); ?></div>
        </div>
    </div>
</div>
<?php endif; ?>

<?php if ($V_role != 'barangay' || $V_sub_role == 'captain' || $V_sub_role == ''): ?>
<div class="panel-card">
    <div class="panel-header dashboard-chart-header">
        <div>
            <h2>Disaster Type Summary</h2>
            <p><?php echo h($V_chart_scope); ?> · <?php echo h($V_month_names[$V_selected_month]); ?> <?php echo $V_selected_year; ?> · Dismissed reports are excluded.</p>
        </div>

        <form method="GET" class="dashboard-chart-filter">
            <select name="month" class="form-select form-select-sm">
                <?php foreach ($V_month_names as $month_number => $month_name) { ?>
                    <option value="<?php echo $month_number; ?>" <?php echo ($month_number == $V_selected_month) ? 'selected' : ''; ?>>
                        <?php echo h($month_name); ?>
                    </option>
                <?php } ?>
            </select>

            <select name="year" class="form-select form-select-sm">
                <?php for ($year = ((int)date('Y') - 3); $year <= ((int)date('Y') + 1); $year++) { ?>
                    <option value="<?php echo $year; ?>" <?php echo ($year == $V_selected_year) ? 'selected' : ''; ?>>
                        <?php echo $year; ?>
                    </option>
                <?php } ?>
            </select>

            <button type="submit" class="btn btn-emergency btn-sm">View</button>
        </form>
    </div>

    <div class="panel-body">
        <?php if (count($V_chart_rows) > 0) { ?>
            <div class="disaster-chart-wrap">
                <div class="disaster-chart">
                    <div class="disaster-chart-row">
                        <div class="disaster-chart-yaxis">
                            <?php foreach ($V_chart_ticks as $V_tick_value) { ?>
                                <span><?php echo (int)$V_tick_value; ?></span>
                            <?php } ?>
                        </div>
                        <div class="disaster-plot">
                            <?php foreach ($V_chart_rows as $chart) { ?>
                                <?php
                                $V_bar_pct = 0;
                                if ($V_chart_ceiling > 0) {
                                    $V_bar_pct = ($chart['total'] / $V_chart_ceiling) * 100;
                                }
                                if ($chart['total'] > 0 && $V_bar_pct < 3) {
                                    $V_bar_pct = 3;
                                }
                                ?>
                                <div class="disaster-column">
                                    <div class="disaster-column-fill" style="height: <?php echo round($V_bar_pct, 1); ?>%;">
                                        <span class="disaster-column-count"><?php echo (int)$chart['total']; ?></span>
                                    </div>
                                </div>
                            <?php } ?>
                        </div>
                    </div>
                    <div class="disaster-chart-row labels-row">
                        <div class="disaster-chart-yaxis-spacer"></div>
                        <div class="disaster-labels">
                            <?php foreach ($V_chart_rows as $chart) { ?>
                                <div class="disaster-label-col"><?php echo disaster_type_badge($chart['disaster_type']); ?></div>
                            <?php } ?>
                        </div>
                    </div>
                </div>
            </div>
        <?php } else { ?>
            <div class="empty-state">No disaster types found.</div>
        <?php } ?>
    </div>
</div>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Report Status Breakdown</h2>
            <p><?php echo h($V_chart_scope); ?> · <?php echo h($V_month_names[$V_selected_month]); ?> <?php echo $V_selected_year; ?> · What needs action vs. handled.</p>
        </div>
    </div>

    <div class="panel-body">
        <?php if (count($V_status_rows) > 0) { ?>
            <?php
            $V_status_colors = [
                'Pending' => '#f59e0b',
                'Verified' => '#0d6efd',
                'Responding' => '#6f42c1',
                'Referred to PHO' => '#d63384',
                'Under PHO Review' => '#fd7e14',
                'Resolved' => '#198754',
            ];
            ?>
            <div class="status-list">
                <?php foreach ($V_status_rows as $status_row) { ?>
                    <?php
                    $V_status_pct = 0;
                    if ($V_status_ceiling > 0) {
                        $V_status_pct = ($status_row['total'] / $V_status_ceiling) * 100;
                    }
                    if ($status_row['total'] > 0 && $V_status_pct < 3) {
                        $V_status_pct = 3;
                    }
                    $V_status_color = $V_status_colors[$status_row['status']] ?? '#6c757d';
                    ?>
                    <div class="status-item">
                        <div class="status-name"><?php echo h(status_display($status_row['status'])); ?></div>
                        <div class="status-track">
                            <div class="status-fill" style="width: <?php echo round($V_status_pct, 1); ?>%; background: <?php echo $V_status_color; ?>;"></div>
                        </div>
                        <div class="status-count"><?php echo (int)$status_row['total']; ?></div>
                    </div>
                <?php } ?>
            </div>
            <div class="status-axis">
                <?php foreach ($V_status_ticks as $V_status_tick) { ?>
                    <span><?php echo (int)$V_status_tick; ?></span>
                <?php } ?>
            </div>
        <?php } else { ?>
            <div class="empty-state">No reports for this month.</div>
        <?php } ?>
    </div>
</div>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Human Impact</h2>
            <p><?php echo h($V_chart_scope); ?> · <?php echo h($V_month_names[$V_selected_month]); ?> <?php echo $V_selected_year; ?> · Total people affected this month.</p>
        </div>
    </div>

    <div class="panel-body">
        <div class="impact-grid">
            <div class="impact-box">
                <div class="impact-label">Affected</div>
                <div class="impact-number"><?php echo (int)$V_impact['affected']; ?></div>
            </div>
            <div class="impact-box">
                <div class="impact-label">Injured</div>
                <div class="impact-number"><?php echo (int)$V_impact['injured']; ?></div>
            </div>
            <div class="impact-box">
                <div class="impact-label">Dead</div>
                <div class="impact-number"><?php echo (int)$V_impact['dead']; ?></div>
            </div>
            <div class="impact-box">
                <div class="impact-label">Missing</div>
                <div class="impact-number"><?php echo (int)$V_impact['missing']; ?></div>
            </div>
        </div>
    </div>
</div>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Daily Report Trend</h2>
            <p><?php echo h($V_chart_scope); ?> · <?php echo h($V_month_names[$V_selected_month]); ?> <?php echo $V_selected_year; ?> · Reports per day (spot the spikes).</p>
        </div>
    </div>

    <div class="panel-body">
        <?php if ($V_trend_max > 0) { ?>
            <div class="disaster-chart-wrap">
                <div style="min-width: 640px;">
                    <div class="trend-row">
                        <div class="trend-yaxis">
                            <?php foreach ($V_trend_ticks as $V_trend_tick) { ?>
                                <span><?php echo (int)$V_trend_tick; ?></span>
                            <?php } ?>
                        </div>
                        <div class="trend-plot">
                            <?php for ($V_day = 1; $V_day <= $V_days_in_month; $V_day++) { ?>
                                <?php
                                $V_trend_pct = 0;
                                if ($V_trend_ceiling > 0) {
                                    $V_trend_pct = ($V_trend_counts[$V_day] / $V_trend_ceiling) * 100;
                                }
                                if ($V_trend_counts[$V_day] > 0 && $V_trend_pct < 3) {
                                    $V_trend_pct = 3;
                                }
                                ?>
                                <div class="trend-bar-wrap" title="Day <?php echo $V_day; ?>: <?php echo (int)$V_trend_counts[$V_day]; ?> report(s)">
                                    <div class="trend-bar" style="height: <?php echo round($V_trend_pct, 1); ?>%;"></div>
                                </div>
                            <?php } ?>
                        </div>
                    </div>
                    <div class="trend-labels">
                        <span>Day 1</span>
                        <span>Day <?php echo (int)ceil($V_days_in_month / 2); ?></span>
                        <span>Day <?php echo $V_days_in_month; ?></span>
                    </div>
                </div>
            </div>
        <?php } else { ?>
            <div class="empty-state">No reports for this month.</div>
        <?php } ?>
    </div>
</div>
<?php endif; ?>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Recent Incident Reports</h2>
            <p>Recent reports based on your account role.</p>
        </div>
        <?php if ($V_role == 'barangay' && ($V_sub_role == 'captain' || $V_sub_role == 'tanod')) { ?>
            <a class="btn btn-emergency btn-sm" href="create-incident-report.php">Create Report</a>
        <?php } elseif ($V_role == 'pcf' && !is_readonly_role($V_role, $V_sub_role)) { ?>
            <a class="btn btn-emergency btn-sm" href="review-reports.php">Review Reports</a>
        <?php } elseif ($V_role == 'pho') { ?>
            <a class="btn btn-emergency btn-sm" href="health-reports.php">Provincial Reports</a>
        <?php } elseif ($V_role == 'superadmin') { ?>
            <a class="btn btn-emergency btn-sm" href="manage-users.php">Manage Users</a>
        <?php } ?>
    </div>

    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Report No.</th>
                    <th>Date</th>
                    <th><?php echo ($V_role === 'barangay') ? 'By' : 'Barangay'; ?></th>
                    <th>Disaster</th>
                    <th>Affected</th>
                    <th>Injured</th>
                    <th>Dead</th>
                    <th>Missing</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($LatestResult && mysqli_num_rows($LatestResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($LatestResult)) { ?>
                        <tr>
                            <td><?php echo report_number($row['id'], $row['created_at']); ?></td>
                            <td><?php echo date('M d, Y h:i A', strtotime($row['created_at'])); ?></td>
                            <td><strong><?php echo ($V_role === 'barangay') ? h($row['creator_name'] ?? 'Unknown') : h($row['barangay_name']); ?></strong></td>
                            <td><?php echo disaster_type_badge($row['disaster_type']); ?></td>
                            <td><?php echo (int)$row['affected_people']; ?></td>
                            <td><?php echo (int)$row['injured']; ?></td>
                            <td><?php echo (int)$row['dead']; ?></td>
                            <td><?php echo (int)$row['missing']; ?></td>
                            <td>
                                <span class="soft-badge <?php echo status_class($row['status']); ?>"><?php echo h(status_display($row['status'])); ?></span>
                                <?php if (!empty($row['pin_outside_area'] ?? 0)) { ?>
                                    <span class="soft-badge badge-soft-warning" title="The reported pin is outside the barangay boundary and was flagged for review.">Pin Outside</span>
                                <?php } ?>
                            </td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr>
                        <td colspan="9" class="empty-state">No incident reports found.</td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<?php include "../app/includes/footer.php"; ?>
