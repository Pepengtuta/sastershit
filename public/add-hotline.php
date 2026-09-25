<?php
$V_page_title = "Add Hotline";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/functions.php";

if (!can_manage_hotlines($_SESSION['role'])) {
    header("Location: hotlines.php?denied=1");
    exit;
}

$BarangayResult = mysqli_query($connection, "SELECT * FROM barangays WHERE status = 'Active' ORDER BY name ASC");
$Municipalities = [
    'Altavas', 'Balete', 'Banga', 'Batan', 'Buruanga', 'Ibajay', 'Kalibo', 'Lezo',
    'Libacao', 'Madalag', 'Makato', 'Malinao', 'Malay', 'Nabas', 'New Washington',
    'Numancia', 'Tangalan'
];

$Categories = ['Barangay', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];

$V_prefill_scope = $_GET['scope'] ?? 'Municipal';
if ($V_prefill_scope != 'Barangay' && $V_prefill_scope != 'Municipal') {
    $V_prefill_scope = 'Municipal';
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";
?>

<div class="panel-card form-panel">
    <div class="panel-header">
        <div>
            <h2>Add Hotline</h2>
            <p>Add a municipal or barangay emergency contact.</p>
        </div>
    </div>

    <?php if (isset($_GET['error'])) { ?>
        <div class="alert alert-danger py-2">Please complete the required fields.</div>
    <?php } ?>

    <div class="panel-body">
        <form action="../app/hotlines/save-hotline.php" method="post">
            <?php echo csrf_field(); ?>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Scope *</label>
                    <select name="N_hotline_scope" id="hotlineScope" class="form-select" required onchange="toggleHotlineArea()">
                        <option value="Municipal" <?php if ($V_prefill_scope == 'Municipal') echo 'selected'; ?>>Municipal</option>
                        <option value="Barangay" <?php if ($V_prefill_scope == 'Barangay') echo 'selected'; ?>>Barangay</option>
                    </select>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Category *</label>
                    <select name="N_category" class="form-select" required>
                        <option value="">Select category</option>
                        <?php foreach ($Categories as $category) { ?>
                            <option value="<?php echo h($category); ?>"><?php echo h($category); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-6" id="municipalityGroup">
                    <label class="form-label">Municipality *</label>
                    <select name="N_municipality" id="municipalitySelect" class="form-select">
                        <option value="">Select municipality</option>
                        <?php foreach ($Municipalities as $municipality) { ?>
                            <option value="<?php echo h($municipality); ?>" <?php if ($municipality == 'Kalibo') echo 'selected'; ?>><?php echo h($municipality); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-6" id="barangayGroup">
                    <label class="form-label">Barangay *</label>
                    <select name="N_barangay_id" id="barangaySelect" class="form-select">
                        <option value="">Select barangay</option>
                        <?php while ($barangay = mysqli_fetch_assoc($BarangayResult)) { ?>
                            <option value="<?php echo (int)$barangay['id']; ?>"><?php echo h($barangay['name']); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-12">
                    <label class="form-label">Name / Office *</label>
                    <input type="text" name="N_office_name" class="form-control" placeholder="Example: Kalibo MDRRMO, Poblacion Barangay Hall" required>
                </div>

                <div class="col-md-4">
                    <label class="form-label">Telephone Numbers</label>
                    <input type="text" name="N_telephone_numbers" class="form-control" placeholder="Example: 268-8991">
                </div>

                <div class="col-md-4">
                    <label class="form-label">Cellphone Numbers</label>
                    <input type="text" name="N_cellphone_numbers" class="form-control" placeholder="Example: 09123456789">
                </div>

                <div class="col-md-4">
                    <label class="form-label">Hotline Number</label>
                    <input type="text" name="N_hotline_number" class="form-control" placeholder="Example: 159">
                </div>

                <div class="col-md-12">
                    <label class="form-label">Remarks</label>
                    <textarea name="N_remarks" class="form-control" rows="3" placeholder="Optional notes"></textarea>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Status</label>
                    <select name="N_status" class="form-select">
                        <option value="Active">Active</option>
                        <option value="Inactive">Inactive</option>
                    </select>
                </div>
            </div>

            <div class="mt-3">
                <input type="submit" value="Save Hotline" class="btn btn-emergency">
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
