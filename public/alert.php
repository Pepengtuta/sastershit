<?php
$V_page_title = "Alerts";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

if ($_SESSION['role'] != 'pcf' && $_SESSION['role'] != 'pho' && $_SESSION['role'] != 'superadmin') {
    header("Location: dashboard.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_alert_query = "SELECT alerts.*, users.name AS created_by_name,
                         IFNULL(alert_targets.affected_barangays, '') AS affected_barangays
                  FROM alerts
                  INNER JOIN users ON alerts.created_by = users.id
                  LEFT JOIN (
                      SELECT alert_barangays.alert_id,
                             GROUP_CONCAT(barangays.name ORDER BY barangays.name ASC SEPARATOR ', ') AS affected_barangays
                      FROM alert_barangays
                      INNER JOIN barangays ON alert_barangays.barangay_id = barangays.id
                      GROUP BY alert_barangays.alert_id
                  ) AS alert_targets ON alerts.id = alert_targets.alert_id
                  ORDER BY alerts.created_at DESC";
$V_alert_result = mysqli_query($connection, $V_alert_query);
?>

<style>
.alert-date-cell {
    white-space: nowrap;
    min-width: 155px;
}
.alert-message-cell {
    min-width: 260px;
}
.alert-target-cell {
    min-width: 220px;
}
</style>

<div class="panel-card">
    <div class="panel-header d-flex justify-content-between align-items-center gap-3">
        <div>
            <h2>Alerts / Advisories</h2>
            <p>Latest alerts published by Municipal and Provincial.</p>
        </div>

        <?php if ($_SESSION['role'] != 'superadmin' && !is_readonly_role($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '')) { ?>
            <a href="add-alert.php" class="btn btn-emergency">+ Add Alert</a>
        <?php } ?>
    </div>

    <?php if (isset($_GET['success'])) { ?>
        <div class="alert alert-success mx-3 mt-3 py-2">Alert published successfully.</div>
    <?php } ?>

    <?php if (isset($_GET['deleted'])) { ?>
        <div class="alert alert-success mx-3 mt-3 py-2">Alert deleted successfully.</div>
    <?php } ?>

    <div class="table-wrap">
        <table class="table table-bordered table-hover custom-table">
            <thead>
                <tr>
                    <th>Title</th>
                    <th>Type</th>
                    <th>Severity</th>
                    <th>Affected Barangays</th>
                    <th>Status</th>
                    <th>Created By</th>
                    <th>Date</th>
                </tr>
            </thead>

            <tbody>
                <?php if ($V_alert_result && mysqli_num_rows($V_alert_result) > 0) { ?>
                    <?php while ($alert = mysqli_fetch_assoc($V_alert_result)) { ?>
                        <tr>
                            <td class="alert-message-cell">
                                <strong><?php echo h($alert['title']); ?></strong><br>
                                <small><?php echo h($alert['message']); ?></small>

                                <?php if ($alert['instructions'] != '') { ?>
                                    <br>
                                    <small><strong>Instruction:</strong> <?php echo h($alert['instructions']); ?></small>
                                <?php } ?>
                            </td>

                            <td><?php echo h($alert['alert_type']); ?></td>

                            <td>
                                <span class="soft-badge <?php echo status_class($alert['severity']); ?>">
                                    <?php echo h($alert['severity']); ?>
                                </span>
                            </td>

                            <td class="alert-target-cell">
                                <?php if ($alert['affected_barangays'] != '') { ?>
                                    <?php echo h($alert['affected_barangays']); ?>
                                <?php } else { ?>
                                    <span class="text-muted">No barangays selected</span>
                                <?php } ?>
                            </td>

                            <td><?php echo h($alert['status']); ?></td>
                            <td><?php echo h($alert['created_by_name']); ?></td>
                            <td class="alert-date-cell"><?php echo date('M d, Y h:i A', strtotime($alert['created_at'])); ?></td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr>
                        <td colspan="7" class="empty-state">No alerts yet.</td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<?php include "../app/includes/footer.php"; ?>
