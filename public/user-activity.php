<?php
$V_page_title = "Activity Log";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_actor_barangay = (int)($_SESSION['barangay_id'] ?? 0);

// Superadmin sees all. Chairman sees own actions only. MDR admins see their MDRRMO's actions.
if ($V_role === 'superadmin') {
    $LogResult = mysqli_query($connection, "SELECT * FROM user_activity_logs ORDER BY created_at DESC LIMIT 300");
} elseif ($V_role === 'barangay' && $V_sub_role === 'captain') {
    $V_actor_id = (int)($_SESSION['user_id'] ?? 0);
    $LogResult = mysqli_query($connection, "SELECT * FROM user_activity_logs WHERE actor_id = $V_actor_id ORDER BY created_at DESC LIMIT 300");
} elseif ($V_role === 'pcf' && $V_sub_role === 'mdr_admin') {
    // MDR Admin sees activity by all PCF users
    $LogResult = mysqli_query($connection, "SELECT * FROM user_activity_logs WHERE actor_id IN (SELECT id FROM users WHERE role = 'pcf') ORDER BY created_at DESC LIMIT 300");
} elseif ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null)) {
    // PHO Admin sees activity by all Provincial (PHO) users.
    $LogResult = mysqli_query($connection, "SELECT * FROM user_activity_logs WHERE actor_id IN (SELECT id FROM users WHERE role = 'pho') ORDER BY created_at DESC LIMIT 300");
} else {
    header("Location: dashboard.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

if (!function_exists('ua_action_label')) {
    function ua_action_label($a) {
        switch ($a) {
            case 'create': return 'Created user';
            case 'update': return 'Updated user';
            case 'reset_password': return 'Reset password';
            case 'deactivate': return 'Deactivated';
            case 'reactivate': return 'Reactivated';
            default: return ucfirst((string)$a);
        }
    }
}
if (!function_exists('ua_action_badge')) {
    function ua_action_badge($a) {
        switch ($a) {
            case 'create': return 'badge-soft-success';
            case 'update': return 'badge-soft-primary';
            case 'reset_password': return 'badge-soft-warning';
            case 'deactivate': return 'badge-soft-danger';
            case 'reactivate': return 'badge-soft-success';
            default: return 'badge-soft-secondary';
        }
    }
}
?>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>User Activity Log</h2>
            <p>A record of account actions taken by administrators (most recent first).</p>
        </div>
    </div>

    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>When</th>
                    <th>Performed by</th>
                    <th>Action</th>
                    <th>Target account</th>
                    <th>Details</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($LogResult && mysqli_num_rows($LogResult) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($LogResult)) { ?>
                        <tr>
                            <td><?php echo date('M d, Y g:i A', strtotime($row['created_at'])); ?></td>
                            <td><?php echo h($row['actor_name'] ?: '-'); ?></td>
                            <td><span class="soft-badge <?php echo h(ua_action_badge($row['action'])); ?>"><?php echo h(ua_action_label($row['action'])); ?></span></td>
                            <td><?php echo h($row['target_username'] ?: '-'); ?></td>
                            <td><?php echo h($row['details'] ?: '-'); ?></td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr><td colspan="5" class="empty-state">No activity recorded yet.</td></tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<?php include "../app/includes/footer.php"; ?>
