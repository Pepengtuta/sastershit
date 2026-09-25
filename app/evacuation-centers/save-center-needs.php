<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";
include "../includes/functions.php";

if (!isset($_SESSION['user_id']) || !can_manage_evacuation_centers($_SESSION['role'], $_SESSION['sub_role'] ?? '')) {
    header("Location: ../../public/evacuation-centers.php?denied=1");
    exit;
}

$V_center_id = (int)($_POST['N_evac_center_id'] ?? 0);

// Load the center so we can scope and reuse its is_demo flag.
$CenterStmt = mysqli_prepare($connection, "SELECT * FROM evacuation_centers WHERE id = ? LIMIT 1");
mysqli_stmt_bind_param($CenterStmt, "i", $V_center_id);
mysqli_stmt_execute($CenterStmt);
$center = mysqli_fetch_assoc(mysqli_stmt_get_result($CenterStmt));

if (!$center) {
    header("Location: ../../public/evacuation-centers.php");
    exit;
}

// Barangay chairmen may only edit the needs of their own barangay's centers.
if (($_SESSION['role'] ?? '') === 'barangay') {
    if ($center['barangay'] !== ($_SESSION['barangay_name'] ?? '')) {
        header("Location: ../../public/evacuation-centers.php?denied=1");
        exit;
    }
}

// MDR sub-roles may only edit needs within their own municipality.
if (($V_needs_muni = mdr_municipality($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? ''))) {
    if ($center['municipality'] !== $V_needs_muni) {
        header("Location: ../../public/evacuation-centers.php?denied=1");
        exit;
    }
}

// --- "Occupants" (profile) ------------------------------------------------
$V_profile_fields = [
    'N_total_evacuees', 'N_families', 'N_pregnant', 'N_lactating_mothers',
    'N_infants', 'N_children', 'N_older_persons', 'N_pwd', 'N_sick', 'N_injured'
];
$V_profile_vals = [];
foreach ($V_profile_fields as $field) {
    $val = (int)($_POST[$field] ?? 0);
    if ($val < 0) $val = 0;
    $V_profile_vals[] = $val;
}

// Profile source is client-declared: 'computed' ONLY when the human explicitly
// clicked "Use reported totals"; anything else (normal edit/save) is 'manual'.
$V_profile_source = (($_POST['N_profile_source'] ?? 'manual') === 'computed') ? 'computed' : 'manual';

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

$V_is_demo = (int)($center['is_demo'] ?? 0);
$V_user_id = (int)($_SESSION['user_id'] ?? 0);
$ProfileStmt = mysqli_prepare($connection, $UpsertProfile);
mysqli_stmt_bind_param($ProfileStmt, "iiiiiiiiiiisii",
    $V_center_id, $V_profile_vals[0], $V_profile_vals[1], $V_profile_vals[2],
    $V_profile_vals[3], $V_profile_vals[4], $V_profile_vals[5], $V_profile_vals[6],
    $V_profile_vals[7], $V_profile_vals[8], $V_profile_vals[9],
    $V_profile_source, $V_is_demo, $V_user_id);

if (!mysqli_stmt_execute($ProfileStmt)) {
    echo fail_message("Something went wrong saving the profile.", "DB error: " . mysqli_error($connection));
    exit;
}

// --- "Needed supplies" (upsert by item name) -------------------------------
// Match existing rows by lowercase item name and UPDATE in place, keeping the
// row id. evac_assistance.need_id references these ids, so deleting + re-inserting
// every row (the old behaviour) orphaned pledges and stopped their Sent/Delivered
// quantities from counting toward the item's unmet total.
$V_items = $_POST['N_item'] ?? [];
$V_qtys  = $_POST['N_qty'] ?? [];
$V_units = $_POST['N_unit'] ?? [];

// Merge the three arrays by row index, keeping only valid rows.
$V_rows = [];
foreach ($V_items as $i => $item) {
    $item = trim((string)$item);
    $qty = (int)($V_qtys[$i] ?? 0);
    $unit = trim((string)($V_units[$i] ?? 'pcs'));
    $allowed_units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];
    if ($item === '' || $qty <= 0) continue;
    if (!in_array($unit, $allowed_units, true)) $unit = 'pcs';
    $V_rows[] = [$item, $qty, $unit];
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
foreach ($V_rows as $row) {
    $V_key = strtolower(trim($row[0]));
    $V_submitted_keys[$V_key] = true;
    if (isset($V_existing[$V_key])) {
        mysqli_stmt_bind_param($UpdateNeeds, "sii", $row[2], $row[1], $V_existing[$V_key]['id']);
        if (!mysqli_stmt_execute($UpdateNeeds)) {
            mysqli_rollback($connection);
            echo fail_message("Something went wrong saving the needs.", "DB error: " . mysqli_error($connection));
            exit;
        }
    } else {
        mysqli_stmt_bind_param($InsertNeeds, "issiii", $V_center_id, $row[0], $row[2], $row[1], $V_is_demo, $V_user_id);
        if (!mysqli_stmt_execute($InsertNeeds)) {
            mysqli_rollback($connection);
            echo fail_message("Something went wrong saving the needs.", "DB error: " . mysqli_error($connection));
            exit;
        }
    }
}

// Delete only rows whose item was genuinely removed from the submitted list.
foreach ($V_existing as $V_key => $V_n) {
    if (!isset($V_submitted_keys[$V_key])) {
        mysqli_stmt_bind_param($DeleteNeed, "i", $V_n['id']);
        if (!mysqli_stmt_execute($DeleteNeed)) {
            mysqli_rollback($connection);
            echo fail_message("Something went wrong saving the needs.", "DB error: " . mysqli_error($connection));
            exit;
        }
    }
}

mysqli_commit($connection);

header("Location: ../../public/center-needs.php?id=" . $V_center_id . "&saved=1");
exit;
?>