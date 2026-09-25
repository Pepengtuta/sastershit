<?php
$V_page_title = "Add Alert";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
require_once "../app/includes/functions.php";

if ($_SESSION['role'] != 'pcf' && $_SESSION['role'] != 'pho') {
    header("Location: dashboard.php");
    exit;
}

// Mayor observers cannot publish alerts.
if (is_readonly_role($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '')) {
    header("Location: dashboard.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

// Determine MDR municipality scope.
// - mdr_ibajay => Ibajay only
// - mdr_kalibo => Kalibo only
// - mdr_admin (PCF Admin) => can filter All / Kalibo / Ibajay via dropdown (default All; loads all, filters client-side)
// - other pcf (no MDR sub-role) => all municipalities
// - pho => all (handled separately in the UI)
$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_is_mdr_admin = ($V_role === 'pcf' && $V_sub_role === 'mdr_admin');
// PDRRMO (province-wide rescue sub-role of PHO) may target specific barangays,
// filtered by municipality like the MDR Admin.
$V_is_pdrrmo = ($V_role === 'pho' && $V_sub_role === 'pdrrmo');
$V_is_pho_admin = ($V_role === 'pho' && !$V_is_pdrrmo);
$V_scope_municipality = null;

if ($V_role === 'pcf' && in_array($V_sub_role, ['mdr_kalibo', 'mdr_ibajay'], true)) {
    $V_scope_municipality = ($V_sub_role === 'mdr_kalibo') ? 'Kalibo' : 'Ibajay';
}

$V_barangay_query = "SELECT * FROM barangays WHERE status = 'Active'";
if ($V_scope_municipality) {
    $V_scope_esc = mysqli_real_escape_string($connection, $V_scope_municipality);
    $V_barangay_query .= " AND municipality = '$V_scope_esc'";
}
$V_barangay_query .= " ORDER BY name ASC";
$V_barangay_result = mysqli_query($connection, $V_barangay_query);

function time_hour_options() {
    for ($i = 1; $i <= 12; $i++) {
        echo '<option value="' . $i . '">' . $i . '</option>';
    }
}

function time_minute_options() {
    for ($i = 0; $i <= 59; $i++) {
        $minute = str_pad($i, 2, '0', STR_PAD_LEFT);
        echo '<option value="' . $minute . '">' . $minute . '</option>';
    }
}
?>

<style>
.alert-checklist {
    max-height: 270px;
    overflow-y: auto;
}
.time-row .form-select {
    min-width: 80px;
}
</style>

<div class="panel-card form-panel">
    <div class="panel-header d-flex justify-content-between align-items-center gap-3">
        <div>
            <h2>Add Alert / Advisory</h2>
            <p>Create an advisory and send it to selected barangays.</p>
        </div>

        <a href="alert.php" class="btn btn-light border">Back to Alerts</a>
    </div>

    <?php if (isset($_GET['error'])) { ?>
        <div class="alert alert-danger mx-3 mt-3 py-2">Please complete the required fields and select at least one barangay.</div>
    <?php } ?>

    <div class="panel-body">
        <form method="POST" action="../app/alerts/save-alert.php">
            <?php echo csrf_field(); ?>
            <div class="row g-4">
                <div class="col-lg-6">
                    <div class="mb-3">
                        <label class="form-label">Alert Title *</label>
                        <input type="text" name="N_title" class="form-control" required>
                    </div>

                    <div class="row g-3">
                        <div class="col-md-6">
                            <label class="form-label">Alert Type *</label>
                            <select name="N_alert_type" class="form-select" required>
                                <option value="">Select Type</option>
                                <?php
                                $V_at_emojis = [
                                    'Typhoon' => '🌪️', 'Flood' => '🌊', 'Storm Surge' => '🌊',
                                    'Earthquake' => '🌎', 'Landslide' => '⛰️', 'Fire' => '🔥',
                                    'Drought / El Niño' => '☀️', 'Disease Outbreak' => '🦠',
                                    'Accident / Mass Casualty Incident' => '🚑', 'Other' => '⚠️',
                                ];
                                $V_at_list = ['Typhoon', 'Flood', 'Storm Surge', 'Earthquake', 'Landslide', 'Fire', 'Drought / El Niño', 'Disease Outbreak', 'Accident / Mass Casualty Incident', 'Other'];
                                foreach ($V_at_list as $V_at) {
                                    $V_emoji = $V_at_emojis[$V_at] ?? '⚠️';
                                    echo '<option value="' . h($V_at) . '">' . $V_emoji . ' ' . h($V_at) . '</option>';
                                }
                                ?>
                            </select>
                        </div>

                        <div class="col-md-6">
                            <label class="form-label">Severity *</label>
                            <select name="N_severity" class="form-select" required>
                                <option value="Low">Low</option>
                                <option value="Moderate">Moderate</option>
                                <option value="High">High</option>
                                <option value="Critical">Critical</option>
                            </select>
                        </div>
                    </div>

                    <div class="mt-3 mb-3">
                        <label class="form-label">Status</label>
                        <select name="N_status" class="form-select">
                            <option value="Active">Active</option>
                            <option value="Inactive">Inactive</option>
                            <option value="Expired">Expired</option>
                        </select>
                    </div>

                    <div class="border rounded p-3 mb-3">
                        <h3 class="form-section-title mb-3">Start Date and Time</h3>

                        <div class="row g-3 align-items-end time-row">
                            <div class="col-md-5">
                                <label class="form-label">Start Date *</label>
                                <input type="date" name="N_start_date" id="startDate" class="form-control" required>
                            </div>

                            <div class="col-md-2">
                                <label class="form-label">Hour</label>
                                <select name="N_start_hour" id="startHour" class="form-select" required>
                                    <?php time_hour_options(); ?>
                                </select>
                            </div>

                            <div class="col-md-2">
                                <label class="form-label">Minute</label>
                                <select name="N_start_minute" id="startMinute" class="form-select" required>
                                    <?php time_minute_options(); ?>
                                </select>
                            </div>

                            <div class="col-md-3">
                                <label class="form-label">AM / PM</label>
                                <select name="N_start_ampm" id="startAmpm" class="form-select" required>
                                    <option value="AM">AM</option>
                                    <option value="PM">PM</option>
                                </select>
                            </div>
                        </div>
                    </div>

                    <div class="border rounded p-3">
                        <h3 class="form-section-title mb-3">End Date and Time</h3>

                        <div class="row g-3 align-items-end time-row">
                            <div class="col-md-5">
                                <label class="form-label">End Date *</label>
                                <input type="date" name="N_end_date" id="endDate" class="form-control" required>
                            </div>

                            <div class="col-md-2">
                                <label class="form-label">Hour</label>
                                <select name="N_end_hour" id="endHour" class="form-select" required>
                                    <?php time_hour_options(); ?>
                                </select>
                            </div>

                            <div class="col-md-2">
                                <label class="form-label">Minute</label>
                                <select name="N_end_minute" id="endMinute" class="form-select" required>
                                    <?php time_minute_options(); ?>
                                </select>
                            </div>

                            <div class="col-md-3">
                                <label class="form-label">AM / PM</label>
                                <select name="N_end_ampm" id="endAmpm" class="form-select" required>
                                    <option value="AM">AM</option>
                                    <option value="PM">PM</option>
                                </select>
                            </div>
                        </div>

                        <small class="text-muted d-block mt-2">Default end time is 3 days from the current device date and time.</small>
                    </div>
                </div>

                <div class="col-lg-6">
                    <div class="mb-3">
                        <?php if ($V_is_pho_admin) { ?>
                            <label class="form-label mb-2">Affected Barangays</label>
                            <div class="border rounded p-3 bg-light">
                                <p class="mb-0"><strong>All barangays</strong> &mdash; Provincial advisories are sent to every barangay automatically.</p>
                            </div>
                        <?php } else { ?>
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <label class="form-label mb-0">Affected Barangays *</label>
                                <button type="button" class="btn btn-light border btn-sm" onclick="toggleAllBarangays()">Select / Clear All</button>
                            </div>

                            <?php if ($V_is_mdr_admin || $V_is_pdrrmo) { ?>
                                <div class="mb-2 d-flex align-items-center gap-2">
                                    <label class="form-label mb-0 small text-muted">Filter by municipality:</label>
                                    <select class="form-select form-select-sm" style="max-width:200px;" onchange="filterMdrBarangays(this.value);">
                                        <option value="">All</option>
                                        <option value="Kalibo">Kalibo</option>
                                        <option value="Ibajay">Ibajay</option>
                                    </select>
                                </div>
                            <?php } elseif ($V_scope_municipality) { ?>
                                <div class="small text-muted mb-2">Showing <?php echo h($V_scope_municipality); ?> barangays for your MDR account.</div>
                            <?php } ?>

                            <div class="border rounded p-3 checkbox-list alert-checklist">
                                <div id="barangayChecklist">
                                <?php if ($V_barangay_result && mysqli_num_rows($V_barangay_result) > 0) { ?>
                                    <?php while ($row = mysqli_fetch_assoc($V_barangay_result)) { ?>
                                        <label class="form-check" data-muni="<?php echo h($row['municipality']); ?>">
                                            <input class="form-check-input barangay-checkbox" type="checkbox" name="N_barangays[]" value="<?php echo (int)$row['id']; ?>">
                                            <span class="form-check-label"><?php echo h($row['name']); ?></span>
                                        </label>
                                    <?php } ?>
                                <?php } else { ?>
                                    <p class="text-muted mb-0">No active barangays found.</p>
                                <?php } ?>
                                </div>
                                <p id="barangayEmpty" class="text-muted mb-0" style="display:none;">No active barangays found.</p>
                            </div>
                        <?php } ?>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Message *</label>
                        <textarea name="N_message" class="form-control" rows="7" required></textarea>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Instructions</label>
                        <textarea name="N_instructions" class="form-control" rows="5"></textarea>
                    </div>
                </div>
            </div>

            <hr>

            <button type="submit" class="btn btn-emergency">Publish Alert</button>
            <a href="alert.php" class="btn btn-light border">Cancel</a>
        </form>
    </div>
</div>

<script>
function padNumber(value) {
    return String(value).padStart(2, '0');
}

function setDateTimeFields(prefix, dateValue) {
    var year = dateValue.getFullYear();
    var month = padNumber(dateValue.getMonth() + 1);
    var day = padNumber(dateValue.getDate());

    var hours = dateValue.getHours();
    var minutes = dateValue.getMinutes();
    var ampm = hours >= 12 ? 'PM' : 'AM';
    var hour12 = hours % 12;

    if (hour12 === 0) {
        hour12 = 12;
    }

    document.getElementById(prefix + 'Date').value = year + '-' + month + '-' + day;
    document.getElementById(prefix + 'Hour').value = hour12;
    document.getElementById(prefix + 'Minute').value = padNumber(minutes);
    document.getElementById(prefix + 'Ampm').value = ampm;
}

function setDefaultAlertDateTime() {
    var now = new Date();
    var endDate = new Date(now.getTime());
    endDate.setDate(endDate.getDate() + 3);

    setDateTimeFields('start', now);
    setDateTimeFields('end', endDate);
}

function toggleAllBarangays() {
    var checkboxes = document.querySelectorAll('.barangay-checkbox:not([style*="display: none"])');
    var hasUnchecked = false;

    checkboxes.forEach(function (checkbox) {
        if (!checkbox.checked) {
            hasUnchecked = true;
        }
    });

    checkboxes.forEach(function (checkbox) {
        checkbox.checked = hasUnchecked;
    });
}

// PCF Admin: filter barangays by municipality without reloading.
function filterMdrBarangays(muni) {
    var dispatch = document.getElementById('barangayChecklist');
    if (!dispatch) return;

    var labels = dispatch.querySelectorAll('.form-check[data-muni]');
    var visible = 0;

    labels.forEach(function (label) {
        var show = !muni || label.getAttribute('data-muni') === muni;
        label.style.display = show ? '' : 'none';
        if (show) visible++;
    });

    var empty = document.getElementById('barangayEmpty');
    if (empty) empty.style.display = visible === 0 ? '' : 'none';
}

setDefaultAlertDateTime();
</script>

<?php include "../app/includes/footer.php"; ?>
