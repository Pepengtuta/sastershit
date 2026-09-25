import 'package:flutter/material.dart';

import '../../widgets/dashboard_summary_view.dart';

class SuperadminDashboardScreen extends StatelessWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardSummaryView(
      role: 'superadmin',
      title: 'Dashboard',
    );
  }
}
