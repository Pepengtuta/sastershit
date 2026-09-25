import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Amber pill shown on MDR/PHO report cards while a report is at the
/// forwarded/referred stage and has not been acknowledged yet.
class AwaitingReviewChip extends StatelessWidget {
  final String label;

  const AwaitingReviewChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.warningYellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}