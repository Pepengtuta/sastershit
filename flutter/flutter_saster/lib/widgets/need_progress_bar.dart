import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// At-a-glance fulfillment bar for one declared need:
/// "Received X / needed Y unit · unmet Z", with a red (unmet) or green
/// (fulfilled) LinearProgressIndicator. Shared by the MDR/higher-role
/// 'Needs & Assistance' board rows and the barangay Chairman/Secretary
/// Center Needs screen so both render the exact same bar.
///
/// Progress and unmet derive from barangay-confirmed received qty only
/// (`received_at` set), matching the server math everywhere else — Pledged/
/// Sent/Delivered-but-unconfirmed supply never reduces what's still needed.
class NeedProgressBar extends StatelessWidget {
  final int needed;
  final int received;
  final String unit;
  final int incoming;
  final bool fulfilled;

  const NeedProgressBar({
    super.key,
    required this.needed,
    required this.received,
    this.unit = '',
    this.incoming = 0,
    this.fulfilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unmet = needed - received < 0 ? 0 : needed - received;

    double progress = 0;
    if (needed > 0) {
      progress = (received / needed).clamp(0.0, 1.0);
      if (received > 0 && progress < 0.03) progress = 0.03;
    }

    final color = fulfilled ? AppColors.successGreen : AppColors.primaryRed;
    final unitText = unit.trim().isEmpty ? '' : ' $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Received $received / needed $needed$unitText  ·  unmet $unmet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: fulfilled ? AppColors.successGreen : AppColors.textDark,
            fontWeight: fulfilled ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (incoming > 0)
          Text(
            'Incoming (pledged): $incoming$unitText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warningYellow,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
