import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/info_card.dart';

class ProfileScreen extends StatelessWidget {
  final Future<void> Function() onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodySmall?.color;
    final user = AuthService.currentUser ?? {};
    final rawName = user['name']?.toString() ?? 'User';
    final cleanName = rawName.replaceAll(RegExp(r'^(Barangay Chairman|Chairman|Barangay Captain|Captain|Barangay Tanod|Tanod|BHERT|Barangay Secretary|Secretary)\s+', caseSensitive: false), '');
    final role = user['role']?.toString();
    final subRole = user['sub_role']?.toString();
    late final String titleText;
    late final String subtitleText;
    String? chipLabel;

    if (role == 'pcf' && subRole == 'mdr_admin') {
      titleText = 'MDR Admin';
      subtitleText = 'MDR Admin';
    } else if (role == 'pcf' && subRole == 'mdr_kalibo') {
      titleText = 'MDRRMO KALIBO';
      subtitleText = 'MDRRMO';
    } else if (role == 'pcf' && subRole == 'mdr_ibajay') {
      titleText = 'MDRRMO IBAJAY';
      subtitleText = 'MDRRMO';
    } else if (role == 'pcf' && subRole == 'mayor_kalibo') {
      titleText = 'Mayor';
      subtitleText = 'Mayor';
    } else if (role == 'pcf' && subRole == 'mayor_ibajay') {
      titleText = 'Mayor';
      subtitleText = 'Mayor';
    } else if (role == 'pho' && (subRole == null || subRole.isEmpty)) {
      titleText = 'Provincial Admin';
      subtitleText = 'Provincial';
    } else if (role == 'pho' && subRole == 'pdrrmo') {
      titleText = 'PDRRMO';
      subtitleText = 'PDRRMO';
    } else if (role == 'pho' && subRole == 'governor') {
      titleText = 'Governor';
      subtitleText = 'Governor';
    } else if (role == 'superadmin') {
      titleText = 'Super Admin';
      subtitleText = 'Super Admin';
    } else if (subRole == 'captain') {
      chipLabel = 'Chairman';
      titleText = chipLabel;
      subtitleText = user['username']?.toString() ?? '';
    } else if (subRole == 'secretary') {
      chipLabel = 'Secretary';
      titleText = '$chipLabel: ${cleanName.toUpperCase()}';
      subtitleText = user['username']?.toString() ?? '';
    } else {
      chipLabel = 'BHERT';
      titleText = '$chipLabel: ${cleanName.toUpperCase()}';
      subtitleText = user['username']?.toString() ?? '';
    }
    final barangay = user['barangay_name']?.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoCard(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                child: Icon(Icons.person_outline, size: 40),
              ),
              const SizedBox(height: 14),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(subtitleText, style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor)),
              if (chipLabel != null) ...[
                const SizedBox(height: 8),
                Chip(label: Text(chipLabel), backgroundColor: AppColors.primaryRed.withValues(alpha: 0.12)),
              ],
              if (barangay != null && barangay.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('BRGY: $barangay', style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor)),
              ],
            ],
          ),
        ),
        InfoCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: AppColors.primaryRed),
            title: Text('Logout', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('Return to login screen', style: theme.textTheme.bodySmall?.copyWith(color: mutedColor)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await onLogout();
            },
          ),
        ),
      ],
    );
  }
}
