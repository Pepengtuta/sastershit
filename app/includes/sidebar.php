<?php
$V_current_page = basename($_SERVER['PHP_SELF']);
$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_name = $_SESSION['name'] ?? 'User';
$V_barangay_name = $_SESSION['barangay_name'] ?? '';
$V_mdr_forced = mdr_municipality($V_role, $V_sub_role);
$V_mayor_forced = mayor_municipality($V_role, $V_sub_role);

if (!function_exists('active_page')) {
    function active_page($V_file, $V_current_page) {
        if ($V_file == $V_current_page) {
            return 'active';
        }
        return '';
    }
}
?>
<div class="layout-shell">
    <aside class="sidebar">
        <div class="sidebar-brand">
            <div>
                <div class="brand-title">BRGY | Municipal | Provincial</div>
                <div class="brand-subtitle">Coordination & Mechanism</div>
            </div>
        </div>

        <div class="user-card">
            <?php if ($V_role == 'barangay' && $V_sub_role == 'tanod') { ?>
                <div class="user-name">BHERT: <?php echo strtoupper(h(preg_replace('/^(Barangay Tanod|Tanod|BHERT)\s+/i', '', $V_name))); ?></div>
            <?php } elseif ($V_role == 'barangay') { ?>
                <div class="user-name"><?php echo h(role_name($V_role, $V_sub_role)); ?></div>
            <?php } elseif ($V_role == 'pcf' && $V_mayor_forced) { ?>
                <div class="user-name">MAYOR <?php echo strtoupper(h($V_mayor_forced)); ?></div>
                <div class="user-role">Mayor</div>
            <?php } elseif ($V_role == 'pcf' && $V_mdr_forced) { ?>
                <div class="user-name">MDRRMO <?php echo strtoupper(h($V_mdr_forced)); ?></div>
                <div class="user-role">MDRRMO</div>
            <?php } elseif ($V_role == 'pho' && $V_sub_role == 'governor') { ?>
                <div class="user-name">AKLAN GOVERNOR</div>
                <div class="user-role">Governor</div>
            <?php } else { ?>
                <div class="user-name"><?php echo h($V_name); ?></div>
                <div class="user-role"><?php echo h(role_name($V_role, $V_sub_role)); ?></div>
            <?php } ?>
            <?php if ($V_barangay_name != '') { ?>
                <div class="user-brgy">BRGY: <?php echo h($V_barangay_name); ?></div>
            <?php } ?>
        </div>

        <nav class="nav-menu">
            <?php if ($V_role == 'barangay' && $V_sub_role == 'tanod') { ?>
                <!-- BHERT: field-focused sidebar -->
                <a class="nav-link <?php echo active_page('dashboard.php', $V_current_page); ?>" href="dashboard.php"><span class="material-symbols-outlined icon-md">dashboard</span> Dashboard</a>
                <a class="nav-link <?php echo active_page('create-incident-report.php', $V_current_page); ?>" href="create-incident-report.php"><span class="material-symbols-outlined icon-md">note_add</span> Create Incident</a>
                <a class="nav-link <?php echo active_page('incident-reports.php', $V_current_page); ?>" href="incident-reports.php"><span class="material-symbols-outlined icon-md">assignment</span> My Reports</a>
                <a class="nav-link <?php echo active_page('hotlines.php', $V_current_page); ?>" href="hotlines.php"><span class="material-symbols-outlined icon-md">phone_in_talk</span> Emergency Hotlines</a>
            <?php } elseif ($V_role == 'barangay') { ?>
                <!-- Chairman & Secretary: full barangay sidebar -->
                <a class="nav-link <?php echo active_page('dashboard.php', $V_current_page); ?>" href="dashboard.php"><span class="material-symbols-outlined icon-md">dashboard</span> Dashboard</a>
                <a class="nav-link <?php echo active_page('map.php', $V_current_page); ?>" href="map.php"><span class="material-symbols-outlined icon-md">map</span> Barangay Map</a>
                <a class="nav-link <?php echo active_page('barangay-alerts.php', $V_current_page); ?>" href="barangay-alerts.php"><span class="material-symbols-outlined icon-md">notifications</span> Alerts</a>
                <a class="nav-link <?php echo active_page('incident-reports.php', $V_current_page); ?>" href="incident-reports.php"><span class="material-symbols-outlined icon-md">assignment</span> My Reports</a>
                <a class="nav-link <?php echo active_page('evacuation-centers.php', $V_current_page); ?>" href="evacuation-centers.php"><span class="material-symbols-outlined icon-md">location_city</span> Evacuation Centers</a>
                <a class="nav-link <?php echo active_page('hotlines.php', $V_current_page); ?>" href="hotlines.php"><span class="material-symbols-outlined icon-md">phone_in_talk</span> Emergency Hotlines</a>
                <!-- Chairman & Secretary: user management -->
                <?php if ($V_sub_role == 'captain' || $V_sub_role == 'secretary') { ?>
                    <a class="nav-link <?php echo active_page('manage-users.php', $V_current_page); ?>" href="manage-users.php"><span class="material-symbols-outlined icon-md">people</span> Manage Users</a>
                <?php } ?>
                <?php if ($V_sub_role == 'captain') { ?>
                    <a class="nav-link <?php echo active_page('user-activity.php', $V_current_page); ?>" href="user-activity.php"><span class="material-symbols-outlined icon-md">history</span> Activity Log</a>
                <?php } ?>
            <?php } elseif ($V_role == 'pcf') { ?>
                <a class="nav-link <?php echo active_page('dashboard.php', $V_current_page); ?>" href="dashboard.php"><span class="material-symbols-outlined icon-md">dashboard</span> Dashboard</a>
                <a class="nav-link <?php echo active_page('map.php', $V_current_page); ?>" href="map.php"><span class="material-symbols-outlined icon-md">map</span> Barangay Map</a>
                <a class="nav-link <?php echo active_page('alert.php', $V_current_page); ?>" href="alert.php"><span class="material-symbols-outlined icon-md">notification_add</span> Alert</a>
                <a class="nav-link <?php echo active_page('incident-reports.php', $V_current_page); ?>" href="incident-reports.php"><span class="material-symbols-outlined icon-md">assignment</span> All Incident Reports</a>
                <a class="nav-link <?php echo active_page('evacuation-centers.php', $V_current_page); ?>" href="evacuation-centers.php"><span class="material-symbols-outlined icon-md">location_city</span> Evacuation Centers</a>
                <a class="nav-link <?php echo active_page('assistance.php', $V_current_page); ?>" href="assistance.php"><span class="material-symbols-outlined icon-md">volunteer_activism</span> Needs &amp; Assistance</a>
                <a class="nav-link <?php echo active_page('hotlines.php', $V_current_page); ?>" href="hotlines.php"><span class="material-symbols-outlined icon-md">phone_in_talk</span> Emergency Hotlines</a>
                <?php if ($V_sub_role === 'mdr_admin') { ?>
                    <a class="nav-link <?php echo active_page('manage-users.php', $V_current_page); ?>" href="manage-users.php"><span class="material-symbols-outlined icon-md">people</span> Manage Users</a>
                <?php } ?>
                <?php if ($V_sub_role === 'mdr_admin') { ?>
                    <a class="nav-link <?php echo active_page('user-activity.php', $V_current_page); ?>" href="user-activity.php"><span class="material-symbols-outlined icon-md">history</span> Activity Log</a>
                <?php } ?>
            <?php } elseif ($V_role == 'pho') { ?>
                <a class="nav-link <?php echo active_page('dashboard.php', $V_current_page); ?>" href="dashboard.php"><span class="material-symbols-outlined icon-md">dashboard</span> Dashboard</a>
                <a class="nav-link <?php echo active_page('map.php', $V_current_page); ?>" href="map.php"><span class="material-symbols-outlined icon-md">map</span> Barangay Map</a>
                <a class="nav-link <?php echo active_page('alert.php', $V_current_page); ?>" href="alert.php"><span class="material-symbols-outlined icon-md">notification_add</span> Alert</a>
                <a class="nav-link <?php echo active_page('health-reports.php', $V_current_page); ?>" href="health-reports.php"><span class="material-symbols-outlined icon-md">health_and_safety</span> Reports</a>
                <a class="nav-link <?php echo active_page('evacuation-centers.php', $V_current_page); ?>" href="evacuation-centers.php"><span class="material-symbols-outlined icon-md">location_city</span> Evacuation Centers</a>
                <a class="nav-link <?php echo active_page('assistance.php', $V_current_page); ?>" href="assistance.php"><span class="material-symbols-outlined icon-md">volunteer_activism</span> Needs &amp; Assistance</a>
                <a class="nav-link <?php echo active_page('hotlines.php', $V_current_page); ?>" href="hotlines.php"><span class="material-symbols-outlined icon-md">phone_in_talk</span> Emergency Hotlines</a>
                <?php if ($V_sub_role === '' || $V_sub_role === null) { ?>
                    <a class="nav-link <?php echo active_page('manage-users.php', $V_current_page); ?>" href="manage-users.php"><span class="material-symbols-outlined icon-md">people</span> Manage Users</a>
                    <a class="nav-link <?php echo active_page('user-activity.php', $V_current_page); ?>" href="user-activity.php"><span class="material-symbols-outlined icon-md">history</span> Activity Log</a>
                <?php } ?>
            <?php } elseif ($V_role == 'superadmin') { ?>
                <a class="nav-link <?php echo active_page('dashboard.php', $V_current_page); ?>" href="dashboard.php"><span class="material-symbols-outlined icon-md">dashboard</span> Dashboard</a>
                <a class="nav-link <?php echo active_page('map.php', $V_current_page); ?>" href="map.php"><span class="material-symbols-outlined icon-md">map</span> Barangay Map</a>
                <a class="nav-link <?php echo active_page('alert.php', $V_current_page); ?>" href="alert.php"><span class="material-symbols-outlined icon-md">notification_add</span> Alert</a>
                <a class="nav-link <?php echo active_page('incident-reports.php', $V_current_page); ?>" href="incident-reports.php"><span class="material-symbols-outlined icon-md">assignment</span> All Reports</a>
                <a class="nav-link <?php echo active_page('manage-users.php', $V_current_page); ?>" href="manage-users.php"><span class="material-symbols-outlined icon-md">people</span> Manage Users</a>
                <a class="nav-link <?php echo active_page('user-activity.php', $V_current_page); ?>" href="user-activity.php"><span class="material-symbols-outlined icon-md">history</span> Activity Log</a>
                <a class="nav-link <?php echo active_page('evacuation-centers.php', $V_current_page); ?>" href="evacuation-centers.php"><span class="material-symbols-outlined icon-md">location_city</span> Evacuation Centers</a>
                <a class="nav-link <?php echo active_page('assistance.php', $V_current_page); ?>" href="assistance.php"><span class="material-symbols-outlined icon-md">volunteer_activism</span> Needs &amp; Assistance</a>
                <a class="nav-link <?php echo active_page('hotlines.php', $V_current_page); ?>" href="hotlines.php"><span class="material-symbols-outlined icon-md">phone_in_talk</span> Emergency Hotlines</a>
            <?php } ?>
        </nav>

        <?php if (is_admin_role($V_role) && !$V_mdr_forced && !$V_mayor_forced): ?>
        <div class="sidebar-muni-filter">
            <div class="sidebar-muni-label">
                <span class="material-symbols-outlined" style="font-size:14px;vertical-align:middle;margin-right:4px;">filter_alt</span>Municipality
            </div>
            <?php
                $V_filter_municipalities = get_municipality_list($connection);
                $V_active_filter = get_filter_municipality();
            ?>
            <form method="POST" action="../app/auth/set_municipality_filter.php">
                <select name="municipality" class="sidebar-muni-select" onchange="this.form.submit()">
                    <option value="all"<?php echo ($V_active_filter === null ? ' selected' : ''); ?>>All Municipalities</option>
                    <?php foreach ($V_filter_municipalities as $V_muni): ?>
                    <option value="<?php echo h($V_muni); ?>"<?php echo ($V_active_filter === $V_muni ? ' selected' : ''); ?>>
                        <?php echo h($V_muni); ?>
                    </option>
                    <?php endforeach; ?>
                </select>
            </form>
        </div>
        <?php endif; ?>

    </aside>

    <main class="main-content">
        <header class="topbar">
            <div>
                <h1><?php echo h($V_page_title); ?></h1>
                <p><?php echo date('F d, Y'); ?> · <?php
                    if (is_admin_role($V_role)) {
                        $V_topbar_muni = get_effective_municipality($V_role, $V_sub_role);
                        echo h(($V_topbar_muni ?? 'All Municipalities') . ', Aklan');
                    } else {
                        echo h(($_SESSION['municipality'] ?? 'Kalibo') . ', Aklan');
                    }
                ?></p>
            </div>
            <div class="topbar-actions">
                <span class="status-chip"><?php echo h(role_name($V_role, $V_sub_role)); ?></span>
                <a class="btn btn-outline-dark btn-sm logout-btn" href="logout.php">Logout</a>
            </div>
        </header>
