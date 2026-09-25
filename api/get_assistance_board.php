<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
require_once "../app/includes/functions.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");

// Only Superadmin / PHO / PCF (all sub-roles, incl. read-only mayors/Governor)
// may view the Needs & Assistance board.
$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
if (!$actorRow || $actorRow['status'] !== 'Active') {
    send_response(false, "You are not authorized to view the assistance board.");
}
$V_role = $actorRow['role'];
$V_sub_role = $actorRow['sub_role'] ?? '';
if (!in_array($V_role, ['superadmin', 'pho', 'pcf'], true)) {
    send_response(false, "You are not authorized to view the assistance board.");
}
// All roles that can view the board (superadmin/pho/pcf, all sub-roles) can also pledge.
$V_can_pledge = true;
// Provincial status override: superadmin, PHO admin (empty sub_role), and PDRRMO.
// The Governor (sub_role 'governor') is NOT an override - it only manages its own pledges.
$V_prov_override = ($V_role === 'superadmin') || ($V_role === 'pho' && strtolower(trim((string)$V_sub_role)) !== 'governor');

// Scope by effective municipality: MDR/mayor sub-roles are forced; others use the input filter.
$V_muni = null;
if ($V_role === 'pcf') {
    if (in_array($V_sub_role, ['mdr_kalibo', 'mayor_kalibo'], true)) $V_muni = 'Kalibo';
    elseif (in_array($V_sub_role, ['mdr_ibajay', 'mayor_ibajay'], true)) $V_muni = 'Ibajay';
}
if ($V_muni === null) {
    $V_muni = trim($input['municipality'] ?? '');
}
$V_muni_where = '';
$V_muni_bind = '';
if ($V_muni !== '') {
    $V_muni_where = "AND ec.municipality = ?";
    $V_muni_bind = "s";
}
// Also confirm from DB (defense in depth): read actor's forced sub-role.
if ($V_role === 'pcf') {
    $checkStmt = mysqli_prepare($connection, "SELECT sub_role FROM users WHERE id = ? LIMIT 1");
    mysqli_stmt_bind_param($checkStmt, "i", $acting_user_id);
    mysqli_stmt_execute($checkStmt);
    $checkRow = mysqli_fetch_assoc(mysqli_stmt_get_result($checkStmt));
    $sub = strtolower(trim($checkRow['sub_role'] ?? ''));
    if ($sub === 'mdr_kalibo' || $sub === 'mayor_kalibo') $V_muni = 'Kalibo';
    elseif ($sub === 'mdr_ibajay' || $sub === 'mayor_ibajay') $V_muni = 'Ibajay';
    if ($V_muni !== '') { $V_muni_where = "AND ec.municipality = ?"; $V_muni_bind = "s"; }
}

// Zero-pledge centers: has a profile/needs but not even one pledge yet.
$zeroSql = "SELECT ec.id, ec.center_name, ec.barangay, ec.municipality, ec.status
            FROM evacuation_centers ec
            WHERE (EXISTS (SELECT 1 FROM evac_center_profile p WHERE p.evac_center_id = ec.id)
                OR EXISTS (SELECT 1 FROM evac_center_needs n WHERE n.evac_center_id = ec.id))
              AND NOT EXISTS (SELECT 1 FROM evac_assistance a WHERE a.evac_center_id = ec.id)
              AND ec.status IN ('" . implode("','", center_status_allowlist()) . "')
              $V_muni_where
            ORDER BY ec.municipality ASC, ec.barangay ASC, ec.center_name ASC";
$zeroCenters = board_fetch_all($connection, $zeroSql, $V_muni_bind, $V_muni);

// "Occupants" profiles. DSWD codes: A = older persons, B = lactating mothers,
// C = PWD. Shown as chips on the board.
$profilesSql = "SELECT p.evac_center_id, p.total_evacuees, p.families, p.pregnant,
                       p.lactating_mothers, p.infants, p.children,
                       p.older_persons, p.pwd, p.sick, p.injured
                FROM evac_center_profile p
                INNER JOIN evacuation_centers ec ON ec.id = p.evac_center_id
                WHERE ec.status IN ('Open','Full','Needs Supplies','Available')$V_muni_where
                ORDER BY p.evac_center_id ASC";
$V_profiles = [];
foreach (board_fetch_all($connection, $profilesSql, $V_muni_bind, $V_muni) as $p) {
    $cid = (int)$p['evac_center_id'];
    $V_types = [];
    foreach ([
        ["code" => 'A', "label" => 'Older Persons', "count" => (int)$p['older_persons']],
        ["code" => 'B', "label" => 'Lactating Mothers', "count" => (int)$p['lactating_mothers']],
        ["code" => 'C', "label" => 'PWD', "count" => (int)$p['pwd']],
        ["code" => 'P', "label" => 'Pregnant', "count" => (int)$p['pregnant']],
        ["code" => 'I', "label" => 'Infants', "count" => (int)$p['infants']],
        ["code" => 'K', "label" => 'Children', "count" => (int)$p['children']],
        ["code" => 'S', "label" => 'Sick', "count" => (int)$p['sick']],
        ["code" => 'J', "label" => 'Injured', "count" => (int)$p['injured']],
    ] as $V_t) {
        if ($V_t['count'] > 0) $V_types[] = $V_t;
    }
    $V_profiles[$cid] = [
        "total_evacuees" => (int)$p['total_evacuees'],
        "families" => (int)$p['families'],
        "pregnant" => (int)$p['pregnant'],
        "lactating_mothers" => (int)$p['lactating_mothers'],
        "infants" => (int)$p['infants'],
        "children" => (int)$p['children'],
        "older_persons" => (int)$p['older_persons'],
        "pwd" => (int)$p['pwd'],
        "sick" => (int)$p['sick'],
        "injured" => (int)$p['injured'],
        "types" => $V_types,
    ];
}

/// Executes a prepared SELECT (fully consuming the result immediately, which
/// avoids MySQL "commands out of sync") and returns all rows as an array.
function board_fetch_all($connection, $sql, $bind_types, $bind_val) {
    $stmt = mysqli_prepare($connection, $sql);
    if (!$stmt) { send_response(false, "Failed to prepare board query."); }
    if ($bind_types !== '') { mysqli_stmt_bind_param($stmt, $bind_types, $bind_val); }
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);
    if (!$result) { send_response(false, "Failed to run board query: " . mysqli_error($connection)); }
    $rows = [];
    while ($row = mysqli_fetch_assoc($result)) { $rows[] = $row; }
    return $rows;
}

// Needs board. ONLY barangay-confirmed ('Received' = received_at set) supply
// counts toward the need; 'Sent'/'Delivered' are incoming / awaiting confirmation.
$needsSql = "SELECT ec.id AS center_id, ec.center_name, ec.barangay, ec.municipality, ec.status,
                    n.id AS need_id, n.item, n.unit, n.qty_needed,
                    COALESCE(s.received_qty, 0) AS received_qty,
                    COALESCE(p.pending_qty, 0) AS pending_qty,
                    COALESCE(i.incoming_qty, 0) AS incoming_qty
             FROM evac_center_needs n
             INNER JOIN evacuation_centers ec ON ec.id = n.evac_center_id
             LEFT JOIN (SELECT need_id, SUM(COALESCE(qty_received, qty)) AS received_qty FROM evac_assistance
                        WHERE received_at IS NOT NULL GROUP BY need_id) s ON s.need_id = n.id
             LEFT JOIN (SELECT need_id, SUM(qty) AS pending_qty FROM evac_assistance
                        WHERE status = 'Delivered' AND received_at IS NULL GROUP BY need_id) p ON p.need_id = n.id
             LEFT JOIN (SELECT need_id, SUM(qty) AS incoming_qty FROM evac_assistance
                        WHERE status IN ('Pledged','Sent') GROUP BY need_id) i ON i.need_id = n.id
             WHERE ec.status IN ('Open','Full','Needs Supplies','Available')
               $V_muni_where
             ORDER BY ec.municipality ASC, ec.barangay ASC, ec.center_name ASC, n.id ASC";
$needsRows = board_fetch_all($connection, $needsSql, $V_muni_bind, $V_muni);

$ledgerSql = "SELECT a.id, a.evac_center_id, a.donor_user_id, a.donor_label, a.item, a.unit, a.qty, a.qty_received,
                     a.status, a.remarks, a.over_pledge_flag, a.pledged_at, a.sent_at, a.delivered_at,
                     a.received_at, a.confirmed_by_user_id,
                     n.item AS need_item
              FROM evac_assistance a
              INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
              LEFT JOIN evac_center_needs n ON n.id = a.need_id
              WHERE 1 = 1
              $V_muni_where
              ORDER BY a.created_at DESC, a.id DESC";
$ledgerRows = board_fetch_all($connection, $ledgerSql, $V_muni_bind, $V_muni);

// Group needs by center; attach each center's ledger rows.
$V_board = [];
foreach ($needsRows as $need) {
    $cid = (int)$need['center_id'];
    if (!isset($V_board[$cid])) {
        $V_board[$cid] = [
            "id" => $cid,
            "center_name" => $need['center_name'],
            "barangay" => $need['barangay'],
            "municipality" => $need['municipality'],
            "status" => $need['status'],
            "profile" => $V_profiles[$cid] ?? [],
            "types" => $V_profiles[$cid]['types'] ?? [],
            "needs" => [],
            "ledger" => [],
        ];
    }
    $qty_needed = (int)$need['qty_needed'];
    $received_qty = (int)$need['received_qty'];
    $V_board[$cid]['needs'][] = [
        "id" => (int)$need['need_id'],
        "item" => $need['item'],
        "unit" => $need['unit'],
        "qty_needed" => $qty_needed,
        "received_qty" => $received_qty,
        "pending_qty" => (int)$need['pending_qty'],
        "incoming_qty" => (int)$need['incoming_qty'],
        "unmet" => max(0, $qty_needed - $received_qty),
        "fulfilled" => ($received_qty >= $qty_needed),
    ];
}
foreach ($ledgerRows as $d) {
    $cid = (int)$d['evac_center_id'];
    if (isset($V_board[$cid])) {
        $is_donor = ((int)$d['donor_user_id'] === $acting_user_id);
        $V_board[$cid]['ledger'][] = [
            "id" => (int)$d['id'],
            "donor_label" => $d['donor_label'],
            "item" => $d['item'],
            "unit" => $d['unit'],
            "qty" => (int)$d['qty'],
            "qty_received" => $d['qty_received'] !== null ? (int)$d['qty_received'] : null,
            "status" => $d['status'],
            "remarks" => $d['remarks'],
            "for_item" => $d['need_item'],
            "can_manage_status" => ($is_donor || $V_prov_override) && $V_can_pledge,
            "over_pledge" => (int)$d['over_pledge_flag'],
            "pledged_at" => $d['pledged_at'],
            "sent_at" => $d['sent_at'],
            "delivered_at" => $d['delivered_at'],
            "received_at" => $d['received_at'],
            "confirmed_by_user_id" => $d['confirmed_by_user_id'],
        ];
    }
}

// Attach the credited incident reference to each center on the board.
foreach ($V_board as $cid => $centerEntry) {
    $V_inc = credited_incident_for_center($connection, $cid);
    $V_board[$cid]["incident"] = $V_inc ? [
        "id" => (int)$V_inc['id'],
        "disaster_type" => $V_inc['disaster_type'],
        "status" => $V_inc['status'],
        "status_label" => incident_status_label($V_inc['status'], $V_board[$cid]['municipality'] ?? ''),
        "incident_datetime" => $V_inc['incident_datetime'],
    ] : null;
}

$V_unmet_total = 0;
$V_incoming_total = 0;
$V_pending_total = 0;
$V_pledge_count = 0;
foreach ($V_board as $centerData) {
    foreach ($centerData['needs'] as $n) { $V_unmet_total += $n['unmet']; }
    foreach ($centerData['ledger'] as $d) {
        if (in_array($d['status'], ['Pledged', 'Sent'], true)) $V_incoming_total += $d['qty'];
        if ($d['status'] === 'Delivered' && empty($d['received_at'])) $V_pending_total += $d['qty'];
        $V_pledge_count++;
    }
}
// My pledges (rows by this actor).
$mySql = "SELECT COUNT(*) AS c FROM evac_assistance WHERE donor_user_id = ? ";
if ($V_muni_bind) {
    $mySql .= " AND evac_center_id IN (SELECT id FROM evacuation_centers WHERE municipality = ?)";
    $myStmt = mysqli_prepare($connection, $mySql);
    mysqli_stmt_bind_param($myStmt, "is", $acting_user_id, $V_muni);
} else {
    $myStmt = mysqli_prepare($connection, $mySql);
    mysqli_stmt_bind_param($myStmt, "i", $acting_user_id);
}
mysqli_stmt_execute($myStmt);
$myRow = mysqli_fetch_assoc(mysqli_stmt_get_result($myStmt));

send_response(true, "Assistance board loaded successfully.", [
    "scope_label" => $V_muni === '' ? 'All Municipalities' : $V_muni,
    "can_pledge" => $V_can_pledge,
    "zero_pledge_centers" => $zeroCenters,
    "centers" => array_values($V_board),
    "summary" => [
        "unmet_total" => $V_unmet_total,
        "incoming_total" => $V_incoming_total,
        "pending_confirmation_total" => $V_pending_total,
        "pledge_count" => $V_pledge_count,
        "my_pledges" => (int)($myRow['c'] ?? 0),
        "zero_pledge_count" => count($zeroCenters),
    ],
]);
?>