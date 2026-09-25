import 'package:flutter/material.dart';

/// Philippine DRRM-style color palette for disaster types.
class DisasterTypeConfig {
  DisasterTypeConfig._();

  static const Map<String, Color> iconColors = {
    'Typhoon': Color(0xFF1565C0),
    'Flood': Color(0xFF0277BD),
    'Storm Surge': Color(0xFF00838F),
    'Earthquake': Color(0xFF795548),
    'Landslide': Color(0xFF6D4C41),
    'Fire': Color(0xFFD32F2F),
    'Drought / El Ni\u00f1o': Color(0xFFEF6C00),
    'Disease Outbreak': Color(0xFF7B1FA2),
    'Accident / Mass Casualty Incident': Color(0xFFAD1457),
    'Others': Color(0xFF616161),
  };

  static const Map<String, Color> backgroundColors = {
    'Typhoon': Color(0xFFE3F2FD),
    'Flood': Color(0xFFE1F5FE),
    'Storm Surge': Color(0xFFE0F7FA),
    'Earthquake': Color(0xFFEFEBE9),
    'Landslide': Color(0xFFEFEBE9),
    'Fire': Color(0xFFFFEBEE),
    'Drought / El Ni\u00f1o': Color(0xFFFFF3E0),
    'Disease Outbreak': Color(0xFFF3E5F5),
    'Accident / Mass Casualty Incident': Color(0xFFFCE4EC),
    'Others': Color(0xFFF5F5F5),
  };

  static const Map<String, Color> borderColors = {
    'Typhoon': Color(0xFF1565C0),
    'Flood': Color(0xFF0277BD),
    'Storm Surge': Color(0xFF00838F),
    'Earthquake': Color(0xFF5D4037),
    'Landslide': Color(0xFF4E342E),
    'Fire': Color(0xFFB71C1C),
    'Drought / El Ni\u00f1o': Color(0xFFE65100),
    'Disease Outbreak': Color(0xFF6A1B9A),
    'Accident / Mass Casualty Incident': Color(0xFF880E4F),
    'Others': Color(0xFF424242),
  };

  static Color getIconColor(String type) => iconColors[type] ?? const Color(0xFF616161);
  static Color getBgColor(String type) => backgroundColors[type] ?? const Color(0xFFF5F5F5);
  static Color getBorderColor(String type) => borderColors[type] ?? const Color(0xFF424242);
}
