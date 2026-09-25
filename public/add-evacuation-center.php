<?php
$V_page_title = "Add Evacuation Center";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/functions.php";

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
if (!can_manage_evacuation_centers($V_role, $V_sub_role)) {
    header("Location: evacuation-centers.php?denied=1");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

// Barangay chairmen can only add centers inside their own barangay.
$V_ec_locked_barangay = false;
if ($V_role === 'barangay') {
    $V_ec_locked_barangay = true;
    $V_ec_own_barangay_id = (int)($_SESSION['barangay_id'] ?? 0);
    $BarangayStmt = mysqli_prepare($connection, "SELECT id, name, municipality FROM barangays WHERE id = ? LIMIT 1");
    mysqli_stmt_bind_param($BarangayStmt, "i", $V_ec_own_barangay_id);
    mysqli_stmt_execute($BarangayStmt);
    $BarangayResult = mysqli_stmt_get_result($BarangayStmt);
// Restrict the barangay list to the caller's municipality when one is forced (MDR sub-roles).
} elseif (($V_ec_manage_muni = mdr_municipality($V_role, $V_sub_role))) {
    $BarangayStmt = mysqli_prepare($connection, "SELECT id, name, municipality FROM barangays WHERE municipality = ? ORDER BY name ASC");
    mysqli_stmt_bind_param($BarangayStmt, "s", $V_ec_manage_muni);
    mysqli_stmt_execute($BarangayStmt);
    $BarangayResult = mysqli_stmt_get_result($BarangayStmt);
} else {
    $BarangayResult = mysqli_query($connection, "SELECT id, name, municipality FROM barangays ORDER BY municipality ASC, name ASC");
}
$V_statuses = ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];
?>

<div class="panel-card form-panel">
    <div class="panel-header">
        <div>
            <h2>Add Evacuation Center</h2>
            <p>Add a new evacuation center record.</p>
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
        <form action="../app/evacuation-centers/save-evacuation-center.php" method="post">
            <?php echo csrf_field(); ?>
            <div class="mb-3">
                <label class="form-label">Barangay *</label>
                <?php if ($V_ec_locked_barangay) { ?>
                    <?php while ($barangay = mysqli_fetch_assoc($BarangayResult)) { ?>
                        <input type="hidden" name="N_barangay_id" value="<?php echo (int)$barangay['id']; ?>">
                        <input type="text" class="form-control" value="<?php echo h($barangay['name'] . ' (' . $barangay['municipality'] . ')'); ?>" disabled>
                    <?php } ?>
                <?php } else { ?>
                <select name="N_barangay_id" class="form-select" required>
                    <option value="">Select barangay</option>
                    <?php while ($barangay = mysqli_fetch_assoc($BarangayResult)) { ?>
                        <option value="<?php echo (int)$barangay['id']; ?>"><?php echo h($barangay['name'] . ' (' . $barangay['municipality'] . ')'); ?></option>
                    <?php } ?>
                </select>
                <?php } ?>
            </div>

            <div class="mb-3">
                <label class="form-label">Center Name *</label>
                <input type="text" name="N_center_name" class="form-control" required>
            </div>

            <div class="mb-3">
                <label class="form-label">Center Type</label>
                <input type="text" name="N_center_type" class="form-control" placeholder="School / Barangay Facility / Covered Court">
            </div>

            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Capacity</label>
                    <input type="number" name="N_capacity" class="form-control" min="0" value="0">
                </div>
                <div class="col-md-6">
                    <label class="form-label">Current Evacuees</label>
                    <input type="number" name="N_current_evacuees" class="form-control" min="0" value="0">
                </div>
            </div>

            <div class="row g-3 mt-1">
                <div class="col-md-6">
                    <label class="form-label">Contact Person</label>
                    <input type="text" name="N_contact_person" class="form-control">
                </div>
                <div class="col-md-6">
                    <label class="form-label">Contact Number</label>
                    <input type="tel" name="N_contact_number" class="form-control" inputmode="tel" pattern="[0-9+ ()-]*" oninput="this.value = this.value.replace(/[^0-9+\s()\-]/g, '')">
                </div>
            </div>

            <div class="mb-3 mt-3">
                <label class="form-label">Status</label>
                <select name="N_status" class="form-select">
                    <?php foreach ($V_statuses as $status) { ?>
                        <option class="ec-status-<?php echo h(strtolower(str_replace(' ', '-', $status))); ?>" value="<?php echo h($status); ?>"><?php echo h($status); ?></option>
                    <?php } ?>
                </select>
            </div>

            <input type="submit" value="Save Evacuation Center" class="btn btn-emergency">
            <a href="evacuation-centers.php" class="btn btn-light border">Cancel</a>
        </form>
    </div>
</div>

<?php include "../app/includes/footer.php"; ?>
