<?php
$V_page_title = "Incident Reports";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

$V_role = $_SESSION['role'];
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_barangay_id = (int)($_SESSION['barangay_id'] ?? 0);

if ($V_role == 'barangay') {
    $V_page_title = "My Reports";
} elseif ($V_role == 'pcf') {
    $V_page_title = "All Incident Reports";
} elseif ($V_role == 'pho') {
    header("Location: health-reports.php");
    exit;
} elseif ($V_role == 'superadmin') {
    $V_page_title = "All Reports";
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

// Keep role-scoping WHERE but remove status/search — those are handled by JS
$V_where = "WHERE 1=1";
$V_bind_types = "";
$V_params = [];

if ($V_role == 'barangay') {
    $V_where .= " AND incident_reports.barangay_id = ?";
    $V_bind_types .= "i";
    $V_params[] = $V_barangay_id;
    if ($V_sub_role === 'tanod') {
        $V_user_id = (int)($_SESSION['user_id'] ?? 0);
        $V_where .= " AND incident_reports.user_id = ?";
        $V_bind_types .= "i";
        $V_params[] = $V_user_id;
    }
}
if ($V_role == 'pcf') {
    $V_where .= " AND incident_reports.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')";
}

// Municipality filter for admin roles (forces municipality for MDR sub-roles)
if (is_admin_role($V_role)) {
    $V_ir_filter_muni = get_effective_municipality($V_role, $V_sub_role);
    if ($V_ir_filter_muni) {
        $V_where .= " AND barangays.municipality = ?";
        $V_bind_types .= "s";
        $V_params[] = $V_ir_filter_muni;
    }
} else {
    $V_ir_filter_muni = null;
}

$ReportQuery = "SELECT incident_reports.*, barangays.name AS barangay_name, barangays.municipality AS barangay_municipality, users.name AS creator_name, evacuation_centers.center_name
                FROM incident_reports
                INNER JOIN barangays ON incident_reports.barangay_id = barangays.id
                LEFT JOIN users ON incident_reports.user_id = users.id
                LEFT JOIN evacuation_centers ON incident_reports.evacuation_center_id = evacuation_centers.id
                $V_where
                ORDER BY incident_reports.created_at DESC";
$ReportStmt = mysqli_prepare($connection, $ReportQuery);

if ($V_bind_types != '') {
    mysqli_stmt_bind_param($ReportStmt, $V_bind_types, ...$V_params);
}

mysqli_stmt_execute($ReportStmt);
$ReportResult = mysqli_stmt_get_result($ReportStmt);

$V_statuses = ['Pending', 'Reviewed', 'Forwarded to PCF', 'Verified', 'Responding', 'Referred to PHO', 'Resolved', 'Dismissed'];
// Municipal acts on the intermediate MDR/PHO stages, so only they see them as filters.
if (can_manage_status($V_role)) {
    $V_statuses = ['Pending', 'Reviewed', 'Forwarded to PCF', 'Under MDR Review', 'Verified', 'Responding', 'Under PHO Review', 'Referred to PHO', 'Resolved', 'Dismissed'];
}

// Disaster types from DB — always in sync with active types.
$V_types_result = mysqli_query($connection, "SELECT name FROM disaster_types WHERE status = 'Active' ORDER BY id ASC");
$V_types_list = [];
if ($V_types_result) {
    while ($V_trow = mysqli_fetch_assoc($V_types_result)) {
        $V_types_list[] = $V_trow['name'];
    }
}

$V_modal_html = '';

if (!function_exists('report_number')) {
    function report_number($id, $created_at) {
        $year = date('Y', strtotime($created_at));
        return $year . '-' . str_pad((int)$id, 4, '0', STR_PAD_LEFT);
    }
}

// Mayor-only municipality evidence card (read-only decision support). Reuses
// the Governor evidence aggregator scoped to the mayor's municipality, which
// produces a per-barangay breakdown instead of the province-wide one.
$V_mayor_evidence = null;
$V_mayor_muni = mayor_municipality($V_role, $V_sub_role);
if ($V_mayor_muni !== null) {
    $V_mayor_evidence = governor_province_evidence($connection, (int)date('n'), (int)date('Y'), $V_mayor_muni);
}
?>
<style>
.report-date {
    white-space: nowrap;
    min-width: 150px;
}
.report-no {
    white-space: nowrap;
}
.report-action-cell {
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

.report-table-wrap {
    overflow: visible !important;
    padding-bottom: 130px;
}

.report-action-cell .dropdown-menu {
    z-index: 3000;
}

@media (max-width: 992px) {
    .report-table-wrap {
        overflow-x: auto !important;
        padding-bottom: 130px;
    }
}
</style>

<?php if ($V_mayor_evidence !== null) { ?>
    <?php $V_mev_month = date('F Y', mktime(0, 0, 0, $V_mayor_evidence['month'], 1, $V_mayor_evidence['year'])); ?>
    <div class="panel-card" id="mayorEvidence">
        <div class="panel-header">
            <div>
                <h2 style="color: #0d6efd;"><?php echo h($V_mayor_muni); ?> Evidence</h2>
                <p><?php echo h($V_mev_month); ?> &middot; <?php echo h($V_mayor_muni); ?> municipality only &middot; All referral statuses &middot; Dismissed reports excluded.</p>
            </div>
        </div>

        <div class="row g-3 px-3 pb-2">
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-primary"><?php echo (int)$V_mayor_evidence['total_reports']; ?></div>
                    <div class="text-muted small">Active Incidents</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-danger"><?php echo (int)($V_mayor_evidence['impact']['affected'] ?? 0); ?></div>
                    <div class="text-muted small">Affected</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-warning"><?php echo (int)($V_mayor_evidence['impact']['injured'] ?? 0); ?></div>
                    <div class="text-muted small">Injured</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-dark"><?php echo (int)($V_mayor_evidence['impact']['dead'] ?? 0); ?></div>
                    <div class="text-muted small">Dead</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-secondary"><?php echo (int)($V_mayor_evidence['impact']['missing'] ?? 0); ?></div>
                    <div class="text-muted small">Missing</div>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <div class="panel-card p-3 text-center">
                    <div class="fs-4 fw-bold text-success"><?php echo (int)$V_mayor_evidence['evac_total']; ?></div>
                    <div class="text-muted small">Evacuation Centers</div>
                </div>
            </div>
        </div>

        <div class="row g-4 px-3 pb-3">
            <div class="col-md-6">
                <div class="mb-1 fw-semibold">Active Incidents by Disaster Type</div>
                <div>
                    <?php foreach ($V_mayor_evidence['disaster_summary'] as $V_dt => $V_dc) { ?>
                        <?php if ($V_dc > 0) { ?>
                            <span class="badge bg-light border text-dark me-1 mb-1"><?php echo h($V_dt); ?> &times; <?php echo (int)$V_dc; ?></span>
                        <?php } ?>
                    <?php } ?>
                    <?php if ((int)$V_mayor_evidence['total_reports'] === 0) { ?>
                        <span class="text-muted small">No active incidents this month.</span>
                    <?php } ?>
                </div>
            </div>
            <div class="col-md-6">
                <div class="mb-1 fw-semibold">Evacuation Centers by Status</div>
                <div>
                    <?php foreach (['Open', 'Available', 'Needs Supplies', 'Full', 'Closed'] as $V_es) { ?>
                        <span class="badge bg-light border text-dark me-1 mb-1"><?php echo h($V_es); ?> &times; <?php echo (int)($V_mayor_evidence['evac_status_summary'][$V_es] ?? 0); ?></span>
                    <?php } ?>
                </div>
            </div>
        </div>

        <?php if (!empty($V_mayor_evidence['barangay_summary'])) { ?>
            <div class="table-wrap pb-0 px-3">
                <div class="mb-1 fw-semibold">Per Barangay</div>
                <table class="table table-bordered table-hover custom-table">
                    <thead>
                        <tr>
                            <th>Barangay</th>
                            <th>Incidents</th>
                            <th>Affected</th>
                            <th>Urgency</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($V_mayor_evidence['barangay_summary'] as $V_br) { ?>
                            <?php
                            $V_urg = $V_br['urgency'];
                            $V_urg_badge = match ($V_urg) {
                                'high' => 'badge-soft-danger',
                                'elevated' => 'badge-soft-warning',
                                default => 'badge-soft-success',
                            };
                            $V_urg_label = ucfirst($V_urg);
                            ?>
                            <tr>
                                <td><strong><?php echo h($V_br['barangay']); ?></strong></td>
                                <td><?php echo (int)$V_br['incident_count']; ?></td>
                                <td><?php echo (int)$V_br['affected']; ?></td>
                                <td><span class="soft-badge <?php echo h($V_urg_badge); ?>"><?php echo h($V_urg_label); ?></span></td>
                            </tr>
                        <?php } ?>
                    </tbody>
                </table>
            </div>
        <?php } ?>

        <?php $V_at_risk = array_values(array_filter($V_mayor_evidence['evac_over_capacity'], function ($V_oc) { return (int)$V_oc['at_risk_count'] > 0; })); ?>
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
            <h2><?php echo h($V_page_title); ?></h2>
            <?php if ($V_role == 'barangay') { ?>
                <p>Reports submitted by your barangay account only.</p>
            <?php } else { ?>
                <p>Simple list of incident reports from barangay accounts.</p>
            <?php } ?>
        </div>
        <?php if ($V_role == 'barangay' && ($_SESSION['sub_role'] ?? '') !== 'secretary') { ?>
            <a class="btn btn-emergency btn-sm" href="create-incident-report.php">Create Report</a>
        <?php } ?>
    </div>

    <?php if (isset($_GET['created'])) { ?>
        <div class="alert alert-success mx-3 mt-3 py-2">Incident report created.</div>
    <?php } ?>

    <?php if (isset($_GET['updated'])) { ?>
        <div class="alert alert-success mx-3 mt-3 py-2">Status updated.</div>
    <?php } ?>

    <?php if (isset($_GET['locked'])) { ?>
        <div class="alert alert-warning mx-3 mt-3 py-2">That report can no longer be edited because it is already being processed.</div>
    <?php } ?>

    <div class="filter-bar" id="incidentFilterBar">
        <input type="text" id="incidentSearch" class="form-control" placeholder="Search barangay, disaster, description...">
        <select id="incidentStatusFilter" class="form-select">
            <option value="">All statuses</option>
            <?php foreach ($V_statuses as $s) { ?>
                <option value="<?php echo h($s); ?>"><?php echo h(status_display($s)); ?></option>
            <?php } ?>
        </select>
        <select id="incidentTypeFilter" class="form-select">
            <option value="">All types</option>
            <?php foreach ($V_types_list as $t) { ?>
                <option value="<?php echo h($t); ?>"><?php echo h($t); ?></option>
            <?php } ?>
        </select>
        <select id="incidentRoadFilter" class="form-select">
            <option value="">All road status</option>
            <option value="obstructed">Obstructed</option>
            <option value="partially passable">Partially Passable</option>
            <option value="passable">Passable</option>
        </select>
        <select id="incidentDateFilter" class="form-select">
            <option value="">All time</option>
            <option value="today">Today</option>
            <option value="7">Last 7 days</option>
            <option value="30">Last 30 days</option>
        </select>
        <button type="button" class="btn btn-light border" onclick="resetIncidentFilters()">Reset</button>
    </div>

    <div class="table-wrap report-table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Report No.</th>
                    <th>Date</th>
                    <th><?php echo ($V_role === 'barangay') ? 'By' : 'Barangay'; ?></th>                    <th>Disaster</th>
                    <th>Affected</th>
                    <th>Injured</th>
                    <th>Dead</th>
                    <th>Missing</th>
                    <th>Evacuation</th>
                    <th>Road Access</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($ReportResult && mysqli_num_rows($ReportResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($ReportResult)) { ?>
                        <?php
                        $V_modal_id = 'reportModal' . (int)$row['id'];
                        $V_modal_html .= get_incident_detail_modal($connection, $row, $V_modal_id);
                        ?>
                        <tr class="report-row"
                            data-search="<?php echo h(strtolower($row['barangay_name'] . ' ' . $row['disaster_type'] . ' ' . $row['description'])); ?>"
                            data-status="<?php echo h(strtolower($row['status'])); ?>"
                            data-type="<?php echo h(strtolower($row['disaster_type'])); ?>"
                            data-road="<?php echo h(strtolower($row['road_status'] ?? 'Passable')); ?>"
                            data-date="<?php echo date('Y-m-d', strtotime($row['created_at'])); ?>">
                            <td class="report-no"><?php echo report_number($row['id'], $row['created_at']); ?></td>
                            <td class="report-date"><?php echo date('M d, Y h:i A', strtotime($row['created_at'])); ?></td>
                            <td><strong><?php echo ($V_role === 'barangay') ? h($row['creator_name'] ?? 'Unknown') : h($row['barangay_name']); ?></strong></td>
                            <td><?php echo disaster_type_badge($row['disaster_type']); ?></td>
                            <td><?php echo (int)$row['affected_people']; ?></td>
                            <td><?php echo (int)$row['injured']; ?></td>
                            <td><?php echo (int)$row['dead']; ?></td>
                            <td><?php echo (int)$row['missing']; ?></td>
                            <td>
                                <?php echo h($row['evacuation_needed']); ?>
                                <?php if ($row['center_name'] != '') { ?>
                                    <br><small class="text-muted"><?php echo h($row['center_name']); ?></small>
                                <?php } ?>
                            </td>
                            <td>
                                <?php $V_road_status = $row['road_status'] ?? 'Passable'; ?>
                                <span class="soft-badge <?php echo road_status_class($V_road_status); ?>"><?php echo h($V_road_status); ?></span>
                            </td>
                            <td>
                                <span class="soft-badge <?php echo status_class($row['status']); ?>"><?php echo h(status_display($row['status'])); ?></span>
                                <?php if (!empty($row['pin_outside_area'] ?? 0)) { ?>
                                    <span class="soft-badge badge-soft-warning" title="The reported pin is outside the barangay boundary and was flagged for review.">Pin Outside</span>
                                <?php } ?>
                            </td>
                            <td class="report-action-cell">
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
                                        <?php if ($V_role === 'barangay' && $V_sub_role === 'captain') { ?>
                                            <?php if ($row['status'] === 'Pending') { ?>
                                                <li><hr class="dropdown-divider"></li>
                                                <li>
                                                    <a class="dropdown-item text-primary" href="edit-incident-report.php?id=<?php echo (int)$row['id']; ?>">Edit</a>
                                                </li>
                                                <li><hr class="dropdown-divider"></li>
                                                <li>
                                                    <form action="../app/reports/update-status.php" method="post" class="m-0">
                                                <?php echo csrf_field(); ?>
                                                        <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                        <input type="hidden" name="status" value="Reviewed">
                                                        <input type="hidden" name="return_page" value="incident-reports.php">
                                                        <input type="hidden" name="remarks" value="Report reviewed by Chairman.">
                                                        <button type="submit" class="dropdown-item text-primary">Review</button>
                                                    </form>
                                                </li>
                                            <?php } ?>
                                            <?php if ($row['status'] === 'Reviewed') { ?>
                                                <li><hr class="dropdown-divider"></li>
                                                <li>
                                                    <form action="../app/reports/update-status.php" method="post" class="m-0">
                                                <?php echo csrf_field(); ?>
                                                        <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                        <input type="hidden" name="status" value="Forwarded to PCF">
                                                        <input type="hidden" name="return_page" value="incident-reports.php">
                                                        <input type="hidden" name="remarks" value="Report forwarded to Municipal for coordination.">
                                                        <button type="submit" class="dropdown-item text-info">Forward to Municipal</button>
                                                    </form>
                                                </li>
                                            <?php } ?>
                                            <?php if (in_array($row['status'], ['Pending', 'Reviewed'])) { ?>
                                                <li><hr class="dropdown-divider"></li>
                                                <li>
                                                    <form action="../app/reports/update-status.php" method="post" class="m-0">
                                                <?php echo csrf_field(); ?>
                                                        <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                        <input type="hidden" name="status" value="Dismissed">
                                                        <input type="hidden" name="return_page" value="incident-reports.php">
                                                        <input type="hidden" name="remarks" value="Report dismissed by Chairman.">
                                                        <button type="submit" class="dropdown-item text-danger">Dismiss</button>
                                                    </form>
                                                </li>
                                            <?php } ?>
                                        <?php } elseif ($V_role === 'barangay' && $row['status'] === 'Pending' && (int)$row['user_id'] === (int)($_SESSION['user_id'] ?? 0)) { ?>
                                                <li><hr class="dropdown-divider"></li>
                                                <li>
                                                    <a class="dropdown-item text-primary" href="edit-incident-report.php?id=<?php echo (int)$row['id']; ?>">Edit</a>
                                                </li>
                                            <?php } elseif (can_manage_status($V_role) && $row['status'] === 'Forwarded to PCF') { ?>
                                            <li><hr class="dropdown-divider"></li>
                                            <li>
                                                <form action="../app/reports/update-status.php" method="post" class="m-0">
                                            <?php echo csrf_field(); ?>
                                                    <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                    <input type="hidden" name="status" value="Under MDR Review">
                                                    <input type="hidden" name="return_page" value="incident-reports.php">
                                                    <input type="hidden" name="remarks" value="Report acknowledged and under MDR review.">
                                                    <button type="submit" class="dropdown-item text-warning">Acknowledge / Start Review</button>
                                                </form>
                                            </li>
                                        <?php } elseif (can_manage_status($V_role) && in_array($row['status'], ['Under MDR Review', 'Verified', 'Responding', 'Referred to PHO'])) { ?>
                                            <li><hr class="dropdown-divider"></li>
                                            <li>
                                                <form action="../app/reports/update-status.php" method="post" class="m-0">
                                            <?php echo csrf_field(); ?>
                                                    <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                    <input type="hidden" name="status" value="Verified">
                                                    <input type="hidden" name="return_page" value="incident-reports.php">
                                                    <input type="hidden" name="remarks" value="Report verified.">
                                                    <button type="submit" class="dropdown-item text-success">Verify</button>
                                                </form>
                                            </li>
                                            <li>
                                                <form action="../app/reports/update-status.php" method="post" class="m-0">
                                            <?php echo csrf_field(); ?>
                                                    <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                    <input type="hidden" name="status" value="Responding">
                                                    <input type="hidden" name="return_page" value="incident-reports.php">
                                                    <input type="hidden" name="remarks" value="Response action started.">
                                                    <button type="submit" class="dropdown-item text-primary">Respond</button>
                                                </form>
                                            </li>
                                            <li>
                                                <form action="../app/reports/update-status.php" method="post" class="m-0">
                                            <?php echo csrf_field(); ?>
                                                    <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                    <input type="hidden" name="status" value="Dismissed">
                                                    <input type="hidden" name="return_page" value="incident-reports.php">
                                                    <input type="hidden" name="remarks" value="Report dismissed.">
                                                    <button type="submit" class="dropdown-item text-danger">Dismiss</button>
                                                </form>
                                            </li>
                                            <li>
                                                <form action="../app/reports/update-status.php" method="post" class="m-0">
                                            <?php echo csrf_field(); ?>
                                                    <input type="hidden" name="report_id" value="<?php echo (int)$row['id']; ?>">
                                                    <input type="hidden" name="status" value="Referred to PHO">
                                                    <input type="hidden" name="return_page" value="incident-reports.php">
                                                    <input type="hidden" name="remarks" value="Report referred to Provincial.">
                                                    <button type="submit" class="dropdown-item text-warning">Send to Provincial</button>
                                                </form>
                                            </li>
                                        <?php } ?>
                                    </ul>
                                </div>
                            </td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr>
                        <td colspan="11" class="empty-state">No incident reports found.</td>
                    </tr>
                <?php } ?>
                <tr id="noReportMatchRow" style="display:none;">
                    <td colspan="11" class="empty-state">No matching incident reports.</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

<?php echo $V_modal_html; ?>

<script>
function runIncidentFilter() {
    var query  = document.getElementById('incidentSearch').value.toLowerCase().trim();
    var status = document.getElementById('incidentStatusFilter').value.toLowerCase();
    var type   = document.getElementById('incidentTypeFilter').value.toLowerCase();
    var road   = document.getElementById('incidentRoadFilter').value.toLowerCase();
    var date   = document.getElementById('incidentDateFilter').value;
    var rows   = document.querySelectorAll('.report-row');
    var now    = new Date();
    var visible = 0;

    rows.forEach(function(row) {
        var rowSearch = row.getAttribute('data-search') || '';
        var rowStatus = row.getAttribute('data-status') || '';
        var rowType   = row.getAttribute('data-type') || '';
        var rowRoad   = row.getAttribute('data-road') || '';
        var rowDate   = row.getAttribute('data-date') || '';

        var matchQuery  = !query  || rowSearch.includes(query);
        var matchStatus = !status || rowStatus === status;
        var matchType   = !type   || rowType.includes(type.toLowerCase());
        var matchRoad   = !road   || rowRoad === road;
        var matchDate   = true;

        if (date && rowDate) {
            var d = new Date(rowDate);
            var diff = Math.floor((now - d) / 86400000);
            if (date === 'today')  matchDate = (diff === 0);
            else if (date === '7')  matchDate = (diff <= 7);
            else if (date === '30') matchDate = (diff <= 30);
        }

        var show = matchQuery && matchStatus && matchType && matchRoad && matchDate;
        row.style.display = show ? '' : 'none';
        if (show) visible++;
    });

    var noMatch = document.getElementById('noReportMatchRow');
    if (noMatch) noMatch.style.display = (visible === 0) ? '' : 'none';
}

function resetIncidentFilters() {
    document.getElementById('incidentSearch').value = '';
    document.getElementById('incidentStatusFilter').value = '';
    document.getElementById('incidentTypeFilter').value = '';
    document.getElementById('incidentRoadFilter').value = '';
    document.getElementById('incidentDateFilter').value = '';
    runIncidentFilter();
}

document.getElementById('incidentSearch').addEventListener('input', runIncidentFilter);
document.getElementById('incidentStatusFilter').addEventListener('change', runIncidentFilter);
document.getElementById('incidentTypeFilter').addEventListener('change', runIncidentFilter);
document.getElementById('incidentRoadFilter').addEventListener('change', runIncidentFilter);
document.getElementById('incidentDateFilter').addEventListener('change', runIncidentFilter);
</script>

<?php include "../app/includes/footer.php"; ?>
