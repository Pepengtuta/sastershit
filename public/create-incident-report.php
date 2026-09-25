<?php
$V_page_title = "Create Incident Report";
include "../app/auth/check_session.php";
include "../config/db_connection.php";

if ($_SESSION['role'] != 'barangay' || ($_SESSION['sub_role'] ?? '') === 'secretary') {
    header("Location: incident-reports.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

$V_barangay_name = $_SESSION['barangay_name'];

// Fetch the reporting barangay's population for auto-filling the affected count.
$V_barangay_population = (int)($_SESSION['population'] ?? 0);
if ($V_barangay_population === 0 && !empty($_SESSION['barangay_id'])) {
    $PopStmt = mysqli_prepare($connection, "SELECT population FROM barangays WHERE id = ? LIMIT 1");
    mysqli_stmt_bind_param($PopStmt, "i", $_SESSION['barangay_id']);
    mysqli_stmt_execute($PopStmt);
    $PopResult = mysqli_stmt_get_result($PopStmt);
    if ($PopRow = mysqli_fetch_assoc($PopResult)) {
        $V_barangay_population = (int)$PopRow['population'];
    }
}

$DisasterResult = mysqli_query($connection, "SELECT * FROM disaster_types WHERE status = 'Active' ORDER BY id ASC");

$CenterQuery = "SELECT * FROM evacuation_centers WHERE barangay = ? AND status IN ('Available', 'Open') ORDER BY center_name ASC";
$CenterStmt = mysqli_prepare($connection, $CenterQuery);
mysqli_stmt_bind_param($CenterStmt, "s", $V_barangay_name);
mysqli_stmt_execute($CenterStmt);
$CenterResult = mysqli_stmt_get_result($CenterStmt);

$V_road_causes = ['Fallen Tree', 'Downed Power Line / Electric Post', 'Flooding / Deep Water', 'Landslide / Debris / Mud', 'Damaged / Collapsed Bridge', 'Other / Cannot Inspect'];
?>

<div class="panel-card" style="max-width: 980px; margin: 0 auto;">
    <div class="panel-header">
        <div>
            <h2>Incident Report Form</h2>
            <p>Barangay is auto-selected from your account. Pin the exact incident location on the map.</p>
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

        <form action="../app/reports/save-report.php" method="post" enctype="multipart/form-data">
            <?php echo csrf_field(); ?>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Barangay</label>
                    <input type="text" class="form-control" value="<?php echo h($V_barangay_name); ?>" readonly>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Disaster Type *</label>
                    <select name="disaster_type" id="disasterType" class="form-select" required>
                        <option value="">Select disaster type</option>
                        <?php while ($type = mysqli_fetch_assoc($DisasterResult)) {
                            $V_dt_emojis = [
                                'Typhoon' => '🌪️', 'Flood' => '🌊', 'Storm Surge' => '🌊',
                                'Earthquake' => '🌎', 'Landslide' => '⛰️', 'Fire' => '🔥',
                                'Drought / El Niño' => '☀️', 'Disease Outbreak' => '🦠',
                                'Accident / Mass Casualty Incident' => '🚑', 'Others' => '⚠️',
                            ];
                            $V_emoji = $V_dt_emojis[$type['name']] ?? '⚠️';
                        ?>
                            <option value="<?php echo h($type['name']); ?>"><?php echo $V_emoji; ?> <?php echo h($type['name']); ?></option>
                        <?php } ?>
                    </select>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Exact Location</label>
                    <input type="text" name="exact_location" id="exactLocation" class="form-control" value="<?php echo h($V_barangay_name); ?>, <?php echo h($_SESSION['municipality'] ?? 'Kalibo'); ?>, Aklan" placeholder="Sitio / street / landmark" required>
                    <div class="form-text">Default is your barangay. If device location is allowed, this will update with coordinates, but you can still edit it.</div>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Incident Date and Time</label>
                    <div class="row g-2">
                        <div class="col-md-5 col-12">
                            <input type="date" name="incident_date" id="incidentDate" class="form-control" required>
                        </div>

                        <div class="col-md-2 col-4">
                            <select name="incident_hour" id="incidentHour" class="form-select" required>
                                <?php for ($i = 1; $i <= 12; $i++) { ?>
                                    <option value="<?php echo $i; ?>"><?php echo $i; ?></option>
                                <?php } ?>
                            </select>
                        </div>

                        <div class="col-md-2 col-4">
                            <select name="incident_minute" id="incidentMinute" class="form-select" required>
                                <?php for ($i = 0; $i <= 55; $i += 5) { ?>
                                    <option value="<?php echo str_pad($i, 2, '0', STR_PAD_LEFT); ?>">
                                        <?php echo str_pad($i, 2, '0', STR_PAD_LEFT); ?>
                                    </option>
                                <?php } ?>
                            </select>
                        </div>

                        <div class="col-md-3 col-4">
                            <select name="incident_ampm" id="incidentAmpm" class="form-select" required>
                                <option value="AM">AM</option>
                                <option value="PM">PM</option>
                            </select>
                        </div>
                    </div>
                    <div class="form-text">Default is your device current date and time. You can still edit the date, hour, minute, and AM/PM.</div>
                </div>
            </div>

            <hr>
            <h3 class="form-section-title">Road / Bridge Accessibility</h3>
            <div class="simple-note mb-2">
                Tells Municipal / Provincial whether response teams and relief can physically reach the area. Default is Passable.
            </div>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Road Status</label>
                    <select name="road_status" id="roadStatus" class="form-select">
                        <option value="Passable" selected>Passable</option>
                        <option value="Partially Passable">Partially Passable</option>
                        <option value="Obstructed">Obstructed</option>
                    </select>
                    <div class="form-text">"Partially" = motorcycles / small vehicles can pass but not trucks or ambulances.</div>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Road / Bridge Name or Landmark</label>
                    <input type="text" name="road_location" id="roadLocation" class="form-control" placeholder="e.g., Kalibo–Ibajay Rd near Mabusao Bridge">
                    <div class="form-text">Optional. Which road/bridge is affected so teams know where to reroute.</div>
                </div>
            </div>

            <div id="roadCausesSection" class="mt-2" style="display: none;">
                <label class="form-label">Cause of Blockage <small class="text-muted">(select all that apply)</small></label>
                <div class="assistance-grid">
                    <?php foreach ($V_road_causes as $V_cause) { ?>
                        <label class="check-card"><input type="checkbox" name="road_blockage_causes[]" value="<?php echo h($V_cause); ?>"> <?php echo h($V_cause); ?></label>
                    <?php } ?>
                </div>
                <div class="form-text">If you know more than one cause, tick them all (e.g., a fallen tree and a downed power line together).</div>
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
                    <input type="text" name="N_latitude" id="incidentLatitude" class="form-control" readonly>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Longitude</label>
                    <input type="text" name="N_longitude" id="incidentLongitude" class="form-control" readonly>
                </div>
            </div>

            <hr>
            <div class="row g-3">
                <div class="col-md-6">
                    <label class="form-label">Affected People</label>
                    <input type="number" name="affected_people" id="affectedPeople" class="form-control" min="0" value="0">
                    <div class="form-text" id="affectedHint">For natural disasters, this fills with your barangay population. You can still edit it.</div>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Injured</label>
                    <input type="number" name="injured" class="form-control" min="0" value="0">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Dead</label>
                    <input type="number" name="dead" class="form-control" min="0" value="0">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Missing</label>
                    <input type="number" name="missing" class="form-control" min="0" value="0">
                </div>

                <div class="col-md-6">
                    <label class="form-label">Evacuation Needed?</label>
                    <select name="evacuation_needed" id="evacuationNeeded" class="form-select">
                        <option value="No">No</option>
                        <option value="Yes">Yes</option>
                    </select>
                </div>

                <div class="col-md-6">
                    <label class="form-label">Evacuation Center</label>
                    <select name="evacuation_center_id" id="evacuationCenter" class="form-select">
                        <option value="">None / Not applicable</option>
                        <?php while ($center = mysqli_fetch_assoc($CenterResult)) { ?>
                            <option value="<?php echo $center['id']; ?>">
                                <?php echo h($center['center_name']); ?> - <?php echo h($center['status']); ?>
                            </option>
                        <?php } ?>
                    </select>
                    <div class="form-text">Only available/open centers in <?php echo h($V_barangay_name); ?> are listed.</div>
                </div>
            </div>

            <div id="headcountSection" style="display: none;">
                <hr>
                <h3 class="form-section-title">Evacuation Headcount</h3>
                <div class="simple-note mb-2">Quick headcount at the evacuation center. Used by Municipal for supply coordination and DSWD reporting.</div>
                <div class="row g-3">
                    <div class="col-md-3">
                        <label class="form-label">No. of Households *</label>
                        <input type="number" name="evac_households" id="evacHouseholds" class="form-control" min="0" value="0">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">No. of Adults *</label>
                        <input type="number" name="evac_adults" id="evacAdults" class="form-control" min="0" value="0">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">No. of Children *</label>
                        <input type="number" name="evac_children" id="evacChildren" class="form-control" min="0" value="0">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">No. of Family Members *</label>
                        <input type="number" name="evac_members" id="evacMembers" class="form-control" min="0" value="0">
                    </div>
                </div>
            </div>

            <hr>
            <h3 class="form-section-title">Description</h3>
            <textarea name="description" class="form-control" rows="5" placeholder="Describe what happened..." required></textarea>

            <!-- DISABLED: Assistance Needed — to be moved to Municipal level
            <hr>
            <h3 class="form-section-title">Assistance Needed</h3>
            <div class="assistance-grid">
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Medical Team"> Medical Team</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Ambulance"> Ambulance</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Food Packs"> Food Packs</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Water"> Water</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Rescue Team"> Rescue Team</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Shelter Supplies"> Shelter Supplies</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Clearing Operations"> Clearing Operations</label>
                <label class="check-card"><input type="checkbox" name="assistance_needed[]" value="Others"> Others</label>
            </div>
            -->

            <hr>
            <h3 class="form-section-title">Upload Evidence</h3>
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
                <input type="submit" value="Submit Report" class="btn btn-emergency">
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

setCurrentDeviceDateTime();
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

document.querySelector('form[action="../app/reports/save-report.php"]').addEventListener('submit', function(e) {
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
    var name = (feature.properties && feature.properties[V_nameKey]) || '';
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
            var name = (feature.properties && feature.properties[V_nameKey]) || '';

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

    if (selectedLayer) {
        var bounds = selectedLayer.getBounds();
        var center = bounds.getCenter();
        V_defaultLocation = [center.lat, center.lng];
        V_map.fitBounds(bounds, { padding: [20, 20] });
        setIncidentMarker(center.lat, center.lng, false);
    } else {
        setIncidentMarker(V_defaultLocation[0], V_defaultLocation[1], false);
    }

    tryDeviceLocation();
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
        setIncidentMarker(V_defaultLocation[0], V_defaultLocation[1], false);
        tryDeviceLocation();
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
toggleRoadCauses();

var V_barangayPopulation = <?php echo (int)$V_barangay_population; ?>;
var V_naturalDisasters = [
    'Typhoon', 'Flood', 'Flash Flood', 'Storm Surge',
    'Earthquake', 'Landslide', 'Fire',
    'Volcanic Eruption', 'Drought / El Niño', 'Disease Outbreak'
];

function autoPopulateAffected() {
    var type = document.getElementById('disasterType').value;
    var input = document.getElementById('affectedPeople');
    // Only auto-fill for natural disasters. Accident/MCI and Others stay manual.
    if (V_naturalDisasters.indexOf(type) !== -1 && V_barangayPopulation > 0) {
        input.value = V_barangayPopulation;
    }
}

document.getElementById('disasterType').addEventListener('change', autoPopulateAffected);
</script>

<?php include "../app/includes/footer.php"; ?>
