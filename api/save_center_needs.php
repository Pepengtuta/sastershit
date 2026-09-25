<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = []) { echo json_encode(["success"=>$success,"message"=>$message,"data"=>$data]); exit; }
$input = json_decode(file_get_contents("php://input"), true);
if (!$input) send_response(false, "Invalid JSON input.");

// Same permissions as managing evacuation centers: Superadmin / PHO / PCF,
// plus Barangay Chairmen (captain) scoped to their OWN barangay.
$acting_user_id = (int)($input['acting_user_id'] ?? 0);
$actorStmt = mysqli_prepare($connection, "SELECT role, sub_role, status, barangay_id FROM users WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
mysqli_stmt_execute($actorStmt);
$actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
$V_allowed_actor = ['superadmin', 'pho', 'pcf'];
if ($actorRow && $actorRow['role'] === 'barangay' && in_array(($actorRow['sub_role'] ?? ''), ['captain', 'secretary'], true)) {
    $V_allowed_actor[] = 'barangay';
}
if (!$actorRow || $actorRow['status'] !== 'Active' || !in_array($actorRow['role'], $V_allowed_actor)) {
    send_response(false, "You are not authorized to edit center needs.");
}
// Read-only observers (mayors + Governor) cannot edit needs.
if ($actorRow['role'] === 'pcf' && in_array($actorRow['sub_role'] ?? '', ['mayor_kalibo', 'mayor_ibajay'], true)
        || ($actorRow['role'] === 'pho' && ($actorRow['sub_role'] ?? '') === 'governor')) {
    send_response(false, "You are not authorized to edit center needs.");
}

$V_center_id = (int)($input['evac_center_id'] ?? 0);
$CenterStmt = mysqli_prepare($connection, "SELECT * FROM evacuation_centers WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($CenterStmt, "i", $V_center_id);
mysqli_stmt_execute($CenterStmt);
$center = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterStmt));
if (!$center) send_response(false, "Evacuation center not found.");

// Barangay chairmen may only edit their own barangay's centers.
if ($actorRow['role'] === 'barangay') {
    $brgyStmt = mysqli_prepare($connection, "SELECT name FROM barangays WHERE id = ? LIMIT 1");
    $V_actor_barangay_id = (int)$actorRow['barangay_id'];
    mysqli_stmt_bind_param($brgyStmt, "i", $V_actor_barangay_id);
    mysqli_stmt_execute($brgyStmt);
    $brgyRow = mysqli_fetch_assoc(mysqli_stmt_get_result($brgyStmt));
    if (!$brgyRow || $center['barangay'] !== $brgyRow['name']) {
        send_response(false, "You may only edit centers in your own barangay.");
    }
}
// MDR sub-roles only their own municipality.
$mdr_muni = ['mdr_kalibo' => 'Kalibo', 'mdr_ibajay' => 'Ibajay'][$actorRow['sub_role']] ?? null;
if ($actorRow['role'] === 'pcf' && $mdr_muni !== null && $center['municipality'] !== $mdr_muni) {
    send_response(false, "You may only edit centers in " . $mdr_muni . ".");
}

$V_is_demo = (int)($center['is_demo'] ?? 0);
$V_user_id = (int)$acting_user_id;

// --- "Occupants" (profile) ------------------------------------------------
$V_profile_fields = [
    'total_evacuees', 'families', 'pregnant', 'lactating_mothers',
    'infants', 'children', 'older_persons', 'pwd', 'sick', 'injured'
];
$V_profile_vals = [];
foreach ($V_profile_fields as $field) {
    $val = (int)($input[$field] ?? 0);
    if ($val < 0) $val = 0;
    $V_profile_vals[] = $val;
}
// Profile source is client-declared: 'computed' ONLY when the human explicitly
// clicked "Use reported totals"; anything else (normal edit/save) is 'manual'.
$V_profile_source = (($input['profile_source'] ?? 'manual') === 'computed') ? 'computed' : 'manual';

$UpsertProfile = "INSERT INTO evac_center_profile
    (evac_center_id, total_evacuees, families, pregnant, lactating_mothers,
     infants, children, older_persons, pwd, sick, injured, source, is_demo, updated_by)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      total_evacuees = VALUES(total_evacuees), families = VALUES(families),
      pregnant = VALUES(pregnant), lactating_mothers = VALUES(lactating_mothers),
      infants = VALUES(infants), children = VALUES(children),
      older_persons = VALUES(older_persons), pwd = VALUES(pwd),
      sick = VALUES(sick), injured = VALUES(injured),
      source = VALUES(source), updated_by = VALUES(updated_by)";
$ProfileStmt = mysqli_prepare($connection, $UpsertProfile);
mysqli_stmt_bind_param($ProfileStmt, "iiiiiiiiiiisii",
    $V_center_id, $V_profile_vals[0], $V_profile_vals[1], $V_profile_vals[2],
    $V_profile_vals[3], $V_profile_vals[4], $V_profile_vals[5], $V_profile_vals[6],
    $V_profile_vals[7], $V_profile_vals[8], $V_profile_vals[9],
    $V_profile_source, $V_is_demo, $V_user_id);
if (!mysqli_stmt_execute($ProfileStmt)) {
    send_response(false, "Failed to save profile.");
}

// --- "Needed supplies" (upsert by item name) -------------------------------
// Match existing rows by lowercase item name and UPDATE in place, keeping the
// row id. evac_assistance.need_id references these ids, so deleting + re-inserting
// every row (the old behaviour) orphaned pledges and stopped their Sent/Delivered
// quantities from counting toward the item's unmet total.
$V_items = $input['items'] ?? [];
$rows = [];
foreach ($V_items as $i => $item) {
    $name = trim((string)($item['item'] ?? ''));
    $qty = (int)($item['qty'] ?? 0);
    $unit = trim((string)($item['unit'] ?? 'pcs'));
    $allowed_units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];
    if ($name === '' || $qty <= 0) continue;
    if (!in_array($unit, $allowed_units, true)) $unit = 'pcs';
    $rows[] = [$name, $qty, $unit];
}

mysqli_begin_transaction($connection);

// Load existing needs for this center, keyed by lowercase item name.
$ExistingStmt = mysqli_prepare($connection, "SELECT id, item, qty_needed, unit, is_demo, created_by FROM evac_center_needs WHERE evac_center_id = ?");
mysqli_stmt_bind_param($ExistingStmt, "i", $V_center_id);
mysqli_stmt_execute($ExistingStmt);
$V_existing = [];
$V_existing_res = mysqli_stmt_get_result($ExistingStmt);
if ($V_existing_res) {
    while ($V_n = mysqli_fetch_assoc($V_existing_res)) {
        $V_existing[strtolower(trim($V_n['item']))] = $V_n;
    }
    mysqli_free_result($V_existing_res);
}
mysqli_stmt_free_result($ExistingStmt);

$UpdateNeeds = mysqli_prepare($connection, "UPDATE evac_center_needs SET unit = ?, qty_needed = ? WHERE id = ?");
$InsertNeeds = mysqli_prepare($connection, "INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
                                            VALUES (?, ?, ?, ?, ?, ?)");
$DeleteNeed = mysqli_prepare($connection, "DELETE FROM evac_center_needs WHERE id = ?");

$V_submitted_keys = [];
foreach ($rows as $row) {
    $V_key = strtolower(trim($row[0]));
    $V_submitted_keys[$V_key] = true;
    if (isset($V_existing[$V_key])) {
        mysqli_stmt_bind_param($UpdateNeeds, "sii", $row[2], $row[1], $V_existing[$V_key]['id']);
        if (!mysqli_stmt_execute($UpdateNeeds)) {
            mysqli_rollback($connection);
            send_response(false, "Failed to save needs list.");
        }
    } else {
        mysqli_stmt_bind_param($InsertNeeds, "issiii", $V_center_id, $row[0], $row[2], $row[1], $V_is_demo, $V_user_id);
        if (!mysqli_stmt_execute($InsertNeeds)) {
            mysqli_rollback($connection);
            send_response(false, "Failed to save needs list.");
        }
    }
}

// Delete only rows whose item was genuinely removed from the submitted list.
foreach ($V_existing as $V_key => $V_n) {
    if (!isset($V_submitted_keys[$V_key])) {
        mysqli_stmt_bind_param($DeleteNeed, "i", $V_n['id']);
        if (!mysqli_stmt_execute($DeleteNeed)) {
            mysqli_rollback($connection);
            send_response(false, "Failed to save needs list.");
        }
    }
}

mysqli_commit($connection);

send_response(true, "Center needs saved successfully.", ["evac_center_id" => $V_center_id]);
?>