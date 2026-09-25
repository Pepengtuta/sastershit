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

class ReviewReportsScreen extends StatefulWidget {
  final int refreshToken;
  final VoidCallback onStatusChanged;

  /// Municipal uses this screen with operational action buttons enabled.
  /// Superadmin uses this same screen with actions disabled for monitoring only.
  final bool allowStatusActions;

  const ReviewReportsScreen({
    super.key,
    required this.refreshToken,
    required this.onStatusChanged,
    this.allowStatusActions = true,
  });

  @override
  State<ReviewReportsScreen> createState() => _ReviewReportsScreenState();
}

class _ReviewReportsScreenState extends State<ReviewReportsScreen> {
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
  void didUpdateWidget(covariant ReviewReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) loadReports();
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final role = widget.allowStatusActions ? 'pcf' : 'superadmin';
    final result = await ReportRepository.instance.getList(
      userId: AuthService.currentUserId ?? 0,
      role: role,
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

  Future<void> updateReport(Map<String, dynamic> report, String status, {bool forwardToPho = false}) async {
    final reportId = int.tryParse(report['id'].toString());
    final userId = AuthService.currentUserId;

    if (reportId == null || userId == null) return;

    final actor = AuthService.currentName ?? 'User';
    final role = (AuthService.currentRole ?? '').toUpperCase();
    final remarks = forwardToPho
        ? '$actor ($role) referred this report to Provincial from mobile app.'
        : '$actor ($role) changed this report status to $status from mobile app.';

    final result = await IncidentService.updateStatus(
      reportId: reportId,
      userId: userId,
      status: status,
      referredToPho: forwardToPho,
      remarks: remarks,
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

  String formatDateTime(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return '—';
    final value = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (value == null) return raw.toString();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    final minute = value.minute.toString().padLeft(2, '0');
    return '${months[value.month - 1]} ${value.day}, ${value.year} • $hour12:$minute $ampm';
  }

  void showReportDetails(Map<String, dynamic> report) {
    showReportDetailsSheet(context, report);
  }

  List<Widget> buildActions(Map<String, dynamic> report) {
    if (!widget.allowStatusActions) {
      return [
        AppButton(
          text: 'View Details',
          icon: Icons.visibility_outlined,
          fullWidth: false,
          backgroundColor: AppColors.primaryBlue,
          onPressed: () => showReportDetails(report),
        ),
      ];
    }

    final status = report['status']?.toString().toLowerCase() ?? '';

    if (status.contains('resolved') || status.contains('dismiss')) {
      return [
        AppButton(
          text: 'View Details',
          icon: Icons.visibility_outlined,
          fullWidth: false,
          backgroundColor: AppColors.primaryBlue,
          onPressed: () => showReportDetails(report),
        ),
      ];
    }

    // Mayor observers are read-only: they only view report details.
    if (AuthService.isReadOnlyObserver) {
      return [
        AppButton(
          text: 'View Details',
          icon: Icons.visibility_outlined,
          fullWidth: false,
          backgroundColor: AppColors.primaryBlue,
          onPressed: () => showReportDetails(report),
        ),
      ];
    }

    // MDR review gate: a freshly forwarded report has not been acknowledged
    // yet, so only "Start Review" (plus Details) is available until the
    // report moves to 'Under MDR Review'.
    if (status == 'forwarded to pcf') {
      return [
        const AwaitingReviewChip(label: 'Awaiting MDR Review'),
        AppButton(
          text: 'Acknowledge / Start Review',
          icon: Icons.playlist_add_check_outlined,
          fullWidth: false,
          backgroundColor: AppColors.primaryOrange,
          onPressed: () => updateReport(report, 'Under MDR Review'),
        ),
        AppButton(
          text: 'Details',
          icon: Icons.visibility_outlined,
          fullWidth: false,
          backgroundColor: AppColors.darkRed,
          onPressed: () => showReportDetails(report),
        ),
      ];
    }

    return [
      AppButton(text: 'Verify', fullWidth: false, backgroundColor: AppColors.successGreen, onPressed: () => updateReport(report, 'Verified')),
      AppButton(text: 'Respond', fullWidth: false, backgroundColor: AppColors.primaryBlue, onPressed: () => updateReport(report, 'Responding')),
      AppButton(text: 'Dismiss', fullWidth: false, backgroundColor: AppColors.textMuted, onPressed: () => updateReport(report, 'Dismissed')),
      AppButton(text: 'Refer Provincial', fullWidth: false, backgroundColor: AppColors.primaryRed, onPressed: () => updateReport(report, 'Referred to PHO', forwardToPho: true)),
      AppButton(text: 'Details', icon: Icons.visibility_outlined, fullWidth: false, backgroundColor: AppColors.darkRed, onPressed: () => showReportDetails(report)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingView();
    if (errorMessage != null) return ErrorState(message: errorMessage!, onRetry: loadReports);

    final filtered = filteredReports;

    // Mayor observers get the municipality-scoped evidence card as the first
    // list item (all non-dismissed barangay-level reports included), above
    // their unchanged operational list. Superadmin/MDR share this screen but
    // AuthService.isMayor is false for them, so no card appears.
    final List<Widget> listChildren = [
      if (AuthService.isMayor)
        EvidenceCard(
          scope: EvidenceScope.municipality,
          title: '${AuthService.effectiveMunicipality} Evidence',
          role: 'pcf',
          subRole: AuthService.currentSubRole ?? '',
          municipality: AuthService.effectiveMunicipality,
        ),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 140),
          child: EmptyState(
            icon: Icons.assignment_outlined,
            message: 'No incident reports found.',
          ),
        )
      else
        ...filtered.map((r) {
          final report = Map<String, dynamic>.from(r);
          return ReportCard(
            report: report,
            actions: buildActions(report),
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
          statusOptions: const ['All', 'Pending', 'Forwarded to PCF', 'Under MDR Review', 'Verified', 'Responding', 'Referred to PHO', 'Under PHO Review', 'Resolved', 'Dismissed'],
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

class DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const DetailLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
