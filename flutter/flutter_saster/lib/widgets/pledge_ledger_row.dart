import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Distinct teal-green used for the barangay-confirmed "Received" badge/stage,
/// so it reads differently from the donor-side successGreen ("Delivered").
const Color _receivedColor = Color(0xFF0E7A5F);

String _fmtPledgeDate(dynamic raw) {
  if (raw == null ||
      raw.toString().trim().isEmpty ||
      raw.toString() == 'null') {
    return '—';
  }

  final cleaned = raw.toString().trim().replaceFirst(' ', 'T');
  final value = DateTime.tryParse(cleaned);
  if (value == null) return raw.toString();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour12 = value.hour == 0
      ? 12
      : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final ampm = value.hour >= 12 ? 'PM' : 'AM';

  return '${months[value.month - 1]} ${value.day}, ${value.year} • $hour12:$minute $ampm';
}

/// Read-only row for one assistance pledge/donation, shared by the assistance
/// board and the per-center needs ledger. Shows donor → qty/unit/item, a
/// wrapping stage-trail of timestamps (Pledged/Sent/Delivered + barangay-
/// confirmed Received), a shortfall "Received X of Y" badge on its own line
/// when fewer arrived than declared, and a wrapping status/action row (status,
/// Received, Over-pledge, Confirm Received) so nothing is ever clipped on
/// narrow phones. The status-management (⋯) menu only renders when an
/// onUpdateStatus callback is provided AND the API says the caller may manage
/// the status. A "Confirm Received" action renders when an onConfirmReceived
/// callback is provided and the row is a Delivered donation the barangay has
/// not yet confirmed.
class PledgeLedgerRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final Future<void> Function(int id, String action)? onUpdateStatus;
  final Future<void> Function(int id, int qty, String unit)? onConfirmReceived;

  const PledgeLedgerRow({
    super.key,
    required this.row,
    this.onUpdateStatus,
    this.onConfirmReceived,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Pledged':
        return AppColors.warningYellow;
      case 'Sent':
        return AppColors.primaryBlue;
      case 'Delivered':
        return AppColors.successGreen;
      default:
        return AppColors.textMuted;
    }
  }

  /// Builds the Pledged/Sent/Delivered/Received timestamp trail as a Wrap.
  /// Chips keep their natural width; when the trail is wider than the row,
  /// whole chips drop to a second line (spacing 6, runSpacing 4) instead of
  /// being clipped or hidden behind a swipe.
  Widget _stageTrail(ThemeData theme) {
    final stages =
        <Map<String, dynamic>>[
          {
            'label': 'Pledged',
            'date': row['pledged_at'],
            'color': AppColors.warningYellow,
          },
          {
            'label': 'Sent',
            'date': row['sent_at'],
            'color': AppColors.primaryBlue,
          },
          {
            'label': 'Delivered',
            'date': row['delivered_at'],
            'color': AppColors.successGreen,
          },
          {
            'label': 'Received',
            'date': row['received_at'],
            'color': _receivedColor,
          },
        ].where((s) {
          final v = s['date'];
          return v != null &&
              v.toString().trim().isNotEmpty &&
              v.toString() != 'null';
        }).toList();

    if (stages.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final stage in stages) _stageChip(theme, stage)],
    );
  }

  /// One "dot + label · date" chip (kept single-line; the parent Wrap reflows
  /// whole chips to new lines rather than squeezing their text).
  Widget _stageChip(ThemeData theme, Map<String, dynamic> s) {
    final color = s['color'] as Color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(
          '${s['label']} · ${_fmtPledgeDate(s['date'])}',
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  /// Small filled pill used for status / Received / Over-pledge / shortfall.
  /// isStatus keeps the softer (0.3) border used by the main status chip.
  Widget _chip(String text, Color chipColor, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: chipColor.withValues(alpha: isStatus ? 0.3 : 0.4),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: chipColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = row['status']?.toString() ?? '';
    final color = _statusColor(status);
    final canManage =
        onUpdateStatus != null && row['can_manage_status'] == true;
    final rawReceived = row['received_at'];
    final isReceived =
        rawReceived != null &&
        rawReceived.toString().trim().isNotEmpty &&
        rawReceived.toString() != 'null';
    final canConfirm =
        onConfirmReceived != null && status == 'Delivered' && !isReceived;
    final id = int.tryParse(row['id']?.toString() ?? '0') ?? 0;
    final overPledge =
        (row['over_pledge']?.toString() ?? '0') == '1' ||
        row['over_pledge'] == true;
    final unitLabel = ((row['unit']?.toString() ?? '').trim().isEmpty)
        ? ''
        : ' ${row['unit']}';
    final qty = int.tryParse(row['qty']?.toString() ?? '0') ?? 0;
    final rawQtyReceived = row['qty_received'];
    final qtyReceived = int.tryParse(rawQtyReceived?.toString() ?? '') ?? 0;
    final hasShortfall =
        isReceived &&
        rawQtyReceived != null &&
        qtyReceived > 0 &&
        qtyReceived < qty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${row['donor_label'] ?? ''} → ${row['qty']}$unitLabel ${row['item']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canManage && status != 'Delivered')
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (action) {
                    if (action == 'send') onUpdateStatus!(id, 'send');
                    if (action == 'deliver') onUpdateStatus!(id, 'deliver');
                  },
                  itemBuilder: (_) => [
                    if (status == 'Pledged')
                      const PopupMenuItem(
                        value: 'send',
                        child: Text('Mark Sent'),
                      ),
                    if (status == 'Pledged' || status == 'Sent')
                      const PopupMenuItem(
                        value: 'deliver',
                        child: Text('Mark Delivered'),
                      ),
                  ],
                ),
            ],
          ),
          if (row['for_item'] != null && (row['for_item'] as String).isNotEmpty)
            Text(
              'for: ${row['for_item']}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          if (row['remarks'] != null && (row['remarks'] as String).isNotEmpty)
            Text(
              '${row['remarks']}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          _stageTrail(theme),
          if (hasShortfall) ...[
            const SizedBox(height: 4),
            _chip('Received $qtyReceived of $qty', AppColors.warningYellow),
          ],
          if (status.isNotEmpty || isReceived || overPledge || canConfirm) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status.isNotEmpty) _chip(status, color, isStatus: true),
                if (isReceived) _chip('Received', _receivedColor),
                if (overPledge) _chip('Over-pledge', AppColors.warningYellow),
                if (canConfirm)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _receivedColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    onPressed: () =>
                        onConfirmReceived!(id, qty, unitLabel.trim()),
                    child: const Text(
                      'Confirm Received',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
