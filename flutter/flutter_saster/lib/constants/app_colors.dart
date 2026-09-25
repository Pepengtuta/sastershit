import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryRed = Color(0xFFDC3545);
  static const Color darkRed = Color(0xFFC82333);
  // Soft light-red for secondary text on red banners (e.g. Create Incident header)
  static const Color lightRed = Color(0xFFFFE5E5);

  static const Color primaryBlue = Color(0xFF0D6EFD);
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color successGreen = Color(0xFF198754);
  static const Color primaryOrange = Color(0xFFFD7E14);
  // Primary care facilities (map pins)
  static const Color primaryPurple = Color(0xFF6F42C1);

  static const Color background = Color(0xFFF4F6F9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDEE2E6);

  static const Color textDark = Color(0xFF212529);
  static const Color textMuted = Color(0xFF6C757D);

  // Evacuation center status colors (single shared mapping for badges, chips,
// and dropdowns). Matches the soft-badge palette in the web CSS.
static Color evacuationCenterStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return successGreen;
      case 'available': return const Color(0xFF0DCAF0);
      case 'full': return warningYellow;
      case 'closed': return primaryRed;
      case 'needs supplies': return primaryOrange;
      default: return textMuted;
    }
  }

  // Web layout colors
  static const Color webSidebar = Color(0xFF2F3439);
  static const Color webDark = Color(0xFF343A40);
}

