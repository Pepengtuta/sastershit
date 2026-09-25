import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Green "Fulfilled" chip shown next to a need's item name once the
/// barangay-confirmed received quantity reaches the needed quantity.
///
/// Same badge style as the Over-pledge chip in PledgeLedgerRow (soft fill +
/// tinted border, bold small text) so it reads as an existing status chip
/// rather than a new pattern. Never shown for "Delivered but not yet
/// confirmed" supply, because fulfillment derives from `received_qty` only.
class FulfilledChip extends StatelessWidget {
  final String label;
  final double fontSize;

  const FulfilledChip({super.key, this.label = 'Fulfilled', this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, color: AppColors.successGreen, fontWeight: FontWeight.bold),
      ),
    );
  }
}