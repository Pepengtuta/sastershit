import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _color() {
    final lower = status.toLowerCase();
    if (lower == 'open' ||
        lower == 'available' ||
        lower == 'full' ||
        lower == 'closed' ||
        lower == 'needs supplies') {
      return AppColors.evacuationCenterStatusColor(status);
    }
    if (lower.contains('pending')) return AppColors.warningYellow;
    if (lower.contains('review') || lower.contains('forward')) return AppColors.primaryBlue;
    if (lower.contains('verified')) return AppColors.successGreen;
    if (lower.contains('respond')) return AppColors.primaryBlue;
    if (lower.contains('refer')) return AppColors.primaryBlue;
    if (lower.contains('resolved')) return AppColors.successGreen;
    if (lower.contains('dismiss')) return AppColors.textMuted;
    if (lower.contains('monitor')) return AppColors.primaryRed;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
