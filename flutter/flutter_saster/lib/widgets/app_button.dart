import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.primaryRed,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? ElevatedButton(
            onPressed: onPressed,
            style: _style(),
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
            style: _style(),
          );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  ButtonStyle _style() {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
