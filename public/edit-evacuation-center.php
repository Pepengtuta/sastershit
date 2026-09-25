<?php
$V_page_title = "Edit Evacuation Center";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/functions.php";

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
if (!can_manage_evacuation_centers($V_role, $V_sub_role)) {
    header("Location: evacuation-centers.php?denied=1");
    exit;
}

$V_ID = (int)($_GET['id'] ?? 0);

// Barangay chairmen may only edit centers within their own barangay.
$V_ec_locked_barangay = false;
$CenterStmt = null;
if ($V_role === 'barangay') {
    $V_ec_locked_barangay = true;
    $CenterQuery = "SELECT * FROM evacuation_centers WHERE id = ? AND barangay = ?";
    $CenterStmt = mysqli_prepare($connection, $CenterQuery);
    $V_actor_barangay_name = $_SESSION['barangay_name'] ?? '';
    mysqli_stmt_bind_param($CenterStmt, "is", $V_ID, $V_actor_barangay_name);
} elseif (($V_ec_edit_muni = mdr_municipality($V_role, $V_sub_role))) {
    // MDR sub-roles may only edit centers within their own municipality.
    $CenterQuery = "SELECT * FROM evacuation_centers WHERE id = ? AND municipality = ?";
    $CenterStmt = mysqli_prepare($connection, $CenterQuery);
    mysqli_stmt_bind_param($CenterStmt, "is", $V_ID, $V_ec_edit_muni);
} else {
    $CenterQuery = "SELECT * FROM evacuation_centers WHERE id = ?";
    $CenterStmt = mysqli_prepare($connection, $CenterQuery);
    mysqli_stmt_bind_param($CenterStmt, "i", $V_ID);
}
if (!$CenterStmt) {
    error_log("edit-evac-center: center query failed to prepare: " . mysqli_error($connection));
    http_response_code(500);
    exit("Unable to load that evacuation center. Please try again.");
}
mysqli_stmt_execute($CenterStmt);
$CenterResult = mysqli_stmt_get_result($CenterStmt);
$row = $CenterResult ? mysqli_fetch_assoc($CenterResult) : null;
if ($CenterResult) mysqli_free_result($CenterResult);

if (!$row) {
    header("Location: evacuation-centers.php");
    exit;
}

// Load the barangay list AFTER the center row is fully consumed (avoids "commands out of sync").
$barangayOptions = [];
if ($V_ec_locked_barangay) {
    $V_ec_own_barangay_id = (int)($_SESSION['barangay_id'] ?? 0);
    $BarangayStmt = mysqli_prepare($connection, "SELECT id, name, municipality FROM barangays WHERE id = ? LIMIT 1");
    if ($BarangayStmt) {
        mysqli_stmt_bind_param($BarangayStmt, "i", $V_ec_own_barangay_id);
        mysqli_stmt_execute($BarangayStmt);
        $Br = mysqli_stmt_get_result($BarangayStmt);
        if ($Br) { while ($b = mysqli_fetch_assoc($Br)) { $barangayOptions[] = $b; } mysqli_free_result($Br); }
    }
} elseif (isset($V_ec_edit_muni)) {
    $BarangayStmt = mysqli_prepare($connection, "SELECT id, name, municipality FROM barangays WHERE municipality = ? ORDER BY name ASC");
    if ($BarangayStmt) {
        mysqli_stmt_bind_param($BarangayStmt, "s", $V_ec_edit_muni);
        mysqli_stmt_execute($BarangayStmt);
        $Br = mysqli_stmt_get_result($BarangayStmt);
        if ($Br) { while ($b = mysqli_fetch_assoc($Br)) { $barangayOptions[] = $b; } mysqli_free_result($Br); }
    }
} else {
    $Br = mysqli_query($connection, "SELECT id, name, municipality FROM barangays ORDER BY municipality ASC, name ASC");
    if ($Br) { while ($b = mysqli_fetch_assoc($Br)) { $barangayOptions[] = $b; } mysqli_free_result($Br); }
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_statuses = ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];
?>

<div class="panel-card form-panel">
    <div class="panel-header">
        <div>
            <h2>Edit Evacuation Center</h2>
            <p>Editing: <?php echo h($row['center_name']); ?></p>
        </div>
    </div>

    <div class="panel-body">
        <?php if (isset($_GET['error'])) { ?>
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <?php if ($_GET['error'] === 'number') { ?>
                    Capacity and Current Evacuees must be valid non-negative numbers, and Contact Number must contain at least one digit.
                <?php } else { ?>
                    Something went wrong. Please review your entries and try again.
                <?php } ?>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        <?php } ?>
        <form action="../app/evacuation-centers/update-evacuation-center.php?id=<?php echo $V_ID; ?>" method="post">
            <?php echo csrf_field(); ?>
            <div class="mb-3">
                <label class="form-label">Barangay *</label>
                <?php if ($V_ec_locked_barangay) { ?>
                    <?php foreach ($barangayOptions as $barangay) { ?>
                        <input type="hidden" name="N_barangay_id" value="<?php echo (int)$barangay['id']; ?>">
                        <input type="text" class="form-control" value="<?php echo h($barangay['name'] . ' (' . $barangay['municipality'] . ')'); ?>" disabled>
                    <?php } ?>
                <?php } else { ?>
                <select name="N_barangay_id" class="form-select" required>
                    <?php foreach ($barangayOptions as $barangay) { ?>
                        <option value="<?php echo (int)$barangay['id']; ?>" <?php if ($row['barangay'] == $barangay['name']) echo 'selected'; ?>><?php echo h($barangay['name'] . ' (' . $barangay['municipality'] . ')'); ?></option>
                    <?php } ?>
                </select>
                <?php } ?>
            </div>

            <div class="mb-3">
                <label class="form-label">Center Name *</label>
                <input type="text" name="N_center_name" class="form-control" value="<?php echo h($row['center_name']); ?>" required>
            </div>

            <div class="mb-3">
                <label class="form-label">Center Type</label>
                <input type="text" name="N_center_type" class="form-control" value="<?php echo h($row['center_type']); ?>">
            </div>

            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Capacity</label>
                    <input type="number" name="N_capacity" class="form-control" min="0" value="<?php echo (int)$row['capacity']; ?>">
                </div>
                <div class="col-md-6">
                    <label class="form-label">Current Evacuees</label>
                    <input type="number" name="N_current_evacuees" class="form-control" min="0" value="<?php echo (int)$row['current_evacuees']; ?>">
                </div>
            </div>

            <div class="row g-3 mt-1">
                <div class="col-md-6">
                    <label class="form-label">Contact Person</label>
                    <input type="text" name="N_contact_person" class="form-control" value="<?php echo h($row['contact_person']); ?>">
                </div>
                <div class="col-md-6">
                    <label class="form-label">Contact Number</label>
                    <input type="tel" name="N_contact_number" class="form-control" inputmode="tel" pattern="[0-9+ ()-]*" value="<?php echo h($row['contact_number']); ?>" oninput="this.value = this.value.replace(/[^0-9+\s()\-]/g, '')">
                </div>
            </div>

            <div class="mb-3 mt-3">
                <label class="form-label">Status</label>
                <select name="N_status" class="form-select">
                    <?php foreach ($V_statuses as $status) { ?>
                        <option class="ec-status-<?php echo h(strtolower(str_replace(' ', '-', $status))); ?>" value="<?php echo h($status); ?>" <?php if ($row['status'] == $status) echo 'selected'; ?>><?php echo h($status); ?></option>
                    <?php } ?>
                </select>
            </div>

            <input type="submit" value="Update Evacuation Center" class="btn btn-emergency">
            <a href="evacuation-centers.php" class="btn btn-light border">Cancel</a>
        </form>
    </div>
</div>

<?php include "../app/includes/footer.php"; ?>
