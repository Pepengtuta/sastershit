<?php
$V_page_title = "Evacuation Center Needs";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/functions.php";

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';

if (!can_manage_evacuation_centers($V_role, $V_sub_role)) {
    header("Location: evacuation-centers.php?denied=1");
    exit;
}

$V_ID = (int)($_GET['id'] ?? 0);

// Chairmen only edit the needs of their OWN barangay's centers.
$V_needs_locked = false;
if ($V_role === 'barangay') {
    $CenterQuery = "SELECT * FROM evacuation_centers WHERE id = ? AND barangay = ?";
    $CenterStmt = mysqli_prepare($connection, $CenterQuery);
    $V_actor_barangay_name = $_SESSION['barangay_name'] ?? '';
    mysqli_stmt_bind_param($CenterStmt, "is", $V_ID, $V_actor_barangay_name);
} elseif (($V_needs_muni = mdr_municipality($V_role, $V_sub_role))) {
    // MDR sub-roles stay inside their own municipality.
    $CenterQuery = "SELECT * FROM evacuation_centers WHERE id = ? AND municipality = ?";
    $CenterStmt = mysqli_prepare($connection, $CenterQuery);
    mysqli_stmt_bind_param($CenterStmt, "is", $V_ID, $V_needs_muni);
} else {
    $CenterQuery = "SELECT * FROM evacuation_centers WHERE id = ?";
    $CenterStmt = mysqli_prepare($connection, $CenterQuery);
    mysqli_stmt_bind_param($CenterStmt, "i", $V_ID);
}
mysqli_stmt_execute($CenterStmt);
$CenterRes = mysqli_stmt_get_result($CenterStmt);
if (!$CenterRes) {
    error_log("center-needs: center query failed: " . mysqli_error($connection));
    http_response_code(500);
    exit("Unable to load that evacuation center. Please try again.");
}
$center = mysqli_fetch_assoc($CenterRes);
mysqli_free_result($CenterRes);

if (!$center) {
    header("Location: evacuation-centers.php");
    exit;
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

// Load any existing profile ("occupants").
$profile = null;
$ProfileStmt = mysqli_prepare($connection, "SELECT * FROM evac_center_profile WHERE evac_center_id = ? LIMIT 1");
mysqli_stmt_bind_param($ProfileStmt, "i", $V_ID);
mysqli_stmt_execute($ProfileStmt);
$ProfileRes = mysqli_stmt_get_result($ProfileStmt);
if (!$ProfileRes) {
    error_log("center-needs: profile query failed: " . mysqli_error($connection));
    http_response_code(500);
    exit("Unable to load the center profile. Please try again.");
}
$profile = mysqli_fetch_assoc($ProfileRes);
mysqli_free_result($ProfileRes);

// Load existing needs list ("needed supplies").
$needs = [];
$NeedsStmt = mysqli_prepare($connection, "SELECT id, item, unit, qty_needed FROM evac_center_needs WHERE evac_center_id = ? ORDER BY id ASC");
if (!$NeedsStmt) {
    error_log("center-needs: needs query could not be prepared: " . mysqli_error($connection));
    http_response_code(500);
    exit("Unable to load need items. Please try again.");
}
mysqli_stmt_bind_param($NeedsStmt, "i", $V_ID);
if (!mysqli_stmt_execute($NeedsStmt)) {
    error_log("center-needs: needs query failed: " . mysqli_stmt_error($NeedsStmt));
    http_response_code(500);
    exit("Unable to load need items. Please try again.");
}
$NeedsRes = mysqli_stmt_get_result($NeedsStmt);
if (!$NeedsRes) {
    error_log("center-needs: needs result failed: " . mysqli_error($connection));
    http_response_code(500);
    exit("Unable to load need items. Please try again.");
}
while ($n = mysqli_fetch_assoc($NeedsRes)) {
    $needs[] = $n;
}
mysqli_free_result($NeedsRes);

// Fulfillment status per need (read-only): pledged / sent / delivered / received + who is helping.
$fulfillment = [];
$FullStmt = mysqli_prepare($connection, "SELECT need_id,
                       SUM(CASE WHEN status = 'Pledged' THEN qty ELSE 0 END) AS pledged_qty,
                       SUM(CASE WHEN status = 'Sent' THEN qty ELSE 0 END) AS sent_qty,
                       SUM(CASE WHEN status = 'Delivered' THEN qty ELSE 0 END) AS delivered_qty,
                       SUM(CASE WHEN received_at IS NOT NULL THEN COALESCE(qty_received, qty) ELSE 0 END) AS received_qty,
                       GROUP_CONCAT(DISTINCT donor_label ORDER BY donor_label SEPARATOR ', ') AS helpers
                   FROM evac_assistance
                   WHERE evac_center_id = ?
                   GROUP BY need_id");
if (!$FullStmt) {
    error_log("center-needs: fulfillment query could not be prepared: " . mysqli_error($connection));
} else {
    mysqli_stmt_bind_param($FullStmt, "i", $V_ID);
    if (mysqli_stmt_execute($FullStmt)) {
        $FullRes = mysqli_stmt_get_result($FullStmt);
        if ($FullRes) {
            while ($f = mysqli_fetch_assoc($FullRes)) {
                $key = ($f['need_id'] !== null) ? (int)$f['need_id'] : 'unlinked';
                $fulfillment[$key] = [
                    'pledged'   => (int)$f['pledged_qty'],
                    'sent'      => (int)$f['sent_qty'],
                    'delivered' => (int)$f['delivered_qty'],
                    'received'  => (int)$f['received_qty'],
                    'helpers'   => $f['helpers'] ?? '',
                ];
            }
            mysqli_free_result($FullRes);
        }
    } else {
        error_log("center-needs: fulfillment query failed: " . mysqli_stmt_error($FullStmt));
    }
    mysqli_stmt_free_result($FullStmt);
}

// Per-donation ledger for this center (read-only): who donated what, when.
$ledger = [];
$LedgerStmt = mysqli_prepare($connection, "SELECT a.id, a.donor_label, a.item, a.unit, a.qty, a.qty_received, a.status,
                     a.over_pledge_flag, a.pledged_at, a.sent_at, a.delivered_at, a.received_at, a.confirmed_by_user_id,
                     n.item AS need_item
              FROM evac_assistance a
              LEFT JOIN evac_center_needs n ON n.id = a.need_id
              WHERE a.evac_center_id = ?
              ORDER BY a.created_at DESC, a.id DESC");
if ($LedgerStmt) {
    mysqli_stmt_bind_param($LedgerStmt, "i", $V_ID);
    if (mysqli_stmt_execute($LedgerStmt)) {
        $LedgerRes = mysqli_stmt_get_result($LedgerStmt);
        if ($LedgerRes) {
            while ($d = mysqli_fetch_assoc($LedgerRes)) {
                $ledger[] = $d;
            }
            mysqli_free_result($LedgerRes);
        }
    } else {
        error_log("center-needs: ledger query failed: " . mysqli_stmt_error($LedgerStmt));
    }
    mysqli_stmt_free_result($LedgerStmt);
}

// The incident this center is backed by, if any (null when needs are unverified).
$V_credited_incident = credited_incident_for_center($connection, $V_ID);

// Read-only reference headcount from credited linked reports (never overwrites profile).
$V_computed_headcount = computed_headcount_for_center($connection, $V_ID);

// Show the "reported totals" banner when credited reports exist AND differ from the
// current manual profile — or when there is no profile yet at all.
$V_show_headcount_banner = false;
$V_prefill_defaults = [];
if ($V_computed_headcount['report_count'] > 0) {
    if (!$profile) {
        $V_show_headcount_banner = true;
    } else {
        $V_show_headcount_banner = ((int)$V_computed_headcount['total_evacuees'] !== (int)$profile['total_evacuees'])
            || ((int)$V_computed_headcount['households'] !== (int)$profile['families'])
            || ((int)$V_computed_headcount['children'] !== (int)$profile['children']);
    }
    // Only used to pre-fill the inputs when no profile row exists yet.
    $V_prefill_defaults = [
        'total_evacuees' => (int)$V_computed_headcount['total_evacuees'],
        'families'       => (int)$V_computed_headcount['households'],
        'children'       => (int)$V_computed_headcount['children'],
    ];
}

// At-a-glance fulfillment summary: only barangay-confirmed ('Received') supply fulfills.
$V_needs_met = 0;
$V_needs_total = count($needs);
foreach ($needs as $V_n) {
    $V_n_sf = $fulfillment[$V_n['id']] ?? ['received' => 0];
    if ((int)$V_n['qty_needed'] > 0 && (int)$V_n_sf['received'] >= (int)$V_n['qty_needed']) {
        $V_needs_met++;
    }
}

$V_units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];
$V_status_classes = [
    'Pledged'   => 'badge-soft-secondary',
    'Sent'      => 'badge-soft-info',
    'Delivered' => 'badge-soft-success',
];
$V_profile_fields = [
    'N_total_evacuees'    => 'Total Evacuees',
    'N_families'          => 'Families',
    'N_pregnant'          => 'Pregnant',
    'N_lactating_mothers' => 'Lactating Mothers (Code B)',
    'N_infants'           => 'Infants (0-2 yrs)',
    'N_children'          => 'Children (3-12 yrs)',
    'N_older_persons'     => 'Older Persons (Code A)',
    'N_pwd'               => 'PWD (Code C)',
    'N_sick'              => 'Sick',
    'N_injured'           => 'Injured',
];
?>

<div class="panel-card form-panel">
    <div class="panel-header">
        <div>
            <h2>Evacuation Center Needs</h2>
            <p><strong><?php echo h($center['center_name']); ?></strong> &middot; <?php echo h($center['barangay']); ?>, <?php echo h($center['municipality']); ?></p>
        </div>
        <?php if ($V_role === 'barangay') { ?>
            <span class="soft-badge badge-soft-secondary">Own barangay only</span>
        <?php } ?>
    </div>

<?php if (isset($_GET['saved'])) { ?><div class="alert alert-success py-2">Needs and profile saved successfully.</div><?php } ?>
<?php if (isset($_GET['received'])) { ?><div class="alert alert-success py-2">Donation confirmed as received. Shortfalls stay "Still Needed".</div><?php } ?>
<?php if (isset($_GET['invalid_qty'])) { ?><div class="alert alert-danger py-2">Received quantity must be between 1 and the donor's declared quantity.</div><?php } ?>

    <?php if ($V_credited_incident): ?>
        <div class="alert alert-success py-2 d-flex align-items-center gap-2">
            <span>Verified claim &mdash; this center is backed by a confirmed <strong><?php echo h($V_credited_incident['disaster_type']); ?></strong>
            incident (<?php echo h(date('M j, Y', strtotime($V_credited_incident['incident_datetime'] ?: $V_credited_incident['created_at']))); ?>, <?php echo h(incident_status_label($V_credited_incident['status'], $center['municipality'] ?? '')); ?>).</span>
        </div>
    <?php else: ?>
        <div class="alert alert-warning py-2">
            No linked incident report &mdash; higher-ups will see these needs as <strong>unverified</strong>. File an incident report and link this evacuation center to make the request traceable.
        </div>
<?php endif; ?>

    <?php if ($V_needs_total > 0) { ?>
        <div class="mb-3">
            <span class="soft-badge badge-soft-success"><?php echo $V_needs_met; ?> of <?php echo $V_needs_total; ?> needs fully met</span>
        </div>
    <?php } ?>

    <div class="panel-body">
        <form action="../app/evacuation-centers/save-center-needs.php" method="post">
            <?php echo csrf_field(); ?>
<input type="hidden" name="N_evac_center_id" value="<?php echo (int)$center['id']; ?>">
            <input type="hidden" name="N_profile_source" id="NProfileSource" value="manual">

            <?php if ($V_show_headcount_banner): ?>
                <div class="alert alert-warning py-2">
                    <strong>Reported headcounts:</strong> linked incident reports suggest
                    <strong><?php echo (int)$V_computed_headcount['total_evacuees']; ?></strong> total evacuees
                    (<?php echo (int)$V_computed_headcount['adults']; ?> adults + <?php echo (int)$V_computed_headcount['children']; ?> children),
                    <strong><?php echo (int)$V_computed_headcount['households']; ?></strong> families,
                    from <strong><?php echo (int)$V_computed_headcount['report_count']; ?></strong> credited report(s).
                    <?php if ($profile): ?>
                        Your current profile shows <?php echo (int)$profile['total_evacuees']; ?> evacuees /
                        <?php echo (int)$profile['families']; ?> families / <?php echo (int)$profile['children']; ?> children.
                        Please verify.
                    <?php else: ?>
                        No profile has been set for this center yet &mdash; the inputs below are pre-filled from the reports. Please verify and save.
                    <?php endif; ?>
                    <button type="button" class="btn btn-warning btn-sm ms-2" onclick="useReportedTotals()">Fill Reported Totals</button>
                </div>
            <?php endif; ?>

            <h5>Occupants</h5>
            <p class="text-muted">Update the vulnerable-sector counts below (DSWD Codes: A = older persons, B = lactating mothers, C = PWD).</p>
            <div class="row g-3 mb-2">
                <?php foreach ($V_profile_fields as $field_name => $field_label) {
                    $V_db_key = substr($field_name, 2); // strip the "N_" prefix -> DB column name
                    $V_field_value = (int)($profile[$V_db_key] ?? 0);
                    if (!$profile && isset($V_prefill_defaults[$V_db_key])) {
                        $V_field_value = $V_prefill_defaults[$V_db_key];
                    }
                ?>
                    <div class="col-md-3 col-6">
                        <label class="form-label"><?php echo h($field_label); ?></label>
                        <input type="number" name="<?php echo $field_name; ?>" class="form-control" min="0" value="<?php echo $V_field_value; ?>">
                    </div>
                <?php } ?>
            </div>

            <hr class="my-4">

            <h5>Needed Supplies</h5>
            <p class="text-muted">List the supplies needed. Fill in at least one line; each row is an item needing a quantity and unit.</p>

            <div id="needsRows">
                <?php if (count($needs) > 0) { ?>
<?php foreach ($needs as $i => $need) { ?>
                        <?php $V_edit_sf = $fulfillment[$need['id']] ?? ['received' => 0]; ?>
                        <?php $V_edit_fulfilled = ((int)$need['qty_needed'] > 0 && (int)$V_edit_sf['received'] >= (int)$need['qty_needed']); ?>
                        <div class="row g-2 mb-2 needs-row"<?php echo $V_edit_fulfilled ? ' style="background:rgba(25,135,84,0.08); border-radius:8px; padding:10px 12px;"' : ''; ?>>
                            <div class="col-md-6">
                                <input type="text" name="N_item[]" class="form-control" placeholder="Item (e.g. Food Packs)" value="<?php echo h($need['item']); ?>" required>
                                <?php if ($V_edit_fulfilled) { ?> <span class="soft-badge badge-soft-success">Fulfilled</span><?php } ?>
                            </div>
                            <div class="col-md-2">
                                <input type="number" name="N_qty[]" class="form-control" placeholder="Qty" min="1" value="<?php echo (int)$need['qty_needed']; ?>" required>
                            </div>
                            <div class="col-md-3">
                                <select name="N_unit[]" class="form-select">
                                    <?php foreach ($V_units as $unit) { ?>
                                        <option value="<?php echo h($unit); ?>" <?php echo ($need['unit'] == $unit) ? 'selected' : ''; ?>><?php echo h(ucfirst($unit)); ?></option>
                                    <?php } ?>
                                </select>
                            </div>
                            <div class="col-md-1">
                                <button type="button" class="btn btn-outline-danger" onclick="this.closest('.needs-row').remove()">&times;</button>
                            </div>
                        </div>
                    <?php } ?>
                <?php } else { ?>
                    <div class="row g-2 mb-2 needs-row">
                        <div class="col-md-6">
                            <input type="text" name="N_item[]" class="form-control" placeholder="Item (e.g. Food Packs)" required>
                        </div>
                        <div class="col-md-2">
                            <input type="number" name="N_qty[]" class="form-control" placeholder="Qty" min="1" required>
                        </div>
                        <div class="col-md-3">
                            <select name="N_unit[]" class="form-select">
                                <?php foreach ($V_units as $unit) { ?>
                                    <option value="<?php echo h($unit); ?>"><?php echo h(ucfirst($unit)); ?></option>
                                <?php } ?>
                            </select>
                        </div>
                        <div class="col-md-1">
                            <button type="button" class="btn btn-outline-danger" onclick="this.closest('.needs-row').remove()">&times;</button>
                        </div>
                    </div>
                <?php } ?>
            </div>

            <button type="button" class="btn btn-light border btn-sm" onclick="addNeedsRow()">+ Add another item</button>

            <div class="mt-4">
                <input type="submit" value="Save Needs &amp; Profile" class="btn btn-emergency">
<a href="evacuation-centers.php" class="btn btn-light border">Cancel</a>
            </div>
</form>
    </div>

    <script>
    // Copy the reported totals into the profile inputs and mark the save
    // as 'computed' (explicit human acceptance). Everything else still saves
    // as 'manual'. The values stay editable before submitting.
    function useReportedTotals() {
        var set = function(name, val) {
            var el = document.querySelector('input[name="' + name + '"]');
            if (el) el.value = val;
        };
        set('N_profile_source', 'computed');
        set('N_total_evacuees', <?php echo (int)$V_computed_headcount['total_evacuees']; ?>);
        set('N_families', <?php echo (int)$V_computed_headcount['households']; ?>);
        set('N_children', <?php echo (int)$V_computed_headcount['children']; ?>);
    }
    </script>

    <?php if (count($ledger) > 0): ?>
    <div class="panel-body pt-0">
        <h5 class="mb-2">Donations to this center</h5>
        <p class="text-muted">Who donated what, and the current status of each pledge. When a donation arrives, the barangay confirms receipt.</p>
        <div class="table-wrap">
            <table class="table">
                <thead>
                    <tr>
                        <th>Donor</th>
                        <th>Item</th>
                        <th>Qty</th>
                        <th>Status</th>
                        <th>Pledged</th>
                        <th>Sent</th>
                        <th>Delivered</th>
                        <th>Received</th>
                        <?php if ($V_role === 'barangay') { ?><th>Confirm</th><?php } ?>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($ledger as $d): ?>
                        <tr>
                            <td><strong><?php echo h($d['donor_label']); ?></strong><?php echo ($d['need_item'] ? ' <span class="text-muted">(for: ' . h($d['need_item']) . ')</span>' : ''); ?></td>
                            <td><?php echo h($d['item']); ?></td>
                            <td><?php echo (int)$d['qty'] . ' ' . h($d['unit']); ?><?php if (!empty($d['received_at']) && $d['qty_received'] !== null && (int)$d['qty_received'] !== (int)$d['qty']) { ?> <span class="text-muted">(<?php echo (int)$d['qty_received']; ?> received)</span><?php } ?></td>
                            <td>
                                <span class="soft-badge <?php echo $V_status_classes[$d['status']] ?? 'badge-soft-secondary'; ?>"><?php echo h($d['status']); ?></span><?php if (!empty($d['received_at'])) { ?> <span class="soft-badge badge-soft-success">Received</span><?php } ?><?php if (!empty($d['over_pledge_flag'])) { ?> <span class="soft-badge badge-soft-warning">Over-pledge</span><?php } ?>
                            </td>
                            <td><?php echo $d['pledged_at'] ? date('M d, Y h:i A', strtotime($d['pledged_at'])) : '&mdash;'; ?></td>
                            <td><?php echo $d['sent_at'] ? date('M d, Y h:i A', strtotime($d['sent_at'])) : '&mdash;'; ?></td>
                            <td><?php echo $d['delivered_at'] ? date('M d, Y h:i A', strtotime($d['delivered_at'])) : '&mdash;'; ?></td>
                            <td><?php echo $d['received_at'] ? date('M d, Y h:i A', strtotime($d['received_at'])) : '&mdash;'; ?></td>
                            <?php if ($V_role === 'barangay') { ?>
                                <td>
                                    <?php if ($d['status'] === 'Delivered' && empty($d['received_at'])) { ?>
                                        <form method="post" action="../app/evacuation-centers/confirm-assistance-received.php" class="d-inline" style="display:inline;" onsubmit="return confirm('Confirm the quantity received is correct?');">
                                            <?php echo csrf_field(); ?>
                                            <input type="hidden" name="assistance_id" value="<?php echo (int)$d['id']; ?>">
                                            <input type="hidden" name="center_id" value="<?php echo (int)$V_ID; ?>">
                                            <div class="input-group input-group-sm" style="width: 220px;">
                                                <input type="number" name="qty_received" class="form-control" min="1" max="<?php echo (int)$d['qty']; ?>" value="<?php echo (int)$d['qty']; ?>" required title="Quantity actually received (1 to <?php echo (int)$d['qty']; ?>)">
                                                <button type="submit" class="btn btn-outline-success">Confirm Received</button>
                                            </div>
                                        </form>
                                    <?php } else { ?><span class="text-muted">&mdash;</span><?php } ?>
                                </td>
                            <?php } ?>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
    <hr class="my-2">
    <?php endif; ?>

    <?php if (count($fulfillment) > 0): ?>
    <div class="panel-body pt-0">
        <h5 class="mb-2">Who's helping &mdash; status of pledges to this center</h5>
        <p class="text-muted">Read-only. Only supplies the barangay has confirmed <strong>Received</strong> reduce what's still needed.</p>
        <div class="table-wrap">
            <table class="table">
                <thead>
                    <tr>
                        <th>Item</th>
                        <th>Needed</th>
                        <th>Pledged</th>
                        <th>Sent</th>
                        <th>Delivered</th>
                        <th>Received</th>
                        <th>Helpers</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($needs as $need): ?>
                        <?php $sf = $fulfillment[$need['id']] ?? ['pledged'=>0,'sent'=>0,'delivered'=>0,'received'=>0,'helpers'=>'']; ?>
                        <?php $V_fh = ((int)$need['qty_needed'] > 0 && (int)$sf['received'] >= (int)$need['qty_needed']); ?>
                        <tr<?php echo $V_fh ? ' style="background:rgba(25,135,84,0.08);"' : ''; ?>>
                            <td><?php echo h($need['item']); ?><?php if ($V_fh) { ?> <span class="soft-badge badge-soft-success">Fulfilled</span><?php } ?></td>
                            <td><?php echo (int)$need['qty_needed']; ?></td>
                            <td><?php echo (int)$sf['pledged']; ?></td>
                            <td><?php echo (int)$sf['sent']; ?></td>
                            <td><?php echo (int)$sf['delivered']; ?></td>
                            <td><?php echo (int)$sf['received']; ?></td>
                            <td><?php echo $sf['helpers'] !== '' ? h($sf['helpers']) : '<span class="text-muted">No pledges yet</span>'; ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (isset($fulfillment['unlinked'])): ?>
                        <tr>
                            <td colspan="5" class="text-muted">Other pledges not tied to a specific item</td>
                            <td><?php echo h($fulfillment['unlinked']['helpers']); ?></td>
                        </tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
    <hr class="my-2">
    <?php endif; ?>
</div>

<script>
function addNeedsRow() {
    var row = document.createElement('div');
    row.className = 'row g-2 mb-2 needs-row';
    row.innerHTML = '' +
        '<div class="col-md-6"><input type="text" name="N_item[]" class="form-control" placeholder="Item (e.g. Food Packs)" required></div>' +
        '<div class="col-md-2"><input type="number" name="N_qty[]" class="form-control" placeholder="Qty" min="1" required></div>' +
        '<div class="col-md-3"><select name="N_unit[]" class="form-select">' +
        '<option value="packs">Packs</option><option value="sacks">Sacks</option><option value="boxes">Boxes</option>' +
        '<option value="liters">Liters</option><option value="pcs">Pcs</option><option value="kits">Kits</option>' +
        '</select></div>' +
        '<div class="col-md-1"><button type="button" class="btn btn-outline-danger" onclick="this.closest(\'.needs-row\').remove()">&times;</button></div>';
    document.getElementById('needsRows').appendChild(row);
}
</script>

<?php include "../app/includes/footer.php"; ?>
