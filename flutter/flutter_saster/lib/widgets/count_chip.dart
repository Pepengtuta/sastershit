import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CountChip extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;

  const CountChip({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.30)),
      label: Text(
        '$label: ${value ?? 0}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
