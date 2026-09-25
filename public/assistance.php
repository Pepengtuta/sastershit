<?php
$V_page_title = "Needs & Assistance";
include "../app/auth/check_session.php";
include "../config/db_connection.php";
include "../app/includes/functions.php";

$V_role = $_SESSION['role'] ?? '';
$V_sub_role = $_SESSION['sub_role'] ?? '';

if (!can_view_assistance($V_role)) {
    header("Location: dashboard.php?denied=1");
    exit;
}

$V_can_pledge   = can_pledge_assistance($V_role, $V_sub_role);
$V_acting_user_id = (int)($_SESSION['user_id'] ?? 0);
$V_prov_override  = ($V_role === 'superadmin') || ($V_role === 'pho' && strtolower(trim((string)$V_sub_role)) !== 'governor');
$V_board_muni   = get_effective_municipality($V_role, $V_sub_role);
$V_muni_where   = '';
$V_muni_bind    = '';
if ($V_board_muni) {
    $V_muni_where = "AND ec.municipality = ?";
    $V_muni_bind = "s";
}

include "../app/includes/header.php";
include "../app/includes/sidebar.php";

// Zero-pledge centers: has a profile/needs but not even one pledge yet.
$zeroSql = "SELECT ec.id, ec.center_name, ec.barangay, ec.municipality, ec.status
            FROM evacuation_centers ec
            WHERE (EXISTS (SELECT 1 FROM evac_center_profile p WHERE p.evac_center_id = ec.id)
                OR EXISTS (SELECT 1 FROM evac_center_needs n WHERE n.evac_center_id = ec.id))
              AND NOT EXISTS (SELECT 1 FROM evac_assistance a WHERE a.evac_center_id = ec.id)
              AND ec.status IN ('" . implode("','", center_status_allowlist()) . "')
              $V_muni_where
            ORDER BY ec.municipality ASC, ec.barangay ASC, ec.center_name ASC";
$zeroStmt = mysqli_prepare($connection, $zeroSql);
$zeroCenters = [];
if ($zeroStmt) {
    if ($V_muni_bind) mysqli_stmt_bind_param($zeroStmt, $V_muni_bind, $V_board_muni);
    mysqli_stmt_execute($zeroStmt);
    $zeroResult = mysqli_stmt_get_result($zeroStmt);
    if ($zeroResult) {
        while ($zc = mysqli_fetch_assoc($zeroResult)) {
            $zeroCenters[] = $zc;
        }
        mysqli_free_result($zeroResult);
    } else {
        error_log("assistance: zero-pledge query failed: " . mysqli_error($connection));
    }
    mysqli_stmt_free_result($zeroStmt);
}

// Needs board with the fulfillment rule applied.
// Only barangay-confirmed ('Received' = received_at set) supply counts toward
// the need; 'Sent' is in transit, 'Delivered' is awaiting confirmation.
$needsSql = "SELECT ec.id AS center_id, ec.center_name, ec.barangay, ec.municipality, ec.status,
                    n.id AS need_id, n.item, n.unit, n.qty_needed,
                    COALESCE(r.received_qty, 0) AS received_qty,
                    COALESCE(p.pending_qty, 0) AS pending_qty,
                    COALESCE(i.incoming_qty, 0) AS incoming_qty
             FROM evac_center_needs n
             INNER JOIN evacuation_centers ec ON ec.id = n.evac_center_id
             LEFT JOIN (SELECT need_id, SUM(COALESCE(qty_received, qty)) AS received_qty FROM evac_assistance
                        WHERE received_at IS NOT NULL GROUP BY need_id) r ON r.need_id = n.id
             LEFT JOIN (SELECT need_id, SUM(qty) AS pending_qty FROM evac_assistance
                        WHERE status = 'Delivered' AND received_at IS NULL GROUP BY need_id) p ON p.need_id = n.id
             LEFT JOIN (SELECT need_id, SUM(qty) AS incoming_qty FROM evac_assistance
                        WHERE status IN ('Pledged','Sent') GROUP BY need_id) i ON i.need_id = n.id
             WHERE ec.status IN ('Open','Full','Needs Supplies','Available')
               $V_muni_where
             ORDER BY ec.municipality ASC, ec.barangay ASC, ec.center_name ASC, n.id ASC";
$needsStmt = mysqli_prepare($connection, $needsSql);
if ($needsStmt) {
    if ($V_muni_bind) mysqli_stmt_bind_param($needsStmt, $V_muni_bind, $V_board_muni);
    mysqli_stmt_execute($needsStmt);
    $needsResult = mysqli_stmt_get_result($needsStmt);
} else {
    $needsResult = false;
    error_log("assistance: needs query failed to prepare: " . mysqli_error($connection));
}
if (!$needsResult) {
    error_log("assistance: needs query failed: " . mysqli_error($connection));
}

// Group needs by center for the board display.
$V_board = [];
if ($needsResult) {
    while ($need = mysqli_fetch_assoc($needsResult)) {
        $cid = (int)$need['center_id'];
        if (!isset($V_board[$cid])) {
            $V_board[$cid] = [
                'id' => $cid, 'center_name' => $need['center_name'],
                'barangay' => $need['barangay'], 'municipality' => $need['municipality'],
                'status' => $need['status'], 'needs' => []
            ];
        }
        $V_board[$cid]['needs'][] = $need;
    }
    mysqli_free_result($needsResult);
    if ($needsStmt) mysqli_stmt_free_result($needsStmt);
}

// Attach the credited incident reference to each center on the board.
foreach ($V_board as $cid => $center_entry) {
    $V_inc = credited_incident_for_center($connection, $cid);
    if ($V_inc) {
        $V_inc['status_label'] = incident_status_label($V_inc['status'], $center_entry['municipality'] ?? '');
    }
    $V_board[$cid]['incident'] = $V_inc;
}

// Ledger: who donated what to where.
$ledgerSql = "SELECT a.*, ec.center_name, ec.barangay, ec.municipality, n.item AS need_item
              FROM evac_assistance a
              INNER JOIN evacuation_centers ec ON ec.id = a.evac_center_id
              LEFT JOIN evac_center_needs n ON n.id = a.need_id
              $V_muni_where
              ORDER BY a.created_at DESC, a.id DESC";
$ledgerStmt = mysqli_prepare($connection, $ledgerSql);
$ledgerRows = [];
if ($ledgerStmt) {
    if ($V_muni_bind) mysqli_stmt_bind_param($ledgerStmt, $V_muni_bind, $V_board_muni);
    mysqli_stmt_execute($ledgerStmt);
    $ledgerResult = mysqli_stmt_get_result($ledgerStmt);
    if ($ledgerResult) {
        while ($lr = mysqli_fetch_assoc($ledgerResult)) {
            $ledgerRows[] = $lr;
        }
        mysqli_free_result($ledgerResult);
    } else {
        error_log("assistance: ledger query failed: " . mysqli_error($connection));
    }
    mysqli_stmt_free_result($ledgerStmt);
}

$V_units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];
$V_status_classes = [
    'Pledged'   => 'badge-soft-secondary',
    'Sent'      => 'badge-soft-info',
    'Delivered' => 'badge-soft-success',
];
?>

<style>
.need-progress {
    display: flex;
    align-items: center;
    gap: 10px;
}
.need-track {
    flex: 1 1 auto;
    height: 10px;
    background: rgba(0,0,0,.06);
    border-radius: 999px;
    overflow: hidden;
}
.need-fill {
    height: 100%;
    border-radius: 999px;
    background: var(--primary, #DC3545);
}
.zero-pledge-banner {
    background: #FEF3C7;
    border: 1px solid #FDE68A;
    color: #92400E;
    border-radius: 10px;
    padding: 12px 16px;
    margin-bottom: 16px;
    font-size: 14px;
}
</style>

<?php if (count($zeroCenters) > 0): ?>
    <div class="zero-pledge-banner">
        <strong>No pledges yet:</strong>
        <?php
        $zero_names = [];
        foreach ($zeroCenters as $zc) {
            $zero_names[] = h($zc['center_name']) . ' (' . h($zc['barangay']) . ', ' . h($zc['municipality']) . ')';
        }
        echo implode(' · ', $zero_names);
        ?> — chairs have declared needs, please pledge/donate.
    </div>
<?php endif; ?>

<div class="panel-card">
    <div class="panel-header">
        <div>
            <h2>Needs &amp; Assistance</h2>
            <p>What each center needs, what is incoming (pledged), and what is already sent/delivered. Only delivered/sent supply fulfills a need.</p>
        </div>
        <?php if (!$V_can_pledge) { ?>
            <span class="soft-badge badge-soft-secondary">Read-only: you can view but not pledge</span>
        <?php } ?>
    </div>

    <?php if (isset($_GET['pledged'])) { ?><div class="alert alert-success py-2">Pledge recorded. Update its status once the supply is on its way or delivered.</div><?php } ?>
    <?php if (isset($_GET['updated'])) { ?><div class="alert alert-success py-2">Assistance status updated.</div><?php } ?>
    <?php if (isset($_GET['denied'])) { ?><div class="alert alert-danger py-2">Access denied for that action.</div><?php } ?>

    <div class="table-wrap">
        <?php if (count($V_board) > 0) { ?>
            <?php foreach ($V_board as $c) { ?>
                <?php
                $V_open_needs = 0;
                foreach ($c['needs'] as $V_bneed) {
                    if ((int)$V_bneed['qty_needed'] > 0 && (int)$V_bneed['received_qty'] < (int)$V_bneed['qty_needed']) $V_open_needs++;
                }
                $V_has_needs = count($c['needs']) > 0;
                ?>
                <div class="mb-4">
                    <div class="mb-1">
                        <strong><?php echo h($c['center_name']); ?></strong>
                        <span class="text-muted"> &middot; <?php echo h($c['barangay']); ?>, <?php echo h($c['municipality']); ?></span>
                        <span class="soft-badge <?php echo h(center_status_badge_class($c['status'])); ?>"><?php echo h($c['status']); ?></span>
                        <?php if ($V_has_needs && $V_open_needs === 0): ?>
                            <span class="soft-badge badge-soft-success">Fully Supplied</span>
                        <?php elseif ($V_open_needs > 0): ?>
                            <span class="soft-badge badge-soft-warning"><?php echo $V_open_needs === 1 ? '1 Need Open' : "$V_open_needs Needs Open"; ?></span>
                        <?php endif; ?>
                        <?php if (!empty($c['incident'])): ?>
                            <span class="soft-badge badge-soft-primary" title="Linked incident report">
                                <?php echo h($c['incident']['disaster_type']); ?> &middot; <?php echo h($c['incident']['status_label'] ?? $c['incident']['status']); ?>
                            </span>
                        <?php else: ?>
                            <span class="soft-badge badge-soft-warning">Unverified &mdash; no linked incident</span>
                        <?php endif; ?>
                    </div>
                    <table class="table table-bordered custom-table mb-0">
                        <thead>
                            <tr>
                                <th>Item</th>
                                <th>Unit</th>
                                <th>Needed</th>
                                <th style="width: 30%;">Received</th>
                                <th>Incoming / Awaiting Confirmation</th>
                                <th>Still Needed</th>
                                <?php if ($V_can_pledge) { ?><th style="width: 90px;">Action</th><?php } ?>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($c['needs'] as $need) { ?>
                                <?php
                                $qty_needed   = (int)$need['qty_needed'];
                                $received_qty = (int)$need['received_qty'];
                                $pending_qty  = (int)$need['pending_qty'];
                                $incoming_qty = (int)$need['incoming_qty'];
                                $unmet       = max(0, $qty_needed - $received_qty);
                                $remaining_committed = max(0, $qty_needed - $received_qty - $incoming_qty);
                                $pct         = ($qty_needed > 0) ? min(100, round(($received_qty / $qty_needed) * 100)) : 0;
                                // Only barangay-confirmed ('Received') supply fulfills a need.
                                $fulfilled   = ($qty_needed > 0 && $received_qty >= $qty_needed);
                                ?>
                                <tr<?php echo $fulfilled ? ' style="background:rgba(25,135,84,0.08);"' : ''; ?>>
                                    <td>
                                        <strong><?php echo h($need['item']); ?></strong>
                                        <?php if ($fulfilled) { ?> <span class="soft-badge badge-soft-success">Fulfilled</span><?php } ?>
                                    </td>
                                    <td><?php echo h($need['unit']); ?></td>
                                    <td><?php echo $qty_needed; ?></td>
                                    <td>
                                        <?php if ($qty_needed > 0) { ?>
                                            <div class="need-progress">
                                                <div class="need-track">
                                                    <div class="need-fill" style="width: <?php echo $pct; ?>%; <?php echo $fulfilled ? 'background:#198754;' : ''; ?>"></div>
                                                </div>
                                                <span><?php echo $received_qty; ?>/<?php echo $qty_needed; ?></span>
                                            </div>
                                        <?php } else { ?><?php echo $received_qty; ?><?php } ?>
                                    </td>
                                    <td>
                                        <?php if ($incoming_qty > 0) { ?><span class="soft-badge badge-soft-secondary"><?php echo $incoming_qty; ?> incoming</span><?php } ?>
                                        <?php if ($pending_qty > 0) { ?><span class="soft-badge badge-soft-warning"><?php echo $pending_qty; ?> awaiting confirmation</span><?php } ?>
                                        <?php if ($incoming_qty === 0 && $pending_qty === 0) { ?>&mdash;<?php } ?>
                                    </td>
                                    <td>
                                        <?php if ($fulfilled) { ?>
                                            <span class="soft-badge badge-soft-success">Fulfilled</span>
                                        <?php } else { ?>
                                            <strong><?php echo $unmet; ?></strong>
                                        <?php } ?>
                                    </td>
                                    <?php if ($V_can_pledge) { ?>
                                        <td>
                                            <button class="btn btn-sm btn-emergency" data-bs-toggle="modal" data-bs-target="#pledgeModal"
                                                    data-center="<?php echo (int)$c['id']; ?>"
                                                    data-item="<?php echo h($need['item']); ?>"
                                                    data-unit="<?php echo h($need['unit']); ?>"
                                                    data-need="<?php echo (int)$need['need_id']; ?>"
                                                    data-remaining="<?php echo $remaining_committed; ?>">Pledge</button>
                                        </td>
                                    <?php } ?>
                                </tr>
                            <?php } ?>
                            <!-- A center may receive /upside/ pledges beyond its declared needs list. -->
                            <tr>
                                <td colspan="<?php echo $V_can_pledge ? 7 : 6; ?>" class="text-center">
                                    <?php
                                    $V_center_count = 0;
                                    foreach ($ledgerRows as $V_ld) {
                                        if ((int)$V_ld['evac_center_id'] === (int)$c['id']) $V_center_count++;
                                    }
                                    ?>
                                    <a class="small text-decoration-none" data-bs-toggle="collapse" href="#ledger<?php echo (int)$c['id']; ?>" role="button">
                                        Who donated what to where (<?php echo $V_center_count; ?> donation(s)) &triangleright;
                                    </a>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                    <div id="ledger<?php echo (int)$c['id']; ?>" class="collapse">
                        <div class="table-wrap" style="margin-top:4px;">
                            <table class="table table-sm table-bordered custom-table">
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
                                        <?php if ($V_can_pledge) { ?><th style="width:180px;">Update</th><?php } ?>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php
                                    $V_center_ledger_shown = false;
                                    foreach ($ledgerRows as $donation) {
                                        if ((int)$donation['evac_center_id'] !== (int)$c['id']) continue;
                                        $V_center_ledger_shown = true;
                                        $V_can_update_row = $V_prov_override || (int)$donation['donor_user_id'] === $V_acting_user_id;
                                        ?>
                                        <tr>
                                            <td><strong><?php echo h($donation['donor_label']); ?></strong></td>
                                            <td><?php echo h($donation['item']); ?><?php echo $donation['need_item'] ? ' <span class="text-muted">(for: ' . h($donation['need_item']) . ')</span>' : ''; ?></td>
                                            <td><?php echo (int)$donation['qty'] . ' ' . h($donation['unit']); ?><?php if (!empty($donation['received_at']) && $donation['qty_received'] !== null && (int)$donation['qty_received'] !== (int)$donation['qty']) { ?> <span class="text-muted">(<?php echo (int)$donation['qty_received']; ?> received)</span><?php } ?></td>
                                            <td><span class="soft-badge <?php echo $V_status_classes[$donation['status']] ?? 'badge-soft-secondary'; ?>"><?php echo h($donation['status']); ?></span><?php if (!empty($donation['received_at'])) { ?> <span class="soft-badge badge-soft-success">Received</span><?php } ?><?php if (!empty($donation['over_pledge_flag'])) { ?> <span class="soft-badge badge-soft-warning">Over-pledge</span><?php } ?></td>
                                            <td><?php echo $donation['pledged_at'] ? date('M d, Y h:i A', strtotime($donation['pledged_at'])) : '&mdash;'; ?></td>
                                            <td><?php echo $donation['sent_at'] ? date('M d, Y h:i A', strtotime($donation['sent_at'])) : '&mdash;'; ?></td>
                                            <td><?php echo $donation['delivered_at'] ? date('M d, Y h:i A', strtotime($donation['delivered_at'])) : '&mdash;'; ?></td>
                                            <td><?php echo $donation['received_at'] ? date('M d, Y h:i A', strtotime($donation['received_at'])) : '&mdash;'; ?></td>
                                            <?php if ($V_can_pledge && $V_can_update_row) { ?>
                                                <td class="text-nowrap">
                                                    <?php if ($donation['status'] === 'Pledged') { ?>
                                                        <form method="post" action="../app/evacuation-centers/update-assistance-status.php" class="d-inline" style="display:inline;">
                                                            <?php echo csrf_field(); ?>
                                                            <input type="hidden" name="assistance_id" value="<?php echo (int)$donation['id']; ?>">
                                                            <input type="hidden" name="action" value="send">
                                                            <button type="submit" class="btn btn-sm btn-outline-info">Mark Sent</button>
                                                        </form>
                                                    <?php } ?>
                                                    <?php if ($donation['status'] === 'Pledged' || $donation['status'] === 'Sent') { ?>
                                                        <form method="post" action="../app/evacuation-centers/update-assistance-status.php" class="d-inline" style="display:inline;">
                                                            <?php echo csrf_field(); ?>
                                                            <input type="hidden" name="assistance_id" value="<?php echo (int)$donation['id']; ?>">
                                                            <input type="hidden" name="action" value="deliver">
                                                            <button type="submit" class="btn btn-sm btn-outline-success">Deliver</button>
                                                        </form>
                                                    <?php } ?>
                                                </td>
                                            <?php } elseif ($V_can_pledge) { ?>
                                                <td class="text-nowrap"><span class="text-muted">&mdash;</span></td>
                                            <?php } ?>
                                        </tr>
                                        <?php
                                    }
                                    ?>
                                    <?php if (!$V_center_ledger_shown) { ?>
                                        <tr><td colspan="<?php echo $V_can_pledge ? 9 : 8; ?>" class="empty-state">No donations recorded yet.</td></tr>
                                    <?php } ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            <?php } ?>
        <?php } else { ?>
            <div class="empty-state">No declared center needs. Chairman/secretary should list needs on each evacuation center first.</div>
        <?php } ?>
    </div>
</div>

<?php if ($V_can_pledge): ?>
<!-- Pledge modal -->
<div class="modal fade" id="pledgeModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <form class="modal-content" method="post" action="../app/evacuation-centers/pledge-assistance.php">
            <?php echo csrf_field(); ?>
            <div class="modal-header">
                <h5 class="modal-title">Pledge Assistance</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" name="evac_center_id" id="pledgeCenterId">
                <input type="hidden" name="need_id" id="pledgeNeedId">
                <div class="mb-3">
                    <label class="form-label">Center</label>
                    <input type="text" class="form-control" id="pledgeCenterName" disabled>
                </div>
                <div class="mb-3">
                    <label class="form-label">Item *</label>
                    <input type="text" name="item" id="pledgeItem" class="form-control" required>
                </div>
                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label">Quantity *</label>
                        <input type="number" name="qty" class="form-control" min="1" required>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">Unit</label>
                        <select name="unit" class="form-select" id="pledgeUnit">
                            <?php foreach ($V_units as $unit) { ?>
                                <option value="<?php echo h($unit); ?>"><?php echo h(ucfirst($unit)); ?></option>
                            <?php } ?>
                        </select>
                    </div>
                </div>
                <div class="mb-3 mt-3">
                    <label class="form-label">Remarks</label>
                    <input type="text" name="remarks" class="form-control" placeholder="e.g. Delivery scheduled tomorrow">
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" class="btn btn-emergency">Record Pledge</button>
            </div>
        </form>
    </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function () {
    var modal = document.getElementById('pledgeModal');
    var pledgeNeedId = 0;
    var pledgeItem = '';
    var pledgeUnit = 'pcs';
    var pledgeRemaining = 0;

    modal.addEventListener('show.bs.modal', function (event) {
        var btn = event.relatedTarget;
        if (!btn) return;
        var centerId  = btn.getAttribute('data-center');
        var item      = btn.getAttribute('data-item');
        var unit      = btn.getAttribute('data-unit');
        var needId    = btn.getAttribute('data-need');
        document.getElementById('pledgeCenterId').value = centerId;
        document.getElementById('pledgeCenterName').value = btn.closest('div.mb-4').querySelector('strong').textContent.trim();
        document.getElementById('pledgeItem').value = item;
        document.getElementById('pledgeNeedId').value = needId;
        var unitSel = document.getElementById('pledgeUnit');
        unitSel.value = unit || 'pcs';
        pledgeNeedId = parseInt(needId || 0, 10) || 0;
        pledgeItem = item || '';
        pledgeUnit = unitSel.value || 'pcs';
        pledgeRemaining = parseInt(btn.getAttribute('data-remaining') || 0, 10) || 0;
    });

    // Soft over-pledge warning (warn but don't block), mirroring the server-side
    // committed-supply check. Cancel aborts the submit; Continue records anyway.
    modal.addEventListener('submit', function (event) {
        var qtyInput = modal.querySelector('input[name="qty"]');
        var qty = parseInt(qtyInput ? qtyInput.value : 0, 10) || 0;
        if (pledgeNeedId < 1 || qty <= pledgeRemaining) {
            return;
        }
        var excess = qty - pledgeRemaining;
        var message = 'Only ' + pledgeRemaining + ' ' + pledgeUnit + ' still needed for '
            + pledgeItem + ' \u2014 you\u2019re pledging ' + qty + ' ('
            + excess + ' more than needed). Continue anyway?';
        if (!window.confirm(message)) {
            event.preventDefault();
            event.stopPropagation();
        }
    });
});
</script>
<?php endif; ?>

<?php include "../app/includes/footer.php"; ?>