import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/incident_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/evidence_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/report_card.dart';
import '../../widgets/report_details_sheet.dart';

/// Read-only drill-down of the reports that feed an [EvidenceCard] aggregate (a
/// municipality / barangay / disaster-type chip), for the same month/year
/// window. Shows ALL non-dismissed statuses, scoped to the Governor
/// (province-wide) or a Mayor (own municipality). Both are pure observers here:
/// the only action is "View Details" — no Verify/Respond/Resolve/Dismiss.
class EvidenceReportsScreen extends StatefulWidget {
  final String title;
  final EvidenceScope scope;
  final String role;
  final String? municipality;
  final int? barangayId;
  final String? disasterType;
  final int month;
  final int year;

  const EvidenceReportsScreen({
    super.key,
    required this.title,
    required this.scope,
    required this.role,
    this.municipality,
    this.barangayId,
    this.disasterType,
    required this.month,
    required this.year,
  });

  @override
  State<EvidenceReportsScreen> createState() => _EvidenceReportsScreenState();
}

class _EvidenceReportsScreenState extends State<EvidenceReportsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final userId = AuthService.currentUserId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Signed-in account could not be identified.';
      });
      return;
    }

    final isProvince = widget.scope == EvidenceScope.province;
    final result = await IncidentService.getReports(
      role: widget.role,
      userId: userId,
      municipality: widget.municipality,
      barangayId: widget.barangayId,
      disasterType: widget.disasterType,
      month: widget.month,
      year: widget.year,
      governorScope: isProvince,
      mayorScope: !isProvince,
    );
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = ApiService.userMessage(result['message']?.toString() ?? 'Failed to load reports.');
      });
      return;
    }

    setState(() {
      _reports = List<dynamic>.from(result['data'] ?? []);
      _loading = false;
    });
  }

  String get _windowLabel {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final month = widget.month >= 1 && widget.month <= 12 ? widget.month : 1;
    return '${names[month - 1]} ${widget.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · $_windowLabel')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _reports.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_outlined,
                      message: 'No reports found for this selection.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primaryRed,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _reports.map((r) {
                          final report = Map<String, dynamic>.from(r);
                          return ReportCard(
                            report: report,
                            actions: [
                              AppButton(
                                text: 'View Details',
                                icon: Icons.visibility_outlined,
                                fullWidth: false,
                                backgroundColor: AppColors.darkRed,
                                onPressed: () => showReportDetailsSheet(context, report),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
}