import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/incident_service.dart';
import '../../services/report_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/awaiting_review_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/evidence_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/offline_cache_status.dart';
import '../../widgets/report_card.dart';
import '../../widgets/report_details_sheet.dart';
import '../../widgets/report_filter_bar.dart';

class HealthReportsScreen extends StatefulWidget {
  final int refreshToken;
  final VoidCallback onStatusChanged;

  const HealthReportsScreen({super.key, required this.refreshToken, required this.onStatusChanged});

  @override
  State<HealthReportsScreen> createState() => _HealthReportsScreenState();
}

class _HealthReportsScreenState extends State<HealthReportsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> reports = [];
  bool _showingSaved = false;
  DateTime? _lastUpdated;

  String searchQuery = '';
  String statusFilter = 'All';
  String typeFilter = 'All';
  String dateFilter = 'All Time';

  List<dynamic> get filteredReports {
    return reports.where((r) {
      final query = searchQuery.toLowerCase();
      final desc = r['description']?.toString().toLowerCase() ?? '';
      final brgy = r['barangay_name']?.toString().toLowerCase() ?? '';
      final matchesQuery = query.isEmpty || desc.contains(query) || brgy.contains(query);

      final status = r['status']?.toString() ?? '';
      final matchesStatus = statusFilter == 'All' || status.toLowerCase() == statusFilter.toLowerCase();

      final type = r['disaster_type']?.toString() ?? '';
      final matchesType = typeFilter == 'All' || type.toLowerCase() == typeFilter.toLowerCase();

      bool matchesDate = true;
      if (dateFilter != 'All Time') {
        final dateStr = r['created_at']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr.replaceFirst(' ', 'T'));
        if (date != null) {
          final now = DateTime.now();
          final difference = now.difference(date).inDays;
          if (dateFilter == 'Today') {
            matchesDate = difference == 0 && now.day == date.day;
          } else if (dateFilter == 'Last 7 Days') {
            matchesDate = difference <= 7;
          } else if (dateFilter == 'Last 30 Days') {
            matchesDate = difference <= 30;
          }
        }
      }

      return matchesQuery && matchesStatus && matchesType && matchesDate;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  @override
  void didUpdateWidget(covariant HealthReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) loadReports();
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await ReportRepository.instance.getList(
      userId: AuthService.currentUserId ?? 0,
      role: 'pho',
      municipality: AuthService.effectiveMunicipality,
      subRole: AuthService.currentSubRole ?? '',
    );
    if (!mounted) return;

    if (result.offline && !result.hasCache) {
      setState(() {
        isLoading = false;
        errorMessage = ApiService.userMessage(result.message ?? 'Failed to load reports.');
        _showingSaved = false;
        _lastUpdated = null;
      });
      return;
    }

    setState(() {
      reports = result.reports;
      isLoading = false;
      errorMessage = null;
      _showingSaved = result.offline;
      _lastUpdated = result.lastUpdated;
    });
  }

  Future<void> updateReport(Map<String, dynamic> report, String status) async {
    final reportId = int.tryParse(report['id'].toString());
    final userId = AuthService.currentUserId;
    if (reportId == null || userId == null) return;

    final result = await IncidentService.updateStatus(
      reportId: reportId,
      userId: userId,
      status: status,
      remarks: status == 'Resolved'
          ? 'Health report resolved from mobile app.'
          : (status == 'Under PHO Review'
              ? 'Provincial acknowledged this referred report from mobile app.'
              : 'Provincial is responding from mobile app.'),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Status updated.'),
        backgroundColor: result['success'] == true ? AppColors.successGreen : AppColors.primaryRed,
      ),
    );

    if (result['success'] == true) {
      await loadReports();
      widget.onStatusChanged();
    }
  }

  List<Widget> _buildActions(Map<String, dynamic> report) {
    final status = report['status']?.toString().toLowerCase() ?? '';
    return [
      AppButton(
        text: 'View Details',
        icon: Icons.visibility_outlined,
        fullWidth: false,
        backgroundColor: AppColors.darkRed,
        onPressed: () => showReportDetailsSheet(context, report),
      ),
      if (!AuthService.isReadOnlyObserver) ...[
        // PHO review gate: a freshly referred report must be acknowledged
        // ('Under PHO Review') before Respond / Resolve appear.
        if (status == 'referred to pho' || status == 'forwarded to pho') ...[
          const AwaitingReviewChip(label: 'Awaiting PDR Review'),
          AppButton(
            text: 'Acknowledge / Start Review',
            icon: Icons.playlist_add_check_outlined,
            fullWidth: false,
            backgroundColor: AppColors.primaryOrange,
            onPressed: () => updateReport(report, 'Under PHO Review'),
          ),
        ] else ...[
          AppButton(text: 'Respond', fullWidth: false, backgroundColor: AppColors.primaryBlue, onPressed: () => updateReport(report, 'Responding')),
          AppButton(text: 'Resolve', fullWidth: false, backgroundColor: AppColors.successGreen, onPressed: () => updateReport(report, 'Resolved')),
        ],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingView();
    if (errorMessage != null) return ErrorState(message: errorMessage!, onRetry: loadReports);

    final filtered = filteredReports;

    final List<Widget> listChildren = [
      if (AuthService.isGovernor)
        const EvidenceCard(
          scope: EvidenceScope.province,
          title: 'Province-Wide Evidence',
          role: 'pho',
          subRole: 'governor',
        ),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 120),
          child: EmptyState(
            icon: Icons.health_and_safety_outlined,
            message: 'No incident reports found.',
          ),
        )
      else
        ...filtered.map((r) {
          final report = Map<String, dynamic>.from(r);
          return ReportCard(
            report: report,
            actions: _buildActions(report),
          );
        }),
    ];

    return Column(
      children: [
        ReportFilterBar(
          searchQuery: searchQuery,
          statusFilter: statusFilter,
          typeFilter: typeFilter,
          dateFilter: dateFilter,
          statusOptions: const ['All', 'Pending', 'Verified', 'Responding', 'Under PHO Review', 'Referred to PHO', 'Resolved', 'Dismissed'],
          onSearchChanged: (val) => setState(() => searchQuery = val),
          onStatusChanged: (val) => setState(() => statusFilter = val ?? 'All'),
          onTypeChanged: (val) => setState(() => typeFilter = val ?? 'All'),
          onDateChanged: (val) => setState(() => dateFilter = val ?? 'All Time'),
        ),
        if (_showingSaved || _lastUpdated != null)
          OfflineCacheStatus(
            showingSaved: _showingSaved,
            lastUpdated: _lastUpdated,
            savedNotice:
                'Showing saved incident reports. This list may not reflect the latest changes.',
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: loadReports,
            color: AppColors.primaryRed,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: listChildren,
            ),
          ),
        ),
      ],
    );
  }
}
