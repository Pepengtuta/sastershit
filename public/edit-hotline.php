<?php
$V_page_title = "Edit Emergency Hotline";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/functions.php";

if (!can_manage_hotlines($_SESSION['role'])) {
    header("Location: hotlines.php?denied=1");
    exit;
}

$V_ID = (int)($_GET['id'] ?? 0);
$HotlineQuery = "SELECT * FROM emergency_hotlines WHERE id = ?";
$HotlineStmt = mysqli_prepare($connection, $HotlineQuery);
mysqli_stmt_bind_param($HotlineStmt, "i", $V_ID);
mysqli_stmt_execute($HotlineStmt);
$HotlineResult = mysqli_stmt_get_result($HotlineStmt);
$row = mysqli_fetch_assoc($HotlineResult);

if (!$row) {
    header("Location: hotlines.php");
    exit;
}

$V_scope = $row['hotline_scope'] ?? 'Municipal';
if ($V_scope != 'Barangay' && $V_scope != 'Municipal') {
    $V_scope = 'Municipal';
}

$BarangayResult = mysqli_query($connection, "SELECT * FROM barangays WHERE status = 'Active' ORDER BY name ASC");
$Municipalities = [
    'Altavas', 'Balete', 'Banga', 'Batan', 'Buruanga', 'Ibajay', 'Kalibo', 'Lezo',
    'Libacao', 'Madalag', 'Makato', 'Malinao', 'Malay', 'Nabas', 'New Washington',
    'Numancia', 'Tangalan'
];

$Categories = ['Barangay', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];

include "../app/includes/header.php";
include "../app/includes/sidebar.php";
?>

<div class="panel-card form-panel">
    <div class="panel-header">
        <div>
            <h2>Edit Hotline</h2>
            <p>Editing: <?php echo h($row['office_name']); ?></p>
        </div>
    </div>

    <?php if (isset($_GET['error'])) { ?>
        <div class="alert alert-danger py-2">Please complete the required fields.</div>
    <?php } ?>

    <div class="panel-body">
        <form action="../app/hotlines/update-hotline.php?id=<?php echo $V_ID; ?>" method="post">
            <?php echo csrf_field(); ?>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Scope *</label>
                    <select name="N_hotline_scope" id="hotlineScope" class="form-select" required onchange="toggleHotlineArea()">
                        <option value="Municipal" <?php if ($V_scope == 'Municipal') echo 'selected'; ?>>Municipal</option>
                        <option value="Barangay" <?php if ($V_scope == 'Barangay') echo 'selected'; ?>>Barangay</option>
                    </select>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Category *</label>
                    <select name="N_category" class="form-select" required>
                        <option value="">Select category</option>
                        <?php foreach ($Categories as $category) { ?>
                            <option value="<?php echo h($category); ?>" <?php if ($row['category'] == $category) echo 'selected'; ?>><?php echo h($category); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-6" id="municipalityGroup">
                    <label class="form-label">Municipality *</label>
                    <select name="N_municipality" id="municipalitySelect" class="form-select">
                        <option value="">Select municipality</option>
                        <?php foreach ($Municipalities as $municipality) { ?>
                            <option value="<?php echo h($municipality); ?>" <?php if ($row['municipality'] == $municipality) echo 'selected'; ?>><?php echo h($municipality); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-6" id="barangayGroup">
                    <label class="form-label">Barangay *</label>
                    <select name="N_barangay_id" id="barangaySelect" class="form-select">
                        <option value="">Select barangay</option>
                        <?php while ($barangay = mysqli_fetch_assoc($BarangayResult)) { ?>
                            <option value="<?php echo (int)$barangay['id']; ?>" <?php if ((int)$row['barangay_id'] == (int)$barangay['id']) echo 'selected'; ?>><?php echo h($barangay['name']); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-12">
                    <label class="form-label">Name / Office *</label>
                    <input type="text" name="N_office_name" class="form-control" value="<?php echo h($row['office_name']); ?>" required>
                </div>

                <div class="col-md-4">
                    <label class="form-label">Telephone Numbers</label>
                    <input type="text" name="N_telephone_numbers" class="form-control" value="<?php echo h($row['telephone_numbers']); ?>">
                </div>

                <div class="col-md-4">
                    <label class="form-label">Cellphone Numbers</label>
                    <input type="text" name="N_cellphone_numbers" class="form-control" value="<?php echo h($row['cellphone_numbers']); ?>">
                </div>

                <div class="col-md-4">
                    <label class="form-label">Hotline Number</label>
                    <input type="text" name="N_hotline_number" class="form-control" value="<?php echo h($row['hotline_number']); ?>">
                </div>

                <div class="col-md-12">
                    <label class="form-label">Remarks</label>
                    <textarea name="N_remarks" class="form-control" rows="3"><?php echo h($row['remarks']); ?></textarea>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Status</label>
                    <select name="N_status" class="form-select">
                        <option value="Active" <?php if ($row['status'] == 'Active') echo 'selected'; ?>>Active</option>
                        <option value="Inactive" <?php if ($row['status'] == 'Inactive') echo 'selected'; ?>>Inactive</option>
                    </select>
                </div>
            </div>

            <div class="mt-3">
                <input type="submit" value="Update Hotline" class="btn btn-emergency">
                <a href="hotlines.php" class="btn btn-light border">Cancel</a>
            </div>
        </form>
    </div>
</div>

<script>
function toggleHotlineArea() {
    var scope = document.getElementById('hotlineScope').value;
    var municipalityGroup = document.getElementById('municipalityGroup');
    var barangayGroup = document.getElementById('barangayGroup');
    var municipalitySelect = document.getElementById('municipalitySelect');
    var barangaySelect = document.getElementById('barangaySelect');

    if (scope === 'Barangay') {
        barangayGroup.style.display = 'block';
        municipalityGroup.style.display = 'none';
        barangaySelect.required = true;
        municipalitySelect.required = false;
    } else {
        barangayGroup.style.display = 'none';
        municipalityGroup.style.display = 'block';
        barangaySelect.required = false;
        municipalitySelect.required = true;
    }
}

toggleHotlineArea();
</script>

<?php include "../app/includes/footer.php"; ?>
