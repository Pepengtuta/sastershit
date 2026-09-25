import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'hotline_cache_status.dart' show formatUpdatedAt;

/// Shows a banner + last-updated line for the offline-capable Evacuation
/// Centers, Center Needs, and Needs & Assistance screens.
///
/// - [showingSaved] true renders the "showing saved data" banner after the API
///   failed but the local cache is still being displayed.
/// - [lastUpdated] renders the last successful update time when known.
///
/// Time-sensitive values (availability, headcount/capacity, remaining need
/// quantities, pledge statuses, delivered/received quantities) are saved data
/// while this banner is visible, so users are told the figures may have moved.
class OfflineCacheStatus extends StatelessWidget {
  const OfflineCacheStatus({
    super.key,
    this.showingSaved = false,
    this.lastUpdated,
    this.savedNotice = defaultSavedNotice,
  });

  final bool showingSaved;
  final DateTime? lastUpdated;
  final String savedNotice;

  /// Exact offline notice for evacuation and assistance data.
  static const String defaultSavedNotice =
      'Showing saved evacuation and assistance data. Quantities and statuses '
      'may have changed.';

  /// Label applied to individual time-sensitive values while [showingSaved].
  static const String savedDataTag = 'Saved data';

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
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.warningYellow,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              savedNotice,
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline tag marking a time-sensitive value (availability, capacity,
/// headcount, remaining need quantities, pledge statuses, received quantities)
/// as saved rather than live.
class SavedDataTag extends StatelessWidget {
  const SavedDataTag({super.key, this.fontSize = 10});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.warningYellow.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        OfflineCacheStatus.savedDataTag,
        style: TextStyle(
          fontSize: fontSize,
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
