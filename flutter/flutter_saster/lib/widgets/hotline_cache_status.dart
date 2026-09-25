import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shows a banner + last-updated line for the offline-capable hotlines screen.
///
/// - [showingSaved] true renders the "showing saved information" banner after
///   the API failed but the local cache is still being displayed.
/// - [lastUpdated] renders the last successful update time when known.
class HotlineCacheStatus extends StatelessWidget {
  const HotlineCacheStatus({
    super.key,
    this.showingSaved = false,
    this.lastUpdated,
  });

  final bool showingSaved;
  final DateTime? lastUpdated;

  static const String savedNotice =
      'Showing saved hotline information. Some details may have changed.';

  @override
  Widget build(BuildContext context) {
    if (!showingSaved && lastUpdated == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showingSaved) _buildBanner(),
          if (lastUpdated != null) ...[
            if (showingSaved) const SizedBox(height: 6),
            Text(
              'Last updated: ${formatUpdatedAt(lastUpdated!)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warningYellow),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warningYellow, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              savedNotice,
              style: TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a timestamp for display, e.g. "Mon, Sep 21, 2026 10:35 AM".
String formatUpdatedAt(DateTime value) {
  final local = value.toLocal();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '${weekdays[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}, '
      '${local.year} $hour:$minutes $ampm';
}
