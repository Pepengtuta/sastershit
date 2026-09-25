<?php
$V_page_title = "Edit Incident Report";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

if ($_SESSION['role'] != 'barangay') {
    header("Location: incident-reports.php");
    exit;
}

$V_barangay_id = (int)($_SESSION['barangay_id'] ?? 0);
$V_barangay_name = $_SESSION['barangay_name'] ?? '';
$V_report_id = (int)($_GET['id'] ?? 0);

if ($V_report_id <= 0) {
    header("Location: incident-reports.php");
    exit;
}

// Load the report and confirm it belongs to this barangay.
$ReportStmt = mysqli_prepare($connection, "SELECT * FROM incident_reports WHERE id = ? AND barangay_id = ? LIMIT 1");
mysqli_stmt_bind_param($ReportStmt, "ii", $V_report_id, $V_barangay_id);
mysqli_stmt_execute($ReportStmt);
$ReportResult = mysqli_stmt_get_result($ReportStmt);
$V_report = mysqli_fetch_assoc($ReportResult);

if (!$V_report) {
    header("Location: incident-reports.php");
    exit;
}

// Only the report's own reporter or the Barangay Chairman may edit it.
$V_is_reporter = ((int)$V_report['user_id'] === (int)($_SESSION['user_id'] ?? 0));
if (($_SESSION['sub_role'] ?? '') !== 'captain' && !$V_is_reporter) {
    header("Location: incident-reports.php");
    exit;
}

// Only Pending reports can be edited by the barangay.
if ($V_report['status'] != 'Pending') {
    header("Location: incident-reports.php?locked=1");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

// Active disaster types (keep the stored one too, even if now inactive).
$V_disaster_names = [];
$DisasterResult = mysqli_query($connection, "SELECT * FROM disaster_types WHERE status = 'Active' ORDER BY id ASC");
while ($V_d = mysqli_fetch_assoc($DisasterResult)) { $V_disaster_names[] = $V_d['name']; }
$V_stored_type = $V_report['disaster_type'];
$V_stored_type_present = in_array($V_stored_type, $V_disaster_names, true);

// Available/Open centers for this barangay; keep the currently selected center
// listed even if it is no longer available/open.
$CenterQuery = "SELECT * FROM evacuation_centers WHERE barangay = ? AND status IN ('Available', 'Open') ORDER BY center_name ASC";
$CenterStmt = mysqli_prepare($connection, $CenterQuery);
mysqli_stmt_bind_param($CenterStmt, "s", $V_barangay_name);
mysqli_stmt_execute($CenterStmt);
$CenterResult = mysqli_stmt_get_result($CenterStmt);
$V_centers = [];
while ($V_c = mysqli_fetch_assoc($CenterResult)) { $V_centers[] = $V_c; }

$V_selected_center_id = (int)($V_report['evacuation_center_id'] ?? 0);
$V_selected_center_present = false;
foreach ($V_centers as $V_c) { if ((int)$V_c['id'] === $V_selected_center_id) { $V_selected_center_present = true; } }
if ($V_selected_center_id > 0 && !$V_selected_center_present) {
    $ExtraStmt = mysqli_prepare($connection, "SELECT * FROM evacuation_centers WHERE id = ? LIMIT 1");
    mysqli_stmt_bind_param($ExtraStmt, "i", $V_selected_center_id);
    mysqli_stmt_execute($ExtraStmt);
    $ExtraResult = mysqli_stmt_get_result($ExtraStmt);
    $V_extra = mysqli_fetch_assoc($ExtraResult);
    if ($V_extra) { $V_centers[] = $V_extra; }
}

// Pre-parse the saved incident date/time into date + 12h pieces.
$V_date_val = '';
$V_hour_val = 12;
$V_ampm_val = 'AM';
$V_minute_val = '00';
if (!empty($V_report['incident_datetime'])) {
    $V_ts = strtotime($V_report['incident_datetime']);
    if ($V_ts !== false) {
        $V_date_val = date('Y-m-d', $V_ts);
        $V_hour_val = (int)date('g', $V_ts);
        $V_ampm_val = date('A', $V_ts);
        $V_minute_val = date('i', $V_ts);
    }
}
$V_minute_round = (int)(round((int)$V_minute_val / 5) * 5);
if ($V_minute_round >= 60) { $V_minute_round = 55; }
$V_minute_sel = str_pad((string)$V_minute_round, 2, '0', STR_PAD_LEFT);

// Assistance list -> array for checkbox prefill.
$V_assistance_selected = [];
if (!empty($V_report['assistance_needed'])) {
    foreach (explode(',', $V_report['assistance_needed']) as $V_a) {
        $V_a = trim($V_a);
        if ($V_a != '') { $V_assistance_selected[] = $V_a; }
    }
}
$V_assist_options = ['Medical Team', 'Ambulance', 'Food Packs', 'Water', 'Rescue Team', 'Shelter Supplies', 'Clearing Operations', 'Others'];

// Road / Bridge Accessibility prefill.
$V_road_status_val = ($V_report['road_status'] ?? 'Passable');
if (!in_array($V_road_status_val, ['Passable', 'Partially Passable', 'Obstructed'], true)) {
    $V_road_status_val = 'Passable';
}

$V_road_causes_selected = [];
if (!empty($V_report['road_blockage_causes'])) {
    foreach (explode(',', $V_report['road_blockage_causes']) as $V_cause) {
        $V_cause = trim($V_cause);
        if ($V_cause != '') { $V_road_causes_selected[] = $V_cause; }
    }
}
$V_road_causes_list = ['Fallen Tree', 'Downed Power Line / Electric Post', 'Flooding / Deep Water', 'Landslide / Debris / Mud', 'Damaged / Collapsed Bridge', 'Other / Cannot Inspect'];
?>

<div class="panel-card" style="max-width: 980px; margin: 0 auto;">
    <div class="panel-header">
        <div>
            <h2>Edit Incident Report</h2>
            <p>You can edit this report while it is still <strong>Pending</strong>. Once Municipal acts on it, it can no longer be changed here.</p>
        </div>
    </div>

    <div class="panel-body">
        <?php if (isset($_GET['error'])) { ?>
            <div class="alert alert-danger py-2">
                <?php if ($_GET['error'] === 'number') { ?>
                    Affected, Injured, Dead, Missing, and evacuation counts must be valid non-negative numbers.
                <?php } else { ?>
                    Please check required fields.
                <?php } ?>
            </div>
        <?php } ?>
        <?php if (isset($_GET['upload_warn']) && !empty($_SESSION['upload_errors'] ?? null)) { ?>
            <div class="alert alert-warning py-2">
                <strong>Evidence upload issues:</strong><br>
                <?php foreach ($_SESSION['upload_errors'] as $err) { echo htmlspecialchars($err) . '<br>'; } ?>
                <?php unset($_SESSION['upload_errors']); ?>
            </div>
        <?php } ?>

        <form action="../app/reports/update-report.php" method="post" enctype="multipart/form-data">
            <?php echo csrf_field(); ?>
            <input type="hidden" name="report_id" value="<?php echo (int)$V_report['id']; ?>">
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Barangay</label>
                    <input type="text" class="form-control" value="<?php echo h($V_barangay_name); ?>" readonly>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Disaster Type *</label>
                    <select name="disaster_type" class="form-select" required>
                        <option value="">Select disaster type</option>
                        <?php
                        $V_dt_emojis = [
                            'Typhoon' => '🌪️', 'Flood' => '🌊', 'Storm Surge' => '🌊',
                            'Earthquake' => '🌎', 'Landslide' => '⛰️', 'Fire' => '🔥',
                            'Drought / El Niño' => '☀️', 'Disease Outbreak' => '🦠',
                            'Accident / Mass Casualty Incident' => '🚑', 'Others' => '⚠️',
                        ];
                        ?>
                        <?php if ($V_stored_type != '' && !$V_stored_type_present) { ?>
                            <option value="<?php echo h($V_stored_type); ?>" selected><?php echo $V_dt_emojis[$V_stored_type] ?? '⚠️'; ?> <?php echo h($V_stored_type); ?> (current)</option>
                        <?php } ?>
                        <?php foreach ($V_disaster_names as $V_name) { ?>
                            <option value="<?php echo h($V_name); ?>" <?php echo ($V_name == $V_stored_type) ? 'selected' : ''; ?>><?php echo $V_dt_emojis[$V_name] ?? '⚠️'; ?> <?php echo h($V_name); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Exact Location</label>
                    <input type="text" name="exact_location" id="exactLocation" class="form-control" value="<?php echo h($V_report['exact_location'] ?? ''); ?>" placeholder="Sitio / street / landmark" required>
                    <div class="form-text">Edit the sitio / street / landmark if needed.</div>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Road Status</label>
                    <select name="road_status" id="roadStatus" class="form-select">
                        <option value="Passable" <?php echo ($V_road_status_val == 'Passable') ? 'selected' : ''; ?>>Passable</option>
                        <option value="Partially Passable" <?php echo ($V_road_status_val == 'Partially Passable') ? 'selected' : ''; ?>>Partially Passable</option>
                        <option value="Obstructed" <?php echo ($V_road_status_val == 'Obstructed') ? 'selected' : ''; ?>>Obstructed</option>
                    </select>
                    <div class="form-text">"Partially" = motorcycles / small vehicles can pass but not trucks or ambulances.</div>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Road / Bridge Name or Landmark</label>
                    <input type="text" name="road_location" id="roadLocation" class="form-control" value="<?php echo h($V_report['road_location'] ?? ''); ?>" placeholder="e.g., Kalibo–Ibajay Rd near Mabusao Bridge">
                    <div class="form-text">Optional. Which road/bridge is affected so teams know where to reroute.</div>
                </div>
            </div>

            <div id="roadCausesSection" class="mt-2" style="display: <?php echo ($V_road_status_val == 'Passable') ? 'none' : 'block'; ?>;">
                <label class="form-label">Cause of Blockage <small class="text-muted">(select all that apply)</small></label>
                <div class="assistance-grid">
                    <?php foreach ($V_road_causes_list as $V_cause) { ?>
                        <label class="check-card"><input type="checkbox" name="road_blockage_causes[]" value="<?php echo h($V_cause); ?>" <?php echo in_array($V_cause, $V_road_causes_selected, true) ? 'checked' : ''; ?>> <?php echo h($V_cause); ?></label>
                    <?php } ?>
                </div>
                <div class="form-text">If you know more than one cause, tick them all (e.g., a fallen tree and a downed power line together).</div>
            </div>

                <div class="col-md-6">
                    <label class="form-label">Incident Date and Time</label>
                    <div class="row g-2">
                        <div class="col-md-5 col-12">
                            <input type="date" name="incident_date" id="incidentDate" class="form-control" value="<?php echo h($V_date_val); ?>" required>
                        </div>

                        <div class="col-md-2 col-4">
                            <select name="incident_hour" id="incidentHour" class="form-select" required>
                                <?php for ($i = 1; $i <= 12; $i++) { ?>
                                    <option value="<?php echo $i; ?>" <?php echo ($i == $V_hour_val) ? 'selected' : ''; ?>><?php echo $i; ?></option>
                                <?php } ?>
                            </select>
                        </div>

                        <div class="col-md-2 col-4">
                            <select name="incident_minute" id="incidentMinute" class="form-select" required>
                                <?php for ($i = 0; $i <= 55; $i += 5) { $V_mm = str_pad($i, 2, '0', STR_PAD_LEFT); ?>
                                    <option value="<?php echo $V_mm; ?>" <?php echo ($V_mm === $V_minute_sel) ? 'selected' : ''; ?>>
                                        <?php echo $V_mm; ?>
                                    </option>
                                <?php } ?>
                            </select>
                        </div>

                        <div class="col-md-3 col-4">
                            <select name="incident_ampm" id="incidentAmpm" class="form-select" required>
                                <option value="AM" <?php echo ($V_ampm_val == 'AM') ? 'selected' : ''; ?>>AM</option>
                                <option value="PM" <?php echo ($V_ampm_val == 'PM') ? 'selected' : ''; ?>>PM</option>
                            </select>
                        </div>
                    </div>
                    <div class="form-text">Edit the date, hour, minute, and AM/PM if needed.</div>
                </div>
            </div>

            <hr>
            <h3 class="form-section-title">Incident Map</h3>
            <div class="simple-note mb-2">
                The map starts at your barangay. If the browser allows location access, it will try to use your device location. You can also click or drag the marker.
            </div>

            <div id="incidentLocationMap" style="height: 350px; border: 1px solid #ddd; border-radius: 8px;"></div>

            <div id="pinBoundaryWarning" class="alert alert-warning py-2 px-3 mt-2 small mb-0" style="display:none;">
                The marker is outside your <span id="pinBoundaryWarningName"></span> boundary. You can still submit, but the report will be marked for review.
            </div>

            <div class="row g-3 mt-1">
                <div class="col-md-6">
                    <label class="form-label">Latitude</label>
                    <input type="text" name="N_latitude" id="incidentLatitude" class="form-control" value="<?php echo h($V_report['latitude'] ?? ''); ?>" readonly>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Longitude</label>
                    <input type="text" name="N_longitude" id="incidentLongitude" class="form-control" value="<?php echo h($V_report['longitude'] ?? ''); ?>" readonly>
                </div>
            </div>

            <hr>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Affected People</label>
                    <input type="number" name="affected_people" class="form-control" min="0" value="<?php echo (int)$V_report['affected_people']; ?>">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Injured</label>
                    <input type="number" name="injured" class="form-control" min="0" value="<?php echo (int)$V_report['injured']; ?>">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Dead</label>
                    <input type="number" name="dead" class="form-control" min="0" value="<?php echo (int)$V_report['dead']; ?>">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Missing</label>
                    <input type="number" name="missing" class="form-control" min="0" value="<?php echo (int)$V_report['missing']; ?>">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Evacuation Needed?</label>
                    <select name="evacuation_needed" id="evacuationNeeded" class="form-select">
                        <option value="No" <?php echo ($V_report['evacuation_needed'] == 'No') ? 'selected' : ''; ?>>No</option>
                        <option value="Yes" <?php echo ($V_report['evacuation_needed'] == 'Yes') ? 'selected' : ''; ?>>Yes</option>
                    </select>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Evacuation Center</label>
                    <select name="evacuation_center_id" id="evacuationCenter" class="form-select">
                        <option value="">None / Not applicable</option>
                        <?php foreach ($V_centers as $center) { ?>
                            <option value="<?php echo (int)$center['id']; ?>" <?php echo ((int)$center['id'] === $V_selected_center_id) ? 'selected' : ''; ?>>
                                <?php echo h($center['center_name']); ?> - <?php echo h($center['status']); ?>
                            </option>
                        <?php } ?>
                    </select>
                    <div class="form-text">Available/open centers in <?php echo h($V_barangay_name); ?> are listed. Your current selection is kept.</div>
                </div>
            </div>

            <div id="headcountSection" style="display: <?php echo ($V_report['evacuation_needed'] == 'Yes' && $V_selected_center_id > 0) ? 'block' : 'none'; ?>;">
                <hr>
                <h3 class="form-section-title">Evacuation Headcount</h3>
                <div class="simple-note mb-2">Quick headcount at the evacuation center. Used by Municipal for supply coordination and DSWD reporting.</div>
                <div class="row g-3">
                    <div class="col-md-3">
                        <label class="form-label">No. of Households</label>
                        <input type="number" name="evac_households" id="evacHouseholds" class="form-control" min="0" value="<?php echo (int)($V_report['evac_households'] ?? 0); ?>">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">No. of Adults</label>
                        <input type="number" name="evac_adults" id="evacAdults" class="form-control" min="0" value="<?php echo (int)($V_report['evac_adults'] ?? 0); ?>">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">No. of Children</label>
                        <input type="number" name="evac_children" id="evacChildren" class="form-control" min="0" value="<?php echo (int)($V_report['evac_children'] ?? 0); ?>">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">No. of Family Members</label>
                        <input type="number" name="evac_members" id="evacMembers" class="form-control" min="0" value="<?php echo (int)($V_report['evac_members'] ?? 0); ?>">
                    </div>
                </div>
            </div>

            <hr>
            <h3 class="form-section-title">Description</h3>
            <textarea name="description" class="form-control" rows="5" placeholder="Describe what happened..." required><?php echo h($V_report['description'] ?? ''); ?></textarea>

            <!-- DISABLED: Assistance Needed — to be moved to Municipal level
            <hr>
            <h3 class="form-section-title">Assistance Needed</h3>
            <div class="assistance-grid">
                <?php foreach ($V_assist_options as $V_opt) { ?>
                    <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="<?php echo h($V_opt); ?>" <?php echo in_array($V_opt, $V_assistance_selected, true) ? 'checked' : ''; ?>> <?php echo h($V_opt); ?></label>
                <?php } ?>
            </div>
            -->

            <hr>
            <h3 class="form-section-title">Current Attachments</h3>
            <div class="mb-2"><?php render_incident_attachments($connection, (int)$V_report['id']); ?></div>
            <div class="simple-note">Existing photos and videos stay attached. You can add more below.</div>

            <hr>
            <h3 class="form-section-title">Add More Evidence</h3>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Photos <small class="text-muted">(max <?php echo UPLOAD_MAX_PHOTOS; ?>, <?php echo UPLOAD_MAX_PHOTO_MB; ?> MB each)</small></label>
                    <input type="file" name="photos[]" class="form-control" accept="image/jpeg,image/png,image/gif,image/webp" multiple max="5">
                </div>
                <div class="col-md-6">
                    <label class="form-label">Videos <small class="text-muted">(max <?php echo UPLOAD_MAX_VIDEOS; ?>, <?php echo UPLOAD_MAX_VIDEO_MB; ?> MB each)</small></label>
                    <input type="file" name="videos[]" class="form-control" accept="video/mp4,video/quicktime,video/x-msvideo,video/x-matroska,video/webm" multiple max="2">
                </div>
                <div class="col-12">
                    <div class="simple-note">Photos: JPG, PNG, GIF, WebP. Videos: MP4, MOV, AVI, MKV, WebM.</div>
                </div>
            </div>

            <div class="d-flex gap-2 justify-content-end mt-4">
                <a href="incident-reports.php" class="btn btn-light border">Cancel</a>
                <input type="submit" value="Save Changes" class="btn btn-emergency">
            </div>
        </form>
    </div>
</div>

<script>
var V_barangayName = <?php echo json_encode($V_barangay_name); ?>;
var V_municipality = <?php echo json_encode($_SESSION['municipality'] ?? 'Kalibo'); ?>;
var isIbajayPrimary = V_municipality === 'Ibajay';
var V_nameKey = isIbajayPrimary ? 'name' : 'adm4_en';
var V_geojsonPath = isIbajayPrimary ? 'asset/data/ibajay_puroks.geojson' : 'asset/data/kalibo_barangays.geojson';
var V_savedLat = <?php echo ($V_report['latitude'] !== null && $V_report['latitude'] !== '') ? json_encode((float)$V_report['latitude']) : 'null'; ?>;
var V_savedLng = <?php echo ($V_report['longitude'] !== null && $V_report['longitude'] !== '') ? json_encode((float)$V_report['longitude']) : 'null'; ?>;
var V_defaultLocation = isIbajayPrimary ? [11.7331, 122.1590] : [11.7060, 122.3640];
var V_map = L.map('incidentLocationMap').setView(V_defaultLocation, 14);
var V_marker = null;
var V_circle = null;
var V_boundaryLayer = null;
var V_ownBoundaryGeom = null;
var V_defaultExactLocation = V_barangayName + ', ' + V_municipality + ', Aklan';
var V_exactLocationEdited = false;

function setCurrentDeviceDateTime() {
    var now = new Date();

    var year = now.getFullYear();
    var month = String(now.getMonth() + 1).padStart(2, '0');
    var day = String(now.getDate()).padStart(2, '0');

    var hours24 = now.getHours();
    var minutes = now.getMinutes();
    var ampm = hours24 >= 12 ? 'PM' : 'AM';
    var hour12 = hours24 % 12;

    if (hour12 === 0) {
        hour12 = 12;
    }

    var roundedMinutes = Math.round(minutes / 5) * 5;

    if (roundedMinutes === 60) {
        roundedMinutes = 55;
    }

    document.getElementById('incidentDate').value = year + '-' + month + '-' + day;
    document.getElementById('incidentHour').value = String(hour12);
    document.getElementById('incidentMinute').value = String(roundedMinutes).padStart(2, '0');
    document.getElementById('incidentAmpm').value = ampm;
}

function setupExactLocationField() {
    var exactInput = document.getElementById('exactLocation');

    exactInput.addEventListener('input', function() {
        V_exactLocationEdited = true;
    });
}

function updateExactLocationFromDevice(lat, lng) {
    var exactInput = document.getElementById('exactLocation');

    if (!V_exactLocationEdited || exactInput.value.trim() === '' || exactInput.value.trim() === V_defaultExactLocation) {
        exactInput.value = 'Current device location near ' + V_barangayName + ' (Lat: ' + Number(lat).toFixed(7) + ', Lng: ' + Number(lng).toFixed(7) + ')';
    }
}

setupExactLocationField();

L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors'
}).addTo(V_map);

function setIncidentMarker(lat, lng, zoomMap) {
    var position = [lat, lng];

    if (V_marker) {
        V_marker.setLatLng(position);
    } else {
        V_marker = L.marker(position, { draggable: true }).addTo(V_map);

        V_marker.on('dragend', function() {
            var pos = V_marker.getLatLng();
            setIncidentInputs(pos.lat, pos.lng);
        });
    }

    if (V_circle) {
        V_circle.setLatLng(position);
    } else {
        V_circle = L.circle(position, {
            radius: 100,
            color: '#DC2626',
            weight: 2,
            fillColor: '#DC2626',
            fillOpacity: 0.12
        }).addTo(V_map);
    }

    setIncidentInputs(lat, lng);

    if (zoomMap) {
        V_map.setView(position, 17);
    }
}

function setIncidentInputs(lat, lng) {
    document.getElementById('incidentLatitude').value = Number(lat).toFixed(7);
    document.getElementById('incidentLongitude').value = Number(lng).toFixed(7);
    V_updatePinBoundaryWarning();
}

/* Client mirror of the server's point_in_rings/point_in_rings_tolerance in
   app/includes/functions.php. Same ray-casting rule, same 0.0001 degree
   (~11 m) boundary tolerance so the browser warning matches the server flag. */
function V_pointInRing(lat, lng, ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        var xi = ring[i][0], yi = ring[i][1];
        var xj = ring[j][0], yj = ring[j][1];
        if (((yi > lat) !== (yj > lat)) && (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
            inside = !inside;
        }
    }
    return inside;
}

function V_pointInOuterRings(lat, lng, geometry) {
    if (!geometry || !geometry.coordinates) return false;
    var ringSets = geometry.type === 'MultiPolygon' ? geometry.coordinates : [geometry.coordinates];
    for (var r = 0; r < ringSets.length; r++) {
        if (ringSets[r][0] && ringSets[r][0].length >= 3 && V_pointInRing(lat, lng, ringSets[r][0])) {
            return true;
        }
    }
    return false;
}

function V_pinWithinBoundary(lat, lng) {
    if (!V_ownBoundaryGeom) return true;
    var EPS = 0.0001;
    if (V_pointInOuterRings(lat, lng, V_ownBoundaryGeom)) return true;
    return V_pointInOuterRings(lat + EPS, lng, V_ownBoundaryGeom)
        || V_pointInOuterRings(lat - EPS, lng, V_ownBoundaryGeom)
        || V_pointInOuterRings(lat, lng + EPS, V_ownBoundaryGeom)
        || V_pointInOuterRings(lat, lng - EPS, V_ownBoundaryGeom);
}

function V_updatePinBoundaryWarning() {
    var warnEl = document.getElementById('pinBoundaryWarning');
    if (!V_ownBoundaryGeom) return true;
    var lat = parseFloat(document.getElementById('incidentLatitude').value);
    var lng = parseFloat(document.getElementById('incidentLongitude').value);
    var ok = V_pinWithinBoundary(lat, lng);
    if (warnEl) {
        document.getElementById('pinBoundaryWarningName').textContent = V_barangayName;
        warnEl.style.display = ok ? 'none' : 'block';
    }
    return ok;
}

document.querySelector('form[action="../app/reports/update-report.php"]').addEventListener('submit', function(e) {
    if (V_ownBoundaryGeom && !V_updatePinBoundaryWarning()) {
        e.preventDefault();
        if (confirm('The marker is outside the ' + V_barangayName + ' boundary. Save this report anyway?')) {
            this.submit();
        }
    }
});

/* Use the site theme color for the map shapes so they match the rest of
   the page. Falls back to the original red if unavailable. */
var V_themeStyles = getComputedStyle(document.documentElement);
var V_primaryColor = (V_themeStyles.getPropertyValue('--primary') || '#dc3545').trim();

var selectedStyle = {
    color: V_primaryColor,
    weight: 3,
    fillColor: V_primaryColor,
    fillOpacity: 0.30
};

var defaultStyle = {
    color: '#555555',
    weight: 1,
    fillColor: '#ffffff',
    fillOpacity: 0.08
};

var hoverStyle = {
    color: V_primaryColor,
    weight: 2,
    fillColor: V_primaryColor,
    fillOpacity: 0.15
};

function boundaryStyle(feature) {
    var name = feature.properties[V_nameKey] || '';
    if (name === V_barangayName) {
        return selectedStyle;
    }
    return defaultStyle;
}

function setupDefaultFromBarangay(data) {
    var selectedLayer = null;

    V_boundaryLayer = L.geoJSON(data, {
        style: boundaryStyle,
        onEachFeature: function(feature, layer) {
            var name = feature.properties[V_nameKey] || '';

            if (name === V_barangayName) {
                selectedLayer = layer;
                V_ownBoundaryGeom = feature.geometry;
            }

            layer.bindTooltip(name, { sticky: true });

            layer.on({
                mouseover: function() {
                    if (name !== V_barangayName) {
                        layer.setStyle(hoverStyle);
                    } else {
                        layer.setStyle({
                            color: V_primaryColor,
                            weight: 3,
                            fillColor: V_primaryColor,
                            fillOpacity: 0.45
                        });
                    }
                },
                mouseout: function() {
                    if (name !== V_barangayName) {
                        V_boundaryLayer.resetStyle(layer);
                    } else {
                        layer.setStyle(selectedStyle);
                    }
                }
            });
        }
    }).addTo(V_map);

    if (V_savedLat !== null && V_savedLng !== null) {
        if (selectedLayer) {
            V_map.fitBounds(selectedLayer.getBounds(), { padding: [20, 20] });
        }
        setIncidentMarker(V_savedLat, V_savedLng, true);
    } else if (selectedLayer) {
        var bounds = selectedLayer.getBounds();
        var center = bounds.getCenter();
        V_defaultLocation = [center.lat, center.lng];
        V_map.fitBounds(bounds, { padding: [20, 20] });
        setIncidentMarker(center.lat, center.lng, false);
    } else {
        setIncidentMarker(V_defaultLocation[0], V_defaultLocation[1], false);
    }

    // Editing keeps the saved location; no device-location override here.
}

function tryDeviceLocation() {
    if (!navigator.geolocation) {
        return;
    }

    navigator.geolocation.getCurrentPosition(
        function(position) {
            var lat = position.coords.latitude;
            var lng = position.coords.longitude;
            setIncidentMarker(lat, lng, true);
            updateExactLocationFromDevice(lat, lng);
        },
        function(error) {
            console.log('Device location not allowed or unavailable. Barangay default location is used.');
        },
        {
            enableHighAccuracy: true,
            timeout: 8000,
            maximumAge: 0
        }
    );
}

V_map.on('click', function(e) {
    setIncidentMarker(e.latlng.lat, e.latlng.lng, false);
});

/* Muted background style for the non-primary municipality layer */
var backgroundStyle = {
    color: '#94a3b8',
    weight: 1,
    opacity: 0.5,
    fillColor: '#94a3b8',
    fillOpacity: 0.03
};

var backgroundHoverStyle = {
    color: '#94a3b8',
    weight: 1.2,
    opacity: 0.7,
    fillColor: '#94a3b8',
    fillOpacity: 0.06
};

function loadSecondaryLayer(url, nameKey) {
    fetch(url)
        .then(function(resp) { if (!resp.ok) throw new Error('Not found'); return resp.json(); })
        .then(function(data) {
            L.geoJSON(data, {
                style: backgroundStyle,
                onEachFeature: function(feature, layer) {
                    var props = feature.properties || {};
                    var layerName = props[nameKey] || 'Unknown';
                    layer.bindTooltip(layerName, { sticky: true });
                    layer.on({
                        mouseover: function() { layer.setStyle(backgroundHoverStyle); },
                        mouseout: function() { layer.resetStyle(layer); }
                    });
                }
            }).addTo(V_map);
        })
        .catch(function() {});
}

fetch(V_geojsonPath)
    .then(function(response) {
        if (!response.ok) {
            throw new Error('GeoJSON file not found.');
        }
        return response.json();
    })
    .then(function(data) {
        setupDefaultFromBarangay(data);

        /* Load the other municipality as a muted background layer */
        loadSecondaryLayer(isIbajayPrimary ? 'asset/data/kalibo_barangays.geojson' : 'asset/data/ibajay_puroks.geojson', isIbajayPrimary ? 'adm4_en' : 'name');
    })
    .catch(function(error) {
        console.log(error.message);
        if (V_savedLat !== null && V_savedLng !== null) {
            setIncidentMarker(V_savedLat, V_savedLng, true);
        } else {
            setIncidentMarker(V_defaultLocation[0], V_defaultLocation[1], false);
        }
    });

function toggleHeadcount() {
    var needed = document.getElementById('evacuationNeeded').value;
    var center = document.getElementById('evacuationCenter').value;
    var section = document.getElementById('headcountSection');
    section.style.display = (needed === 'Yes' && center !== '') ? 'block' : 'none';
}

document.getElementById('evacuationNeeded').addEventListener('change', toggleHeadcount);
document.getElementById('evacuationCenter').addEventListener('change', toggleHeadcount);

function toggleRoadCauses() {
    var statusValue = document.getElementById('roadStatus').value;
    var section = document.getElementById('roadCausesSection');
    section.style.display = (statusValue === 'Passable') ? 'none' : 'block';
}

document.getElementById('roadStatus').addEventListener('change', toggleRoadCauses);
</script>

<?php include "../app/includes/footer.php"; ?>
