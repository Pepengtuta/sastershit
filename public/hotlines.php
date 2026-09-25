<?php
$V_page_title = "Emergency Hotlines";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_role = $_SESSION['role'];
$CanManageData = can_manage_hotlines($V_role);

$V_search = trim($_GET['search'] ?? '');
$V_scope_filter = trim($_GET['scope'] ?? 'All');
$V_category_filter = trim($_GET['category'] ?? 'All');

$AllowedScopes = ['All', 'Municipal', 'Barangay'];
$AllowedCategories = ['All', 'Barangay', 'Municipal', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];

if (!in_array($V_scope_filter, $AllowedScopes)) {
    $V_scope_filter = 'All';
}

if (!in_array($V_category_filter, $AllowedCategories)) {
    $V_category_filter = 'All';
}

$V_where = "WHERE 1=1";
$V_bind_types = "";
$V_params = [];

if (!$CanManageData) {
    $V_where .= " AND emergency_hotlines.status = ?";
    $V_bind_types .= "s";
    $V_params[] = "Active";
}

// Municipality filter for admin roles
if (is_admin_role($V_role)) {
    $V_hl_filter_muni = get_filter_municipality();
    if ($V_hl_filter_muni) {
        $V_where .= " AND (emergency_hotlines.municipality = ? OR (emergency_hotlines.municipality IS NULL AND emergency_hotlines.hotline_scope = 'Municipal'))";
        $V_bind_types .= "s";
        $V_params[] = $V_hl_filter_muni;
    }
}

$HotlineQuery = "SELECT emergency_hotlines.*, barangays.name AS barangay_name
                 FROM emergency_hotlines
                 LEFT JOIN barangays ON emergency_hotlines.barangay_id = barangays.id
                 $V_where
                 ORDER BY emergency_hotlines.hotline_scope ASC,
                          emergency_hotlines.municipality ASC,
                          barangays.name ASC,
                          emergency_hotlines.category ASC,
                          emergency_hotlines.office_name ASC";

$HotlineStmt = mysqli_prepare($connection, $HotlineQuery);

if ($V_bind_types != '') {
    mysqli_stmt_bind_param($HotlineStmt, $V_bind_types, ...$V_params);
}

mysqli_stmt_execute($HotlineStmt);
$HotlineResult = mysqli_stmt_get_result($HotlineStmt);

function hotline_area_text($row) {
    if (($row['hotline_scope'] ?? '') == 'Barangay') {
        return $row['barangay_name'] ?: '-';
    }

    return $row['municipality'] ?: '-';
}

function hotline_category_badge($category) {
    $category = trim($category ?? 'Other');

    if ($category == '') {
        $category = 'Other';
    }

    return '<span class="soft-badge">' . h($category) . '</span>';
}

function preserve_filter_url($category, $scope, $search) {
    $query = [];

    if ($category != '') {
        $query['category'] = $category;
    }

    if ($scope != '') {
        $query['scope'] = $scope;
    }

    if ($search != '') {
        $query['search'] = $search;
    }

    return 'hotlines.php?' . http_build_query($query);
}
?>

<div class="panel-card">
    <div class="panel-header d-flex justify-content-between align-items-center">
        <div>
            <h2>Emergency Hotlines</h2>
            <p>One hotline directory with filters for municipal, barangay, PNP, fire, medical, MDRRMO, and other contacts.</p>
        </div>

        <?php if ($CanManageData) { ?>
            <a href="add-hotline.php" class="btn btn-emergency">+ Add Hotline</a>
        <?php } ?>
    </div>

    <?php if (isset($_GET['created'])) { ?><div class="alert alert-success py-2">Hotline added successfully.</div><?php } ?>
    <?php if (isset($_GET['updated'])) { ?><div class="alert alert-success py-2">Hotline updated successfully.</div><?php } ?>
    <?php if (isset($_GET['deleted'])) { ?><div class="alert alert-success py-2">Hotline deleted successfully.</div><?php } ?>
    <?php if (isset($_GET['denied'])) { ?><div class="alert alert-danger py-2">Access denied.</div><?php } ?>
    <?php if (isset($_GET['error'])) { ?><div class="alert alert-danger py-2">Please complete the required fields.</div><?php } ?>

    <div class="filter-bar" id="hotlineFilterBar">
        <input type="text" id="hotlineSearch" class="form-control" placeholder="Search name, category, area, number..." autocomplete="off">
        <select id="hotlineScopeFilter" class="form-select">
            <option value="">All scopes</option>
            <?php foreach (['Municipal', 'Barangay'] as $scope) { ?>
                <option value="<?php echo h(strtolower($scope)); ?>"><?php echo h($scope); ?></option>
            <?php } ?>
        </select>
        <select id="hotlineCategoryFilter" class="form-select">
            <option value="">All categories</option>
            <?php foreach ($AllowedCategories as $cat) { if ($cat === 'All') continue; ?>
                <option value="<?php echo h(strtolower($cat)); ?>"><?php echo h($cat); ?></option>
            <?php } ?>
        </select>
        <button type="button" class="btn btn-light border" onclick="resetHotlineFilters()">Reset</button>
    </div>

    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table align-middle">
            <thead>
                <tr>
                    <th>Name / Office</th>
                    <th>Category</th>
                    <th>Scope</th>
                    <th>Area / Barangay</th>
                    <th>Telephone</th>
                    <th>Cellphone</th>
                    <th>Hotline</th>
                    <th>Status</th>
                    <?php if ($CanManageData) { ?><th style="width:90px;">Action</th><?php } ?>
                </tr>
            </thead>
            <tbody>
                <?php if ($HotlineResult && mysqli_num_rows($HotlineResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($HotlineResult)) { ?>
                        <tr class="hotline-row"
                            data-search="<?php echo h(strtolower($row['office_name'] . ' ' . $row['category'] . ' ' . $row['municipality'] . ' ' . ($row['barangay_name'] ?? '') . ' ' . $row['telephone_numbers'] . ' ' . $row['cellphone_numbers'] . ' ' . $row['hotline_number'])); ?>"
                            data-scope="<?php echo h(strtolower($row['hotline_scope'] ?? '')); ?>"
                            data-category="<?php echo h(strtolower($row['category'] ?? '')); ?>">
                            <td>
                                <strong><?php echo h($row['office_name']); ?></strong>
                                <?php if (trim($row['remarks'] ?? '') != '') { ?>
                                    <br><small class="text-muted"><?php echo h($row['remarks']); ?></small>
                                <?php } ?>
                            </td>
                            <td><?php echo hotline_category_badge($row['category']); ?></td>
                            <td><?php echo h($row['hotline_scope'] ?: '-'); ?></td>
                            <td><?php echo h(hotline_area_text($row)); ?></td>
                            <td><?php echo h($row['telephone_numbers'] ?: '-'); ?></td>
                            <td><?php echo h($row['cellphone_numbers'] ?: '-'); ?></td>
                            <td><strong><?php echo h($row['hotline_number'] ?: '-'); ?></strong></td>
                            <td><?php echo h($row['status']); ?></td>
                            <?php if ($CanManageData) { ?>
                                <td class="text-nowrap">
                                    <div class="dropdown">
                                        <button class="btn btn-sm btn-dark dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                            Action
                                        </button>
                                        <ul class="dropdown-menu dropdown-menu-end">
                                            <li>
                                                <a class="dropdown-item" href="edit-hotline.php?id=<?php echo (int)$row['id']; ?>">
                                                    Edit
                                                </a>
                                            </li>
                                            <li>
                                                <form method="post" action="../app/hotlines/delete-hotline.php" class="m-0" onsubmit="return confirm('Delete this hotline?');">
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
                        <td colspan="<?php echo $CanManageData ? 9 : 8; ?>" class="empty-state">No hotlines found.</td>
                    </tr>
                <?php } ?>
                <tr id="noHotlineMatchRow" style="display:none;">
                    <td colspan="<?php echo $CanManageData ? 9 : 8; ?>" class="empty-state">No matching hotlines.</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

<script>
function runHotlineFilter() {
    var query    = document.getElementById('hotlineSearch').value.toLowerCase().trim();
    var scope    = document.getElementById('hotlineScopeFilter').value.toLowerCase();
    var category = document.getElementById('hotlineCategoryFilter').value.toLowerCase();
    var rows     = document.querySelectorAll('.hotline-row');
    var visible  = 0;

    rows.forEach(function(row) {
        var rowSearch   = row.getAttribute('data-search') || '';
        var rowScope    = row.getAttribute('data-scope') || '';
        var rowCategory = row.getAttribute('data-category') || '';

        var matchQuery    = !query    || rowSearch.includes(query);
        var matchScope    = !scope    || rowScope === scope;
        var matchCategory = !category || rowCategory.includes(category);

        var show = matchQuery && matchScope && matchCategory;
        row.style.display = show ? '' : 'none';
        if (show) visible++;
    });

    var noMatch = document.getElementById('noHotlineMatchRow');
    if (noMatch) noMatch.style.display = (visible === 0) ? '' : 'none';
}

function resetHotlineFilters() {
    document.getElementById('hotlineSearch').value = '';
    document.getElementById('hotlineScopeFilter').value = '';
    document.getElementById('hotlineCategoryFilter').value = '';
    runHotlineFilter();
}

document.getElementById('hotlineSearch').addEventListener('input', runHotlineFilter);
document.getElementById('hotlineScopeFilter').addEventListener('change', runHotlineFilter);
document.getElementById('hotlineCategoryFilter').addEventListener('change', runHotlineFilter);
</script>

<?php include "../app/includes/footer.php"; ?>
