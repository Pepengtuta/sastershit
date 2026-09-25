import 'package:flutter/material.dart';

import '../../widgets/dashboard_summary_view.dart';

class PhoDashboardScreen extends StatelessWidget {
  const PhoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardSummaryView(
      role: 'pho',
      title: 'Dashboard',
      phoLabel: 'Provincial Cases',
    );
  }
}
