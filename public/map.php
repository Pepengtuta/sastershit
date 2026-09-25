<?php
$V_page_title = "Barangay Map";

include_once "../app/auth/check_session.php";
include_once "../config/db_connection.php";
include_once "../app/includes/functions.php";

/*
    Barangay Map Page
    Purpose:
    - Show Kalibo barangay boundaries using Leaflet + OpenStreetMap
    - Show blue barangay hall markers when coordinates exist
    - Show green evacuation center markers when coordinates exist
    - Select barangay from map or list
    - Show evacuation centers for selected barangay
*/

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';
$V_session_barangay_name = $_SESSION['barangay_name'] ?? '';

// MDR and mayor sub-roles are forced to their municipality — no switching allowed.
$V_forced_muni = mdr_municipality($V_role, $V_sub_role);
if ($V_forced_muni === null) {
    $V_forced_muni = mayor_municipality($V_role, $V_sub_role);
}

// Superadmins (and province-level roles) can switch municipality via filter;
// other roles always see their own municipality.
$V_superadmin_roles = ['superadmin', 'pcf', 'pho'];
$V_is_superadmin = in_array($V_role, $V_superadmin_roles);

if ($V_forced_muni) {
    $V_session_municipality = $V_forced_muni;
} elseif ($V_is_superadmin) {
    $V_session_municipality = $_SESSION['filter_municipality'] ?? '';
} else {
    $V_session_municipality = $_SESSION['municipality'] ?? 'Kalibo';
}

$V_municipalities = ['Kalibo', 'Ibajay'];
$V_map_scope_label = $V_session_municipality !== '' ? $V_session_municipality : 'All Municipalities';

$V_barangays = [];
$V_barangay_hall_markers = [];
$V_evacuation_centers = [];
$V_evacuation_markers = [];

/* Get barangays and barangay hall marker coordinates (filtered to the
   logged-in user's municipality so the map lists the correct primary set) */
$V_barangay_municipality_where = $V_session_municipality !== ''
    ? "WHERE municipality = '" . mysqli_real_escape_string($connection, $V_session_municipality) . "'"
    : '';
$V_barangay_query = "SELECT id, name, latitude, longitude FROM barangays $V_barangay_municipality_where ORDER BY municipality ASC, name ASC";
$V_barangay_result = mysqli_query($connection, $V_barangay_query);

if ($V_barangay_result) {
    while ($row = mysqli_fetch_assoc($V_barangay_result)) {
        $V_barangay_name = $row['name'];

        $V_barangays[] = [
            "id" => (int)$row['id'],
            "name" => $V_barangay_name,
            "latitude" => $row['latitude'],
            "longitude" => $row['longitude']
        ];

        $V_evacuation_centers[$V_barangay_name] = [];

        if ($row['latitude'] !== null && $row['latitude'] !== '' && $row['longitude'] !== null && $row['longitude'] !== '') {
            $V_barangay_hall_markers[] = [
                "barangay" => $V_barangay_name,
                "name" => $V_barangay_name . " Barangay Hall",
                "latitude" => $row['latitude'],
                "longitude" => $row['longitude']
            ];
        }
    }
}

/* Get evacuation centers per barangay (filtered by municipality) */
$V_evac_municipality_where = $V_session_municipality !== ''
    ? "WHERE municipality = '" . mysqli_real_escape_string($connection, $V_session_municipality) . "'"
    : '';
$V_evac_query = "SELECT id, barangay, center_name, center_type, capacity, current_evacuees, status, contact_person, contact_number, latitude, longitude
                 FROM evacuation_centers
                 $V_evac_municipality_where
                 ORDER BY barangay ASC, center_name ASC";
$V_evac_result = mysqli_query($connection, $V_evac_query);

if ($V_evac_result) {
    while ($row = mysqli_fetch_assoc($V_evac_result)) {
        $V_barangay_name = $row['barangay'];

        if (!isset($V_evacuation_centers[$V_barangay_name])) {
            $V_evacuation_centers[$V_barangay_name] = [];
        }

        $V_center_item = [
            "id" => (int)$row['id'],
            "barangay" => $V_barangay_name,
            "center_name" => $row['center_name'],
            "center_type" => $row['center_type'],
            "capacity" => (int)$row['capacity'],
            "current_evacuees" => (int)$row['current_evacuees'],
            "status" => $row['status'],
            "contact_person" => $row['contact_person'],
            "contact_number" => $row['contact_number'],
            "latitude" => $row['latitude'],
            "longitude" => $row['longitude']
        ];

        $V_evacuation_centers[$V_barangay_name][] = $V_center_item;

        if ($row['latitude'] !== null && $row['latitude'] !== '' && $row['longitude'] !== null && $row['longitude'] !== '') {
            $V_evacuation_markers[] = $V_center_item;
        }
    }
}

/* Get primary care facility markers (lat/lng) — shown to every role/scope */
$V_pcf_markers = [];
$V_pcf_query = "SELECT id, name, municipality, latitude, longitude
                FROM pcf_facilities
                WHERE latitude IS NOT NULL AND latitude != ''
                  AND longitude IS NOT NULL AND longitude != ''
                ORDER BY municipality ASC, name ASC";
$V_pcf_result = mysqli_query($connection, $V_pcf_query);

if ($V_pcf_result) {
    while ($row = mysqli_fetch_assoc($V_pcf_result)) {
        $V_pcf_markers[] = [
            "id" => (int)$row['id'],
            "name" => $row['name'],
            "municipality" => $row['municipality'],
            "latitude" => $row['latitude'],
            "longitude" => $row['longitude']
        ];
    }
}

/* Get incident markers (lat/lng) */
$V_incident_markers = [];
$V_barangay_id_session = (int)($_SESSION['barangay_id'] ?? 0);

$V_incident_where = "WHERE ir.latitude IS NOT NULL AND ir.latitude != '' AND ir.longitude IS NOT NULL AND ir.longitude != ''";
if ($V_role === 'barangay' && $V_barangay_id_session > 0) {
    $V_incident_where .= " AND ir.barangay_id = " . $V_barangay_id_session;
} elseif (is_admin_role($V_role)) {
    // Admin map markers follow the selected/forced municipality.
    if ($V_session_municipality !== '') {
        $V_muni_escaped = mysqli_real_escape_string($connection, $V_session_municipality);
        $V_incident_where .= " AND b.municipality = '$V_muni_escaped'";
    }
    if ($V_role === 'pcf') {
        $V_incident_where .= " AND ir.status IN ('Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved','Dismissed')";
    } elseif ($V_role === 'pho') {
        // Governor map: PHO pipeline (red) + MDR-level statuses (orange layer),
        // mirroring the app's "Forwarded to MDR" toggle.
        $V_incident_where .= " AND (ir.referred_to_pho = 1 OR ir.status IN ('Referred to PHO','Under PHO Review','Forwarded to PHO','Forwarded to PCF','Under MDR Review','Verified','Responding'))";
    }
}

$V_incident_query = "SELECT ir.id, ir.disaster_type, ir.status, ir.latitude, ir.longitude, ir.created_at, ir.affected_people, ir.injured, b.name AS barangay_name, b.municipality
                     FROM incident_reports ir
                     LEFT JOIN barangays b ON ir.barangay_id = b.id
                     $V_incident_where
                     ORDER BY ir.created_at DESC";
$V_incident_result = mysqli_query($connection, $V_incident_query);
if ($V_incident_result) {
    while ($row = mysqli_fetch_assoc($V_incident_result)) {
        $V_incident_markers[] = [
            'id'              => (int)$row['id'],
            'disaster_type'   => $row['disaster_type'],
            'status'          => $row['status'],
            'status_label'    => incident_status_label($row['status'], $row['municipality'] ?? ''),
            'latitude'        => $row['latitude'],
            'longitude'       => $row['longitude'],
            'created_at'      => $row['created_at'],
            'affected_people' => (int)($row['affected_people'] ?? 0),
            'injured'         => (int)($row['injured'] ?? 0),
            'barangay_name'   => $row['barangay_name'],
            'municipality'    => $row['municipality'],
        ];
    }
}

$V_barangays_json = json_encode($V_barangays, JSON_UNESCAPED_UNICODE);
$V_barangay_hall_markers_json = json_encode($V_barangay_hall_markers, JSON_UNESCAPED_UNICODE);
$V_evacuation_json = json_encode($V_evacuation_centers, JSON_UNESCAPED_UNICODE);
$V_evacuation_markers_json = json_encode($V_evacuation_markers, JSON_UNESCAPED_UNICODE);
$V_pcf_markers_json = json_encode($V_pcf_markers, JSON_UNESCAPED_UNICODE);
$V_incident_markers_json = json_encode($V_incident_markers, JSON_UNESCAPED_UNICODE);
$V_role_json = json_encode($V_role);
$V_session_barangay_json = json_encode($V_session_barangay_name, JSON_UNESCAPED_UNICODE);
$V_session_municipality_json = json_encode($V_session_municipality, JSON_UNESCAPED_UNICODE);

include_once "../app/includes/header.php";
include_once "../app/includes/sidebar.php";
?>

<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<style>
    /* Theme colors for this page.
       --primary, --bg, --text, --muted and --border already come from the
       site stylesheet (asset/css/style.css). The three below mirror colors
       the map uses, defined here so the map matches the site theme and a
       future color change stays easy. */
    :root {
        --primary-rgb: 220, 53, 69; /* same red as --primary, for see-through tints */
        --success: #198754;         /* green - evacuation markers */
        --info: #0d6efd;            /* blue - barangay-hall markers */
        --pcf: #6f42c1;             /* purple - primary care facility markers */
        --mdr: #fd7e14;             /* orange - "Forwarded to MDR" incidents */
    }

    .map-page-layout {
        display: grid;
        grid-template-columns: minmax(0, 2fr) 230px 340px;
        gap: 12px;
        align-items: stretch;
    }

    .map-box,
    .map-list-box,
    .map-evac-box {
        border: 1px solid var(--border);
        border-radius: 12px;
        background: var(--card-bg);
        overflow: hidden;
        min-height: 560px;
    }

    #barangayMap {
        height: 560px;
        width: 100%;
    }

    .map-box-header {
        padding: 12px 14px;
        border-bottom: 1px solid var(--border);
        background: var(--card-bg);
    }

    .map-box-header strong {
        display: block;
        font-size: 15px;
        color: var(--text-main);
    }

    .map-box-header span {
        display: block;
        font-size: 12px;
        color: var(--text-muted);
        margin-top: 2px;
    }

    .barangay-list {
        height: 505px;
        overflow-y: auto;
    }

    .barangay-item {
        width: 100%;
        border: 0;
        border-bottom: 1px solid var(--border);
        background: transparent;
        text-align: left;
        padding: 10px 12px;
        color: var(--text-main);
        display: flex;
        justify-content: space-between;
        gap: 8px;
        cursor: pointer;
    }

    .barangay-item:hover {
        background: rgba(var(--primary-rgb), 0.08);
    }

    .barangay-item.active {
        border-left: 5px solid var(--primary);
        background: rgba(var(--primary-rgb), 0.14);
        font-weight: 700;
    }


    .evac-panel-body {
        height: 505px;
        overflow-y: auto;
        padding: 12px;
    }

    .evac-summary {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 8px;
        margin-bottom: 12px;
    }

    .evac-summary-box {
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 10px;
        background: var(--body-bg);
    }

    .evac-summary-box span {
        display: block;
        color: var(--text-muted);
        font-size: 12px;
    }

    .evac-summary-box strong {
        font-size: 22px;
        color: var(--text-main);
    }

    .evac-item {
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 11px;
        margin-bottom: 10px;
        background: var(--body-bg);
    }

    .evac-item-title {
        font-weight: 700;
        color: var(--text-main);
        margin-bottom: 4px;
    }

    .evac-item small {
        color: var(--text-muted);
        display: block;
        margin-top: 2px;
    }

    .map-empty {
        border: 1px dashed var(--border);
        border-radius: 10px;
        padding: 16px;
        color: var(--text-muted);
        background: var(--body-bg);
    }

    .map-status-badge {
        display: inline-block;
        padding: 3px 8px;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 700;
        background: rgba(var(--primary-rgb), 0.12);
        color: var(--primary);
        margin-top: 5px;
    }

    .map-coordinate-badge {
        display: inline-block;
        padding: 3px 8px;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 700;
        background: rgba(22, 163, 74, 0.12);
        color: #15803d;
        margin-top: 5px;
        margin-left: 4px;
    }

    .leaflet-container {
        font-family: inherit;
    }

    .custom-map-marker {
        width: 30px;
        height: 30px;
        border-radius: 50%;
        border: 3px solid #ffffff;
        box-shadow: 0 2px 8px rgba(15, 23, 42, 0.35);
        display: flex;
        align-items: center;
        justify-content: center;
    }

    /* Icon inside the colored dot — mirrors the app's marker icons */
    .custom-map-marker .material-symbols-outlined {
        color: #ffffff;
        font-size: 18px;
        line-height: 1;
    }

    .custom-map-marker.barangay-hall-marker {
        background: var(--info);
    }

    .custom-map-marker.evacuation-marker {
        background: var(--success);
    }

    .custom-map-marker.incident-marker {
        background: var(--primary);
    }

    .custom-map-marker.incident-mdr-marker {
        background: var(--mdr);
    }

    .custom-map-marker.pcf-marker {
        background: var(--pcf);
    }

    .map-legend {
        background: white;
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 8px 12px;
        box-shadow: 0 2px 8px rgba(15, 23, 42, 0.12);
        color: var(--text);
        font-size: 12px;
    }

    /* Layer toggles — Flutter-style icon buttons */
    .map-layer-toggles {
        background: white;
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 6px 8px;
        box-shadow: 0 2px 8px rgba(15, 23, 42, 0.12);
        display: flex;
        gap: 6px;
        align-items: center;
    }

    .layer-toggle-btn {
        width: 36px;
        height: 36px;
        border-radius: 50%;
        border: 2px solid transparent;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 16px;
        transition: background 0.15s, border-color 0.15s;
        background: var(--bg);
        color: var(--muted);
    }

    .layer-toggle-btn.active-blue  { background: var(--info); border-color: var(--info); color: #fff; }
    .layer-toggle-btn.active-green { background: var(--success); border-color: var(--success); color: #fff; }
    .layer-toggle-btn.active-red   { background: var(--primary); border-color: var(--primary); color: #fff; }
    .layer-toggle-btn.active-purple { background: var(--pcf); border-color: var(--pcf); color: #fff; }
    .layer-toggle-btn.active-orange { background: var(--mdr); border-color: var(--mdr); color: #fff; }

    .map-legend-row {
        display: flex;
        align-items: center;
        gap: 6px;
        margin: 3px 0;
        white-space: nowrap;
    }

    .map-legend-dot {
        width: 11px;
        height: 11px;
        border-radius: 50%;
        display: inline-block;
    }

    .map-legend-dot.blue {
        background: var(--info);
    }

    .map-legend-dot.green {
        background: var(--success);
    }

    .map-legend-dot.red {
        background: var(--primary);
    }

    .map-legend-dot.orange {
        background: var(--mdr);
    }

    .map-legend-dot.purple {
        background: var(--pcf);
    }

    @media (max-width: 1200px) {
        .map-page-layout {
            grid-template-columns: minmax(0, 1fr) 220px;
        }

        .map-evac-box {
            grid-column: 1 / -1;
            min-height: auto;
        }

        .evac-panel-body {
            height: auto;
            max-height: 360px;
        }
    }

    @media (max-width: 768px) {
        .map-page-layout {
            grid-template-columns: 1fr;
        }

        .map-box,
        .map-list-box,
        .map-evac-box {
            min-height: auto;
        }

        #barangayMap {
            height: 430px;
        }

        .barangay-list,
        .evac-panel-body {
            height: auto;
            max-height: 360px;
        }
    }
</style>

<div class="panel-card">
    <div class="panel-header d-flex justify-content-between align-items-center">
        <div>
            <h2>Barangay Map</h2>
            <p>Interactive map of <?php echo count($V_barangays); ?> barangays in <?php echo h($V_map_scope_label); ?>. Blue pins are barangay halls. Green pins are evacuation centers. Purple pins are primary care facilities.</p>
        </div>
        <div class="d-flex align-items-center gap-2">
            <button type="button" class="btn btn-light border btn-sm" onclick="resetBarangayMap()">Reset Map</button>
            <?php if ($V_is_superadmin && !$V_forced_muni): ?>
            <form method="POST" action="../app/auth/set_municipality_filter.php" class="m-0">
                <select name="municipality" class="form-select form-select-sm" onchange="this.form.submit()" style="min-width:130px;">
                    <option value="all"<?php echo ($V_session_municipality === '' ? ' selected' : ''); ?>>All Municipalities</option>
                    <?php foreach ($V_municipalities as $V_muni): ?>
                    <option value="<?php echo h($V_muni); ?>"<?php echo ($V_session_municipality === $V_muni ? ' selected' : ''); ?>>
                        <?php echo h($V_muni); ?>
                    </option>
                    <?php endforeach; ?>
                </select>
            </form>
            <?php endif; ?>
        </div>
    </div>
</div>

<div class="map-page-layout mt-3">
    <div class="map-box">
        <div id="barangayMap"></div>
    </div>

    <div class="map-list-box">
        <div class="map-box-header">
            <strong>Barangays</strong>
            <span>Select from the list.</span>
        </div>
        <div class="barangay-list" id="barangayList">
            <div class="map-empty m-2">Loading barangays...</div>
        </div>
    </div>

    <div class="map-evac-box">
        <div class="map-box-header">
            <strong>Evacuation Centers</strong>
            <span id="selectedBarangaySubtitle">No barangay selected.</span>
        </div>
        <div class="evac-panel-body" id="evacuationPanel">
            <div class="map-empty">Select a barangay to view evacuation centers.</div>
        </div>
    </div>
</div>

<script>
var V_barangays = <?php echo $V_barangays_json ? $V_barangays_json : '[]'; ?>;
var V_barangayHallMarkers = <?php echo $V_barangay_hall_markers_json ? $V_barangay_hall_markers_json : '[]'; ?>;
var V_evacuationCenters = <?php echo $V_evacuation_json ? $V_evacuation_json : '{}'; ?>;
var V_evacuationMarkers = <?php echo $V_evacuation_markers_json ? $V_evacuation_markers_json : '[]'; ?>;
var V_pcfMarkers = <?php echo $V_pcf_markers_json ? $V_pcf_markers_json : '[]'; ?>;
var V_incidentMarkers = <?php echo $V_incident_markers_json ? $V_incident_markers_json : '[]'; ?>;
var V_userRole = <?php echo $V_role_json; ?>;
var V_subRole = <?php echo json_encode($V_sub_role, JSON_UNESCAPED_UNICODE); ?>;
var V_sessionBarangayName = <?php echo $V_session_barangay_json; ?>;
var V_municipality = <?php echo $V_session_municipality_json; ?>;
var isIbajayPrimary = V_municipality === 'Ibajay';

var map = L.map('barangayMap');
var barangayLayer = null;
var selectedLayer = null;
var selectedBarangayName = null;
var barangayHallMarkerLayer = L.layerGroup().addTo(map);
var evacuationMarkerLayer = L.layerGroup().addTo(map);
var pcfMarkerLayer = L.layerGroup().addTo(map);
var incidentMarkerLayer = L.layerGroup().addTo(map);
var mdrIncidentMarkerLayer = L.layerGroup();

/* Layer visibility state */
var layerVisibility = { halls: true, evacuation: true, pcf: true, incidents: true, mdr: false };

/* MDR-level statuses shown in the optional orange "Forwarded to MDR" layer
   (Governor/pho only) — mirrors map_view_screen.dart's _mdrStatuses. */
var MDR_STATUSES = ['Forwarded to PCF', 'Under MDR Review', 'Verified', 'Responding'];
var isPhoRole = V_userRole === 'pho';

/* Use the site theme color for the map shapes/markers so they match the
   rest of the page. Falls back to the original red if unavailable. */
var V_themeStyles = getComputedStyle(document.documentElement);
var V_primaryColor = (V_themeStyles.getPropertyValue('--primary') || '#dc3545').trim();

var defaultStyle = {
    color: '#475569',
    weight: 1.4,
    opacity: 0.9,
    fillColor: V_primaryColor,
    fillOpacity: 0.08
};

var hoverStyle = {
    color: V_primaryColor,
    weight: 2,
    opacity: 1,
    fillColor: V_primaryColor,
    fillOpacity: 0.20
};

var selectedStyle = {
    color: V_primaryColor,
    weight: 3,
    opacity: 1,
    fillColor: V_primaryColor,
    fillOpacity: 0.50
};

L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors'
}).addTo(map);

/* Legend */
var markerLegend = L.control({ position: 'bottomleft' });
markerLegend.onAdd = function() {
    var div = L.DomUtil.create('div', 'map-legend');
    div.innerHTML =
        '<div class="map-legend-row"><span class="map-legend-dot blue"></span> Barangay Hall</div>' +
        '<div class="map-legend-row"><span class="map-legend-dot green"></span> Evacuation Center</div>' +
        '<div class="map-legend-row"><span class="map-legend-dot purple"></span> Primary Care Facility</div>' +
        '<div class="map-legend-row"><span class="map-legend-dot red"></span> Incident Location</div>' +
        '<?php echo ($V_role === 'pho') ? '<div class="map-legend-row"><span class="map-legend-dot orange"></span> Forwarded to MDR</div>' : ''; ?>';
    return div;
};
markerLegend.addTo(map);

/* Layer toggle buttons */
var toggleControl = L.control({ position: 'bottomright' });
toggleControl.onAdd = function() {
    var container = L.DomUtil.create('div', 'map-layer-toggles');
    container.innerHTML =
        '<button id="toggleHalls" class="layer-toggle-btn active-blue" title="Barangay Halls">🏛</button>' +
        '<button id="toggleEvac" class="layer-toggle-btn active-green" title="Evacuation Centers">🏠</button>' +
        '<button id="togglePcf" class="layer-toggle-btn active-purple" title="Primary Care Facilities">🏥</button>' +
        '<button id="toggleIncidents" class="layer-toggle-btn active-red" title="Incident Locations">⚠</button>' +
        '<?php echo ($V_role === 'pho') ? '<button id="toggleMdr" class="layer-toggle-btn" title="Forwarded to MDR">📨</button>' : ''; ?>';
    L.DomEvent.disableClickPropagation(container);
    return container;
};
toggleControl.addTo(map);

function applyLayerToggle(layerKey, btn, activeClass, layer) {
    layerVisibility[layerKey] = !layerVisibility[layerKey];
    if (layerVisibility[layerKey]) {
        btn.classList.add(activeClass);
        map.addLayer(layer);
    } else {
        btn.classList.remove(activeClass);
        map.removeLayer(layer);
    }
}

map.whenReady(function() {
    var hallBtn = document.getElementById('toggleHalls');
    var evacBtn = document.getElementById('toggleEvac');
    var pcfBtn  = document.getElementById('togglePcf');
    var incBtn  = document.getElementById('toggleIncidents');
    if (hallBtn) hallBtn.addEventListener('click', function() { applyLayerToggle('halls', hallBtn, 'active-blue', barangayHallMarkerLayer); });
    if (evacBtn) evacBtn.addEventListener('click', function() { applyLayerToggle('evacuation', evacBtn, 'active-green', evacuationMarkerLayer); });
    if (pcfBtn)  pcfBtn.addEventListener('click',  function() { applyLayerToggle('pcf', pcfBtn, 'active-purple', pcfMarkerLayer); });
    if (incBtn)  incBtn.addEventListener('click',  function() { applyLayerToggle('incidents', incBtn, 'active-red', incidentMarkerLayer); });
    var mdrBtn = document.getElementById('toggleMdr');
    if (mdrBtn) mdrBtn.addEventListener('click', function() { applyLayerToggle('mdr', mdrBtn, 'active-orange', mdrIncidentMarkerLayer); });
});

function getBarangayName(feature) {
    if (feature && feature.properties) {
        var key = isIbajayPrimary ? 'name' : 'adm4_en';
        if (feature.properties[key]) {
            return feature.properties[key];
        }
    }
    return 'Unknown';
}

function normalizeName(value) {
    return String(value || '').trim().toLowerCase();
}

function makeMarkerIcon(markerClass) {
    /* Icons mirror the app (map_view_screen.dart): hall = account_balance,
       evacuation center = location_city, incident = warning (outlined amber). */
    var markerIconNames = {
        'barangay-hall-marker': 'account_balance',
        'evacuation-marker': 'location_city',
        'incident-marker': 'warning',
        'incident-mdr-marker': 'forward_to_inbox',
        'pcf-marker': 'local_hospital'
    };
    var glyph = markerIconNames[markerClass] || 'place';
    return L.divIcon({
        className: '',
        html: '<div class="custom-map-marker ' + markerClass + '"><span class="material-symbols-outlined">' + glyph + '</span></div>',
        iconSize: [30, 30],
        iconAnchor: [15, 15],
        popupAnchor: [0, -16]
    });
}

function hasCoordinates(item) {
    if (!item || item.latitude === null || item.longitude === null || item.latitude === '' || item.longitude === '') {
        return false;
    }

    var lat = parseFloat(item.latitude);
    var lng = parseFloat(item.longitude);

    return !isNaN(lat) && !isNaN(lng);
}

function shouldShowMarkerForBarangay(item, barangayName) {
    if (!barangayName) {
        return true;
    }
    return normalizeName(item.barangay) === normalizeName(barangayName);
}

function renderMapMarkers(barangayName) {
    barangayHallMarkerLayer.clearLayers();
    evacuationMarkerLayer.clearLayers();
    pcfMarkerLayer.clearLayers();
    incidentMarkerLayer.clearLayers();
    mdrIncidentMarkerLayer.clearLayers();

    V_barangayHallMarkers.forEach(function(markerItem) {
        if (!hasCoordinates(markerItem)) return;
        if (!shouldShowMarkerForBarangay(markerItem, barangayName)) return;

        var lat = parseFloat(markerItem.latitude);
        var lng = parseFloat(markerItem.longitude);
        var marker = L.marker([lat, lng], { icon: makeMarkerIcon('barangay-hall-marker') });
        marker.bindPopup(
            '<strong>' + escapeHtml(markerItem.name) + '</strong><br>' +
            'Type: Barangay Hall<br>' +
            'Barangay: ' + escapeHtml(markerItem.barangay)
        );
        marker.addTo(barangayHallMarkerLayer);
    });

    V_evacuationMarkers.forEach(function(center) {
        if (!hasCoordinates(center)) return;
        if (!shouldShowMarkerForBarangay(center, barangayName)) return;

        var lat = parseFloat(center.latitude);
        var lng = parseFloat(center.longitude);
        var marker = L.marker([lat, lng], { icon: makeMarkerIcon('evacuation-marker') });
        marker.bindPopup(
            '<strong>' + escapeHtml(center.center_name) + '</strong><br>' +
            'Type: Evacuation Center<br>' +
            'Barangay: ' + escapeHtml(center.barangay) + '<br>' +
            'Status: ' + escapeHtml(center.status || 'No status') + '<br>' +
            'Current Evacuees: ' + Number(center.current_evacuees || 0).toLocaleString()
        );
        marker.addTo(evacuationMarkerLayer);
    });

    V_pcfMarkers.forEach(function(facility) {
        if (!hasCoordinates(facility)) return;

        var lat = parseFloat(facility.latitude);
        var lng = parseFloat(facility.longitude);
        var marker = L.marker([lat, lng], { icon: makeMarkerIcon('pcf-marker') });
        marker.bindPopup(
            '<strong>' + escapeHtml(facility.name) + '</strong><br>' +
            'Type: Primary Care Facility<br>' +
            'Municipality: ' + escapeHtml(facility.municipality)
        );
        marker.addTo(pcfMarkerLayer);
    });

    V_incidentMarkers.forEach(function(incident) {
        if (!hasCoordinates(incident)) return;
        if (barangayName && normalizeName(incident.barangay_name) !== normalizeName(barangayName)) return;

        var lat = parseFloat(incident.latitude);
        var lng = parseFloat(incident.longitude);
        // Governor (pho) only: MDR-level incidents go to the optional orange
        // layer; every other role keeps the legacy single red incident layer.
        var isMdrStatus = isPhoRole && MDR_STATUSES.indexOf(incident.status) !== -1;
        var targetLayer = isMdrStatus ? mdrIncidentMarkerLayer : incidentMarkerLayer;
        var marker = L.marker([lat, lng], { icon: makeMarkerIcon(isMdrStatus ? 'incident-mdr-marker' : 'incident-marker') });
        marker.bindPopup(
            '<strong>' + escapeHtml(incident.disaster_type || 'Incident') + '</strong><br>' +
            'Barangay: ' + escapeHtml(incident.barangay_name || '—') + '<br>' +
            'Status: ' + escapeHtml(incident.status_label || '—')
        );
        marker.on('click', function() {
            renderIncidentBrief(incident);
        });
        marker.addTo(targetLayer);
    });
}

function selectBarangay(barangayName, zoomToBarangay) {
    if (!barangayLayer) {
        return;
    }

    if (selectedBarangayName === barangayName) {
        clearSelectedBarangay();
        return;
    }

    selectedBarangayName = barangayName;

    barangayLayer.eachLayer(function(layer) {
        var layerName = getBarangayName(layer.feature);
        barangayLayer.resetStyle(layer);

        if (layerName === barangayName) {
            selectedLayer = layer;
            layer.setStyle(selectedStyle);

            if (layer.bringToFront) {
                layer.bringToFront();
            }

            if (zoomToBarangay) {
                map.fitBounds(layer.getBounds(), {
                    padding: [24, 24]
                });
            }
        }
    });

    setActiveBarangayList(barangayName);
    renderEvacuationCenters(barangayName);
    renderMapMarkers(barangayName);
}

function clearSelectedBarangay() {
    selectedBarangayName = null;
    selectedLayer = null;

    if (barangayLayer) {
        barangayLayer.eachLayer(function(layer) {
            barangayLayer.resetStyle(layer);
        });

        map.fitBounds(barangayLayer.getBounds(), {
            padding: [18, 18]
        });
    }

    setActiveBarangayList('');
    renderEvacuationCenters('');
    renderMapMarkers('');
}

function resetBarangayMap() {
    clearSelectedBarangay();
}

function setActiveBarangayList(barangayName) {
    var items = document.querySelectorAll('.barangay-item');

    items.forEach(function(item) {
        if (item.getAttribute('data-name') === barangayName) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });
}

function renderBarangayList(names) {
    var list = document.getElementById('barangayList');
    var html = '';

    names.forEach(function(name) {
        html += '<button type="button" class="barangay-item" data-name="' + escapeHtml(name) + '" onclick="selectBarangay(\'' + escapeJs(name) + '\', true)">';
        html += '<span>' + escapeHtml(name) + '</span>';
        html += '</button>';
    });

    list.innerHTML = html;
}

function renderEvacuationCenters(barangayName) {
    var subtitle = document.getElementById('selectedBarangaySubtitle');
    var panel = document.getElementById('evacuationPanel');

    if (!barangayName) {
        subtitle.innerHTML = 'No barangay selected.';
        panel.innerHTML = '<div class="map-empty">Select a barangay to view evacuation centers.</div>';
        return;
    }

    var centers = V_evacuationCenters[barangayName] || [];
    var openCount = 0;
    var evacueeCount = 0;

    centers.forEach(function(center) {
        var status = String(center.status || '').toLowerCase();
        if (status === 'available' || status === 'open' || status === 'active') {
            openCount++;
        }
        evacueeCount += Number(center.current_evacuees || 0);
    });

    subtitle.innerHTML = 'Barangay: ' + escapeHtml(barangayName);

    var html = '';
    html += '<div class="evac-summary">';
    html += '<div class="evac-summary-box"><span>Open Centers</span><strong>' + Number(openCount).toLocaleString() + '</strong></div>';
    html += '<div class="evac-summary-box"><span>Current Evacuees</span><strong>' + Number(evacueeCount).toLocaleString() + '</strong></div>';
    html += '</div>';

    if (centers.length === 0) {
        html += '<div class="map-empty">No evacuation centers recorded for this barangay.</div>';
    }

    centers.forEach(function(center) {
        html += '<div class="evac-item">';
        html += '<div class="evac-item-title">' + escapeHtml(center.center_name) + '</div>';

        if (center.center_type) {
            html += '<small>Type: ' + escapeHtml(center.center_type) + '</small>';
        }

        html += '<small>Capacity: ' + Number(center.capacity || 0).toLocaleString() + '</small>';
        html += '<small>Current Evacuees: ' + Number(center.current_evacuees || 0).toLocaleString() + '</small>';

        if (center.contact_person) {
            html += '<small>Contact Person: ' + escapeHtml(center.contact_person) + '</small>';
        }

        if (center.contact_number) {
            html += '<small>Contact Number: ' + escapeHtml(center.contact_number) + '</small>';
        }

        html += '<span class="map-status-badge">' + escapeHtml(center.status || 'No status') + '</span>';

        if (hasCoordinates(center)) {
            html += '<span class="map-coordinate-badge">Pinned</span>';
        }

        html += '</div>';
    });

    panel.innerHTML = html + '<div id="incidentBriefPanel"></div>';

    // ── Recent Incident Brief ──────────────────────────────────────────────
    var recentIncident = null;
    for (var i = 0; i < V_incidentMarkers.length; i++) {
        if (normalizeName(V_incidentMarkers[i].barangay_name) === normalizeName(barangayName)) {
            recentIncident = V_incidentMarkers[i];
            break;
        }
    }
    renderIncidentBrief(recentIncident);
}

function renderIncidentBrief(incident) {
    var container = document.getElementById('incidentBriefPanel');
    if (!container) return;

    var html = '<div style="margin-top:18px; padding-top:14px; border-top:1px solid #e5e7eb;">';
    html += '<div style="font-size:12px; font-weight:700; color:#374151; text-transform:uppercase; letter-spacing:0.4px; margin-bottom:10px;">Recent Incident</div>';

    if (!incident) {
        html += '<div class="map-empty">No recent incidents for this barangay.</div>';
    } else {
        var rDate = incident.created_at ? new Date(incident.created_at.replace(' ', 'T')) : null;
        var rDateStr = rDate ? rDate.toLocaleDateString('en-US', { month:'short', day:'numeric', year:'numeric' }) + ', ' + rDate.toLocaleTimeString('en-US', { hour:'numeric', minute:'2-digit', hour12:true }) : '—';
        var rId = String(incident.id).padStart(4, '0');
        var affected = incident.affected_people || 0;
        var injured = incident.injured || 0;
        var impactParts = [];
        if (affected > 0) impactParts.push(affected + ' affected');
        if (injured > 0) impactParts.push(injured + ' injured');
        var impactStr = impactParts.length > 0 ? impactParts.join(', ') : 'No casualties reported';

        html += '<div style="background:#fff; border:1px solid #e5e7eb; border-radius:8px; padding:12px;">';
        html += '<div style="font-size:14px; font-weight:700; color:#1f2937; margin-bottom:4px;">#' + rId + ' — ' + escapeHtml(incident.disaster_type || 'Incident') + '</div>';
        html += '<div style="font-size:12px; color:#6b7280; margin-bottom:4px;">' + escapeHtml(impactStr) + '</div>';
        html += '<div style="font-size:12px; color:#6b7280; margin-bottom:4px;">' + escapeHtml(incident.barangay_name || '—') + ', ' + escapeHtml(incident.municipality || V_municipality || 'Aklan') + '</div>';
        html += '<div style="font-size:12px; color:#9ca3af; margin-bottom:6px;">' + rDateStr + ' (submitted)</div>';
        html += '<span class="map-status-badge">' + escapeHtml(incident.status_label || 'Pending') + '</span>';
        html += '</div>';
    }

    html += '</div>';
    container.innerHTML = html;
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function escapeJs(value) {
    return String(value || '')
        .replace(/\\/g, '\\\\')
        .replace(/'/g, "\\'")
        .replace(/"/g, '\\"');
}

function getBarangayNamesFromDatabase() {
    return V_barangays.map(function(item) {
        return item.name;
    });
}

/* Background (secondary) layer style — muted so the primary layer stands out */
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

function loadPrimaryLayer(url, onLoaded) {
    fetch(url)
        .then(function(response) {
            if (!response.ok) {
                throw new Error('GeoJSON file not found.');
            }
            return response.json();
        })
        .then(function(geojsonData) {
            var barangayNames = getBarangayNamesFromDatabase();

            barangayLayer = L.geoJSON(geojsonData, {
                style: function(feature) {
                    if (feature && feature.properties && feature.properties.level === 'municipality') {
                        return { color: '#7f1d1d', weight: 1.5, opacity: 0.8, fillColor: V_primaryColor, fillOpacity: 0, dashArray: '4 4' };
                    }
                    return defaultStyle;
                },
                onEachFeature: function(feature, layer) {
                    var barangayName = getBarangayName(feature);

                    if (feature && feature.properties && feature.properties.level === 'municipality') {
                        layer.bindTooltip(barangayName, { sticky: true });
                        return;
                    }

                    layer.bindTooltip(barangayName, {
                        sticky: true
                    });

                    layer.on({
                        mouseover: function() {
                            if (selectedBarangayName !== barangayName) {
                                layer.setStyle(hoverStyle);
                            }
                        },
                        mouseout: function() {
                            if (selectedBarangayName !== barangayName) {
                                barangayLayer.resetStyle(layer);
                            }
                        },
                        click: function() {
                            selectBarangay(barangayName, true);
                        }
                    });
                }
            }).addTo(map);

            if (barangayNames.length === 0) {
                geojsonData.features.forEach(function(feature) {
                    barangayNames.push(getBarangayName(feature));
                });
                barangayNames.sort();
            }

            renderBarangayList(barangayNames);

            map.fitBounds(barangayLayer.getBounds(), {
                padding: [18, 18]
            });

            renderMapMarkers('');

            if (V_userRole === 'barangay' && V_sessionBarangayName !== '') {
                var matchedBarangay = '';

                barangayNames.forEach(function(name) {
                    if (normalizeName(name) === normalizeName(V_sessionBarangayName)) {
                        matchedBarangay = name;
                    }
                });

                if (matchedBarangay !== '') {
                    setTimeout(function() {
                        selectBarangay(matchedBarangay, true);
                    }, 250);
                }
            }

            if (onLoaded) onLoaded();
        })
        .catch(function(error) {
            renderBarangayList(getBarangayNamesFromDatabase());
            document.getElementById('evacuationPanel').innerHTML = '<div class="map-empty">' + escapeHtml(error.message) + '</div>';
            map.setView([11.7060, 122.3640], 13);
            renderMapMarkers('');
        });
}

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
            }).addTo(map);
        })
        .catch(function() {});
}

/* Load the primary clickable layer for the user's municipality. MDR accounts
   stay focused on their assigned municipality, so no secondary layer loads. */
var isMdr = V_userRole === 'pcf' && ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay'].includes(V_subRole);
if (isIbajayPrimary) {
    loadPrimaryLayer('asset/data/ibajay_puroks.geojson', function() {
        if (!isMdr) loadSecondaryLayer('asset/data/kalibo_barangays.geojson', 'adm4_en');
    });
} else {
    loadPrimaryLayer('asset/data/kalibo_barangays.geojson', function() {
        if (!isMdr) loadSecondaryLayer('asset/data/ibajay_puroks.geojson', 'name');
    });
}
</script>

<?php include_once "../app/includes/footer.php"; ?>
