<?php
$V_page_title = "Evacuation Centers";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_role = $_SESSION['role'];
$V_sub_role = $_SESSION['sub_role'] ?? '';
$CanManageData = can_manage_evacuation_centers($V_role, $V_sub_role);
$V_where = "WHERE 1=1";
$V_bind_types = "";
$V_params = [];

if ($V_role == 'barangay') {
    $V_barangay_name = $_SESSION['barangay_name'];
    if ($CanManageData) {
        // Chairman manages ALL of their barangay's centers.
        $V_where .= " AND evacuation_centers.barangay = ?";
    } else {
        $V_where .= " AND evacuation_centers.barangay = ? AND evacuation_centers.status IN ('Available', 'Open')";
    }
    $V_bind_types .= "s";
    $V_params[] = $V_barangay_name;
    // Scope by the barangay's municipality to prevent cross-municipality name collisions
    $muni_stmt = mysqli_prepare($connection, "SELECT municipality FROM barangays WHERE name = ? LIMIT 1");
    if ($muni_stmt) {
        mysqli_stmt_bind_param($muni_stmt, "s", $V_barangay_name);
        mysqli_stmt_execute($muni_stmt);
        $muni_result = mysqli_stmt_get_result($muni_stmt);
        if ($muni_row = mysqli_fetch_assoc($muni_result)) {
            $V_where .= " AND evacuation_centers.municipality = ?";
            $V_bind_types .= "s";
            $V_params[] = $muni_row['municipality'];
        }
    }
}

// Municipality filter for admin roles (direct column filter, forces muni for MDR sub-roles)
if (is_admin_role($V_role)) {
    $V_ec_filter_muni = get_effective_municipality($V_role, $V_sub_role ?? '');
    if ($V_ec_filter_muni) {
        $V_where .= " AND evacuation_centers.municipality = ?";
        $V_bind_types .= "s";
        $V_params[] = $V_ec_filter_muni;
    }
}

$CenterQuery = "SELECT evacuation_centers.* FROM evacuation_centers $V_where ORDER BY evacuation_centers.barangay ASC, evacuation_centers.center_name ASC";
$CenterStmt = mysqli_prepare($connection, $CenterQuery);

if ($V_bind_types != '') {
    mysqli_stmt_bind_param($CenterStmt, $V_bind_types, ...$V_params);
}

mysqli_stmt_execute($CenterStmt);
$CenterResult = mysqli_stmt_get_result($CenterStmt);

$V_statuses = ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];
?>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Evacuation Centers</h2>
            <?php if ($V_role == 'barangay' && !$CanManageData) { ?>
                <p>Available/open centers from your barangay only.</p>
            <?php } elseif ($V_role == 'barangay') { ?>
                <p>Manage your barangay's evacuation centers.</p>
            <?php } else { ?>
                <p>Manage evacuation centers across barangays.</p>
            <?php } ?>
        </div>

        <?php if ($CanManageData) { ?>
            <a href="add-evacuation-center.php" class="btn btn-emergency">Add Evacuation Center</a>
        <?php } ?>
    </div>

    <?php if (isset($_GET['created'])) { ?><div class="alert alert-success py-2">Evacuation center added successfully.</div><?php } ?>
    <?php if (isset($_GET['updated'])) { ?><div class="alert alert-success py-2">Evacuation center updated successfully.</div><?php } ?>
    <?php if (isset($_GET['deleted'])) { ?><div class="alert alert-success py-2">Evacuation center deleted successfully.</div><?php } ?>
    <?php if (isset($_GET['denied'])) { ?><div class="alert alert-danger py-2">Access denied.</div><?php } ?>

    <div class="filter-bar" id="evacFilterBar">
        <input type="text" id="evacSearch" class="form-control" placeholder="Search barangay or center name...">
        <?php if ($V_role != 'barangay' || $CanManageData) { ?>
        <select id="evacStatusFilter" class="form-select">
            <option value="">All statuses</option>
            <?php foreach ($V_statuses as $s) { ?>
                <option class="ec-status-<?php echo h(strtolower(str_replace(' ', '-', $s))); ?>" value="<?php echo h(strtolower($s)); ?>"><?php echo h($s); ?></option>
            <?php } ?>
        </select>
        <?php } ?>
        <button type="button" class="btn btn-light border" onclick="resetEvacFilters()">Reset</button>
    </div>

    <div class="table-wrap menu-open">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Barangay</th>
                    <th>Center Name</th>
                    <th>Type</th>
                    <th>Capacity</th>
                    <th>Current Evacuees</th>
                    <th>Status</th>
                    <?php if ($CanManageData) { ?><th style="width:90px;">Action</th><?php } ?>
                </tr>
            </thead>
            <tbody>
                <?php if ($CenterResult && mysqli_num_rows($CenterResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($CenterResult)) { ?>
                        <tr class="evac-row"
                            data-search="<?php echo h(strtolower($row['barangay'] . ' ' . $row['center_name'] . ' ' . $row['center_type'])); ?>"
                            data-status="<?php echo h(strtolower($row['status'])); ?>">
                            <td><strong><?php echo h($row['barangay']); ?></strong></td>
                            <td><?php echo h($row['center_name']); ?></td>
                            <td><?php echo h($row['center_type'] ?: '-'); ?></td>
                            <td><?php echo (int)$row['capacity']; ?></td>
                            <td><?php echo (int)$row['current_evacuees']; ?></td>
                            <td><span class="soft-badge <?php echo h(center_status_badge_class($row['status'])); ?>"><?php echo h($row['status']); ?></span></td>
                            <?php if ($CanManageData) { ?>
                                <td class="text-nowrap">
                                    <div class="dropdown">
                                        <button class="btn btn-sm btn-dark dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                            Action
                                        </button>
                                        <ul class="dropdown-menu dropdown-menu-end">
                                            <li>
                                                <a class="dropdown-item" href="center-needs.php?id=<?php echo (int)$row['id']; ?>">
                                                    Needs &amp; Assistance
                                                </a>
                                            </li>
                                            <li>
                                                <a class="dropdown-item" href="edit-evacuation-center.php?id=<?php echo (int)$row['id']; ?>">
                                                    Edit
                                                </a>
                                            </li>
                                            <li>
                                                <form method="post" action="../app/evacuation-centers/delete-evacuation-center.php" class="m-0" onsubmit="return confirm('Delete this evacuation center?');">
                                                    <?php echo csrf_field(); ?>
                                                    <input type="hidden" name="id" value="<?php echo (int)$row['id']; ?>">
                                                    <button type="submit" class="dropdown-item text-danger">Delete</button>
                                                </form>
                                            </li>
                                        </ul>
                                    </div>
                                </td>
                            <?php } ?>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr>
                        <td colspan="<?php echo $CanManageData ? 7 : 6; ?>" class="empty-state">No evacuation center found.</td>
                    </tr>
                <?php } ?>
                <tr id="noEvacMatchRow" style="display:none;">
                    <td colspan="<?php echo $CanManageData ? 7 : 6; ?>" class="empty-state">No matching evacuation centers.</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

<script>
function runEvacFilter() {
    var query  = document.getElementById('evacSearch').value.toLowerCase().trim();
    var statusEl = document.getElementById('evacStatusFilter');
    var status = statusEl ? statusEl.value.toLowerCase() : '';
    var rows   = document.querySelectorAll('.evac-row');
    var visible = 0;

    rows.forEach(function(row) {
        var rowSearch = row.getAttribute('data-search') || '';
        var rowStatus = row.getAttribute('data-status') || '';
        var matchQuery  = !query  || rowSearch.includes(query);
        var matchStatus = !status || rowStatus === status;
        var show = matchQuery && matchStatus;
        row.style.display = show ? '' : 'none';
        if (show) visible++;
    });

    var noMatch = document.getElementById('noEvacMatchRow');
    if (noMatch) noMatch.style.display = (visible === 0) ? '' : 'none';
}

function resetEvacFilters() {
    document.getElementById('evacSearch').value = '';
    var statusEl = document.getElementById('evacStatusFilter');
    if (statusEl) statusEl.value = '';
    runEvacFilter();
}

document.getElementById('evacSearch').addEventListener('input', runEvacFilter);
var evacStatusEl = document.getElementById('evacStatusFilter');
if (evacStatusEl) evacStatusEl.addEventListener('change', runEvacFilter);
</script>

<?php include "../app/includes/footer.php"; ?>
