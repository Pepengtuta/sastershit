import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/dashboard_summary_view.dart';

class BarangayDashboardScreen extends StatelessWidget {
  const BarangayDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardSummaryView(
      role: 'barangay',
      barangayId: AuthService.currentBarangayId,
      title: 'Dashboard',
      subRole: AuthService.currentSubRole ?? '',
      userId: AuthService.currentUserId,
    );
  }
}
