<?php
$V_page_title = "Alerts";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

if ($_SESSION['role'] != 'barangay') {
    header("Location: dashboard.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_barangay_id = (int)$_SESSION['barangay_id'];

$V_alert_query = "SELECT alerts.*, alert_barangays.is_read, alert_barangays.read_at, users.name AS created_by_name
                  FROM alert_barangays
                  INNER JOIN alerts ON alert_barangays.alert_id = alerts.id
                  INNER JOIN users ON alerts.created_by = users.id
                  WHERE alert_barangays.barangay_id = ?
                  ORDER BY alerts.created_at DESC";
$stmt = mysqli_prepare($connection, $V_alert_query);
mysqli_stmt_bind_param($stmt, "i", $V_barangay_id);
mysqli_stmt_execute($stmt);
$V_alert_result = mysqli_stmt_get_result($stmt);
?>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Alerts / Advisories</h2>
            <p>Alerts sent to your barangay by Municipal or Superadmin.</p>
        </div>
    </div>

    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Severity</th>
                    <th>Alert</th>
                    <th>Type</th>
                    <th>Instructions</th>
                    <th>Status</th>
                    <th>Date</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($V_alert_result && mysqli_num_rows($V_alert_result) > 0) { ?>
                    <?php while ($row = mysqli_fetch_assoc($V_alert_result)) { ?>
                        <tr>
                            <td><span class="soft-badge <?php echo status_class($row['severity']); ?>"><?php echo h($row['severity']); ?></span></td>
                            <td>
                                <strong><?php echo h($row['title']); ?></strong><br>
                                <small><?php echo h($row['message']); ?></small><br>
                                <small class="text-muted">Issued by: <?php echo h($row['created_by_name']); ?></small>
                            </td>
                            <td><?php echo h($row['alert_type']); ?></td>
                            <td><?php echo h($row['instructions'] ?: '-'); ?></td>
                            <td>
                                <?php if ((int)$row['is_read'] == 1) { ?>
                                    <span class="badge bg-success">Read</span>
                                <?php } else { ?>
                                    <span class="badge bg-warning text-dark">Unread</span>
                                <?php } ?>
                            </td>
                            <td><?php echo date('M d, Y h:i A', strtotime($row['created_at'])); ?></td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr><td colspan="6" class="empty-state">No alerts assigned to your barangay yet.</td></tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<?php include "../app/includes/footer.php"; ?>
