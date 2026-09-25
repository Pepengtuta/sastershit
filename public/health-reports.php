<?php
$V_page_title = "Reports";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include_once "../app/includes/functions.php";

if ($_SESSION['role'] != 'pho' && $_SESSION['role'] != 'superadmin') {
    header("Location: dashboard.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_health_where = "WHERE incident_reports.referred_to_pho = 1";
$V_health_params = [];
$V_health_types = '';
$V_health_municipality = get_effective_municipality($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '');
if ($V_health_municipality !== null && $V_health_municipality !== '') {
    $V_health_where .= " AND barangays.municipality = ?";
    $V_health_params[] = $V_health_municipality;
    $V_health_types .= 's';
}

$ReportQuery = "SELECT incident_reports.*, barangays.name AS barangay_name, barangays.municipality AS barangay_municipality, evacuation_centers.center_name
                FROM incident_reports
                INNER JOIN barangays ON incident_reports.barangay_id = barangays.id
                LEFT JOIN evacuation_centers ON incident_reports.evacuation_center_id = evacuation_centers.id
                $V_health_where
                ORDER BY incident_reports.created_at DESC";
$V_health_stmt = mysqli_prepare($connection, $ReportQuery);
if ($V_health_stmt && !empty($V_health_params)) {
    mysqli_stmt_bind_param($V_health_stmt, $V_health_types, ...$V_health_params);
}
if ($V_health_stmt) {
    mysqli_stmt_execute($V_health_stmt);
    $ReportResult = mysqli_stmt_get_result($V_health_stmt);
} else {
    $ReportResult = false;
}

$V_statuses = ['Pending', 'Verified', 'Responding', 'Under PHO Review', 'Referred to PHO', 'Resolved', 'Dismissed'];
$V_types    = ['Flood', 'Fire', 'Earthquake', 'Accident / Mass Casualty Incident', 'Medical', 'Other'];
$V_modal_html = '';

// Governor-only province-wide evidence card (read-only decision support).
$V_province_evidence = null;
if ($_SESSION['role'] === 'pho' && ($_SESSION['sub_role'] ?? '') === 'governor') {
    $V_province_evidence = governor_province_evidence($connection, (int)date('n'), (int)date('Y'));
}

if (!function_exists('report_number')) {
    function report_number($id, $created_at) {
        $year = date('Y', strtotime($created_at));
        return $year . '-' . str_pad((int)$id, 4, '0', STR_PAD_LEFT);
    }
}
?>

<style>
.health-action-cell {
    white-space: nowrap;
    min-width: 110px;
}
.custom-table th,
.custom-table td {
    vertical-align: middle;
}

/* Allow Bootstrap action dropdowns to show outside the table/card. */
.panel-card,
.table-wrap,
.custom-table,
.custom-table tbody,
.custom-table tr,
.custom-table td {
    overflow: visible !important;
}

.health-table-wrap {
    overflow: visible !important;
    padding-bottom: 130px;
}

.health-action-cell .dropdown-menu {
    z-index: 3000;
}

@media (max-width: 992px) {
    .health-table-wrap {
        overflow-x: auto !important;
        padding-bottom: 130px;
    }
}
</style>

<?php if ($V_province_evidence !== null) { ?>
    <?php $V_ev_month = date('F Y', mktime(0, 0, 0, $V_province_evidence['month'], 1, $V_province_evidence['year'])); ?>
    <div class="panel-card" id="provinceEvidence">
        <div class="panel-header">
            <div>
                <h2 style="color: #0d6efd;">Province-Wide Evidence</h2>
                <p><?php echo h($V_ev_month); ?> &middot; All municipalities &middot; All referral statuses &middot; Dismissed reports excluded.</p>
            </div>
        </div>

        <div class="row g-3 px-3 pb-2">
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-primary"><?php echo (int)$V_province_evidence['total_reports']; ?></div>
                    <div class="text-muted small">Active Incidents</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-danger"><?php echo (int)($V_province_evidence['impact']['affected'] ?? 0); ?></div>
                    <div class="text-muted small">Affected</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-warning"><?php echo (int)($V_province_evidence['impact']['injured'] ?? 0); ?></div>
                    <div class="text-muted small">Injured</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-dark"><?php echo (int)($V_province_evidence['impact']['dead'] ?? 0); ?></div>
                    <div class="text-muted small">Dead</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-secondary"><?php echo (int)($V_province_evidence['impact']['missing'] ?? 0); ?></div>
                    <div class="text-muted small">Missing</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-success"><?php echo (int)$V_province_evidence['evac_total']; ?></div>
                    <div class="text-muted small">Evacuation Centers</div>
                </div>
            </div>
        </div>

        <div class="row g-4 px-3 pb-3">
            <div class="col-md-6">
                <div class="mb-1 fw-semibold">Active Incidents by Disaster Type</div>
                <div>
                    <?php foreach ($V_province_evidence['disaster_summary'] as $V_dt => $V_dc) { ?>
                        <?php if ($V_dc > 0) { ?>
                            <span class="badge bg-light border text-dark me-1 mb-1"><?php echo h($V_dt); ?> &times; <?php echo (int)$V_dc; ?></span>
                        <?php } ?>
                    <?php } ?>
                    <?php if ((int)$V_province_evidence['total_reports'] === 0) { ?>
                        <span class="text-muted small">No active incidents this month.</span>
                    <?php } ?>
                </div>
            </div>
            <div class="col-md-6">
                <div class="mb-1 fw-semibold">Evacuation Centers by Status</div>
                <div>
                    <?php foreach (['Open', 'Available', 'Needs Supplies', 'Full', 'Closed'] as $V_es) { ?>
                        <span class="badge bg-light border text-dark me-1 mb-1"><?php echo h($V_es); ?> &times; <?php echo (int)($V_province_evidence['evac_status_summary'][$V_es] ?? 0); ?></span>
                    <?php } ?>
                </div>
            </div>
        </div>

        <?php if (!empty($V_province_evidence['municipality_summary'])) { ?>
            <div class="table-wrap pb-0 px-3">
                <div class="mb-1 fw-semibold">Per Municipality</div>
                <table class="table table-bordered table-hover custom-table">
                    <thead>
                        <tr>
                            <th>Municipality</th>
                            <th>Incidents</th>
                            <th>Affected</th>
                            <th>Urgency</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($V_province_evidence['municipality_summary'] as $V_mr) { ?>
                            <?php
                            $V_urg = $V_mr['urgency'];
                            $V_urg_badge = match ($V_urg) {
                                'high' => 'badge-soft-danger',
                                'elevated' => 'badge-soft-warning',
                                default => 'badge-soft-success',
                            };
                            $V_urg_label = ucfirst($V_urg);
                            ?>
                            <tr>
                                <td><strong><?php echo h($V_mr['municipality']); ?></strong></td>
                                <td><?php echo (int)$V_mr['incident_count']; ?></td>
                                <td><?php echo (int)$V_mr['affected']; ?></td>
                                <td><span class="soft-badge <?php echo $V_urg_badge; ?>"><?php echo h($V_urg_label); ?></span></td>
                            </tr>
                        <?php } ?>
                    </tbody>
                </table>
            </div>
        <?php } ?>

        <?php $V_at_risk = array_values(array_filter($V_province_evidence['evac_over_capacity'], function ($V_oc) { return (int)$V_oc['at_risk_count'] > 0; })); ?>
        <div class="px-3 pb-3">
            <div class="mb-1 fw-semibold">Shelter Capacity (&gt;80% occupied)</div>
            <?php if (!empty($V_at_risk)) { ?>
                <div class="alert alert-warning py-2 mb-0">
                    <?php foreach ($V_at_risk as $V_oc) { ?>
                        <div><strong><?php echo h($V_oc['municipality']); ?>:</strong> <?php echo (int)$V_oc['at_risk_count']; ?>/<?php echo (int)$V_oc['center_count']; ?> shelters over 80% capacity (<?php echo (int)$V_oc['occupants']; ?> of <?php echo (int)$V_oc['capacity']; ?> persons, <?php echo (int)$V_oc['occupancy_pct']; ?>% occupied).</div>
                    <?php } ?>
                </div>
            <?php } else { ?>
                <div class="alert alert-success py-2 mb-0">No municipal shelters are above the 80% capacity threshold.</div>
            <?php } ?>
        </div>
    </div>
<?php } ?>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Provincial Reports</h2>
            <p>Reports officially referred to Provincial by Municipal. Responding and resolved Provincial reports remain visible here.</p>
        </div>
    </div>

    <?php if (isset($_GET['updated'])) { ?>
        <div class="alert alert-success mx-3 mt-3 py-2">Health report status updated.</div>
    <?php } ?>

    <div class="filter-bar" id="healthFilterBar">
        <input type="text" id="healthSearch" class="form-control" placeholder="Search barangay, disaster, description...">
        <select id="healthStatusFilter" class="form-select">
            <option value="">All statuses</option>
            <?php foreach ($V_statuses as $s) { ?>
                <option value="<?php echo h($s); ?>"><?php echo h(status_display($s)); ?></option>
            <?php } ?>
        </select>
        <select id="healthTypeFilter" class="form-select">
            <option value="">All types</option>
            <?php foreach ($V_types as $t) { ?>
                <option value="<?php echo h($t); ?>"><?php echo h($t); ?></option>
            <?php } ?>
        </select>
        <select id="healthDateFilter" class="form-select">
            <option value="">All time</option>
            <option value="today">Today</option>
            <option value="7">Last 7 days</option>
            <option value="30">Last 30 days</option>
        </select>
        <button type="button" class="btn btn-light border" onclick="resetHealthFilters()">Reset</button>
    </div>

    <div class="table-wrap health-table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Report No.</th>
                    <th>Date</th>
                    <th>Barangay</th>
                    <th>Disaster</th>
                    <th>Injured</th>
                    <th>Dead</th>
                    <th>Missing</th>
                    <th>Evacuation</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($ReportResult && mysqli_num_rows($ReportResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($ReportResult)) { ?>
                        <?php
                        $V_modal_id = 'healthReportModal' . (int)$row['id'];
                        $V_modal_html .= get_incident_detail_modal($connection, $row, $V_modal_id);
                        ?>
                        <tr class="health-row"
                            data-search="<?php echo h(strtolower($row['barangay_name'] . ' ' . $row['disaster_type'] . ' ' . $row['description'])); ?>"
                            data-status="<?php echo h(strtolower($row['status'])); ?>"
                            data-type="<?php echo h(strtolower($row['disaster_type'])); ?>"
                            data-date="<?php echo date('Y-m-d', strtotime($row['created_at'])); ?>">
                            <td><?php echo report_number($row['id'], $row['created_at']); ?></td>
                            <td style="white-space: nowrap; min-width: 160px;"><?php echo date('M d, Y h:i A', strtotime($row['created_at'])); ?></td>
                            <td><strong><?php echo h($row['barangay_name']); ?></strong></td>
                            <td><?php echo h($row['disaster_type']); ?></td>
                            <td><?php echo (int)$row['injured']; ?></td>
                            <td><?php echo (int)$row['dead']; ?></td>
                            <td><?php echo (int)$row['missing']; ?></td>
                            <td>
                                <?php echo h($row['evacuation_needed']); ?>
                                <?php if ($row['center_name'] != '') { ?>
                                    <br><small class="text-muted"><?php echo h($row['center_name']); ?></small>
                                <?php } ?>
                            </td>
                            <td><span class="soft-badge <?php echo status_class($row['status']); ?>"><?php echo h(status_display($row['status'])); ?></span></td>
                            <td class="health-action-cell">
                                <?php if ($_SESSION['role'] == 'pho' && !is_readonly_role($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '')) { ?>
                                    <div class="dropdown">
                                        <button class="btn btn-sm btn-dark dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                            Action
                                        </button>
                                        <ul class="dropdown-menu dropdown-menu-end">
                                            <li>
                                                <button class="dropdown-item" type="button" data-bs-toggle="modal" data-bs-target="#<?php echo h($V_modal_id); ?>">
                                                    View Details
                                                </button>
                                            </li>
                                            <li><hr class="dropdown-divider"></li>
                                            <?php if ($row['status'] === 'Referred to PHO' || $row['status'] === 'Forwarded to PHO') { ?>
                                                <li>
                                                    <form action="../app/reports/update-status.php" method="post" class="m-0">
                    <?php echo csrf_field(); ?>
                                                        <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                        <input type="hidden" name="status" value="Under PHO Review">
                                                        <input type="hidden" name="return_page" value="health-reports.php">
                                                        <input type="hidden" name="remarks" value="Provincial acknowledged this referred report.">
                                                        <button type="submit" class="dropdown-item text-warning">Acknowledge / Start Review</button>
                                                    </form>
                                                </li>
                                            <?php } else { ?>
                                                <li>
                                                    <form action="../app/reports/update-status.php" method="post" class="m-0">
                    <?php echo csrf_field(); ?>
                                                        <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                        <input type="hidden" name="status" value="Responding">
                                                        <input type="hidden" name="return_page" value="health-reports.php">
                                                        <input type="hidden" name="remarks" value="Provincial is responding to this referred report.">
                                                        <button type="submit" class="dropdown-item text-primary">Respond</button>
                                                    </form>
                                                </li>
                                                <li>
                                                    <form action="../app/reports/update-status.php" method="post" class="m-0">
                    <?php echo csrf_field(); ?>
                                                        <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                        <input type="hidden" name="status" value="Resolved">
                                                        <input type="hidden" name="return_page" value="health-reports.php">
                                                        <input type="hidden" name="remarks" value="Provincial marked this referred report as resolved.">
                                                        <button type="submit" class="dropdown-item text-success">Resolve</button>
                                                    </form>
                                                </li>
                                            <?php } ?>
                                        </ul>
                                    </div>
                                <?php } else { ?>
                                    <button class="btn btn-sm btn-outline-dark" type="button" data-bs-toggle="modal" data-bs-target="#<?php echo h($V_modal_id); ?>">View</button>
                                <?php } ?>
                            </td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr>
                        <td colspan="10" class="empty-state">No Provincial reports found.</td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<?php echo $V_modal_html; ?>

<script>
function runHealthFilter() {
    var query  = document.getElementById('healthSearch').value.toLowerCase().trim();
    var status = document.getElementById('healthStatusFilter').value.toLowerCase();
    var type   = document.getElementById('healthTypeFilter').value.toLowerCase();
    var date   = document.getElementById('healthDateFilter').value;
    var rows   = document.querySelectorAll('.health-row');
    var now    = new Date();
    var visible = 0;

    rows.forEach(function(row) {
        var rowSearch = row.getAttribute('data-search') || '';
        var rowStatus = row.getAttribute('data-status') || '';
        var rowType   = row.getAttribute('data-type') || '';
        var rowDate   = row.getAttribute('data-date') || '';

        var matchQuery  = !query  || rowSearch.includes(query);
        var matchStatus = !status || rowStatus === status;
        var matchType   = !type   || rowType.includes(type.toLowerCase());
        var matchDate   = true;

        if (date && rowDate) {
            var d = new Date(rowDate);
            var diff = Math.floor((now - d) / 86400000);
            if (date === 'today')  matchDate = (diff === 0);
            else if (date === '7')  matchDate = (diff <= 7);
            else if (date === '30') matchDate = (diff <= 30);
        }

        var show = matchQuery && matchStatus && matchType && matchDate;
        row.style.display = show ? '' : 'none';
        if (show) visible++;
    });

    var noMatch = document.getElementById('healthNoMatch');
    if (noMatch) noMatch.style.display = (visible === 0) ? '' : 'none';
}

function resetHealthFilters() {
    document.getElementById('healthSearch').value = '';
    document.getElementById('healthStatusFilter').value = '';
    document.getElementById('healthTypeFilter').value = '';
    document.getElementById('healthDateFilter').value = '';
    runHealthFilter();
}

document.getElementById('healthSearch').addEventListener('input', runHealthFilter);
document.getElementById('healthStatusFilter').addEventListener('change', runHealthFilter);
document.getElementById('healthTypeFilter').addEventListener('change', runHealthFilter);
document.getElementById('healthDateFilter').addEventListener('change', runHealthFilter);
</script>

<?php include "../app/includes/footer.php"; ?>
