import 'package:flutter/material.dart';

import '../../widgets/dashboard_summary_view.dart';

class PcfDashboardScreen extends StatelessWidget {
  const PcfDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardSummaryView(
      role: 'pcf',
      title: 'Dashboard',
    );
  }
}
