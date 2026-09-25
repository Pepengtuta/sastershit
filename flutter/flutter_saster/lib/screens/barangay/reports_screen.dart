import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/incident_service.dart';
import '../../services/report_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/offline_cache_status.dart';
import '../../widgets/report_card.dart';
import '../../widgets/report_details_sheet.dart';
import '../../widgets/report_filter_bar.dart';
import 'edit_incident_screen.dart';

class ReportsScreen extends StatefulWidget {
  final int refreshToken;

  const ReportsScreen({super.key, required this.refreshToken});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      loadReports();
    }
  }

  Future<void> loadReports() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final isBhert = AuthService.isTanod;
    final result = await ReportRepository.instance.getList(
      userId: AuthService.currentUserId ?? 0,
      role: 'barangay',
      barangayId: AuthService.currentBarangayId,
      subRole: AuthService.currentSubRole ?? '',
      forUserId: isBhert ? AuthService.currentUserId : null,
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

  Future<void> openEditReport(Map<String, dynamic> report) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditIncidentScreen(report: report)),
    );
    if (result == true && mounted) {
      loadReports();
    }
  }

  Future<void> changeReportStatus(Map<String, dynamic> report, String newStatus, String remarks) async {
    final reportId = int.tryParse(report['id']?.toString() ?? '') ?? 0;
    final userId = AuthService.currentUserId ?? 0;
    if (reportId <= 0 || userId <= 0) return;

    final result = await IncidentService.updateStatus(
      reportId: reportId,
      userId: userId,
      status: newStatus,
      remarks: remarks,
    );

    if (mounted && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: AppColors.successGreen),
      );
      loadReports();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed to update status.'), backgroundColor: AppColors.primaryRed),
      );
    }
  }

  void showChairmanActions(Map<String, dynamic> report) {
    final status = report['status']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Update Report Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (status == 'Pending') ...[
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.primaryBlue),
                title: const Text('Review'),
                subtitle: const Text('Mark as reviewed by Chairman'),
                onTap: () { Navigator.pop(ctx); changeReportStatus(report, 'Reviewed', 'Report reviewed by Chairman.'); },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.primaryRed),
                title: const Text('Dismiss', style: TextStyle(color: AppColors.primaryRed)),
                subtitle: const Text('Dismiss this report'),
                onTap: () { Navigator.pop(ctx); changeReportStatus(report, 'Dismissed', 'Report dismissed by Chairman.'); },
              ),
            ],
            if (status == 'Reviewed') ...[
              ListTile(
                leading: const Icon(Icons.send_outlined, color: AppColors.primaryBlue),
                title: const Text('Forward to Municipal'),
                subtitle: const Text('Send to Municipal'),
                onTap: () { Navigator.pop(ctx); changeReportStatus(report, 'Forwarded to PCF', 'Report forwarded to Municipal for coordination.'); },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.primaryRed),
                title: const Text('Dismiss', style: TextStyle(color: AppColors.primaryRed)),
                subtitle: const Text('Dismiss this report'),
                onTap: () { Navigator.pop(ctx); changeReportStatus(report, 'Dismissed', 'Report dismissed by Chairman.'); },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingView();
    }

    if (errorMessage != null) {
      return ErrorState(message: errorMessage!, onRetry: loadReports);
    }

    final filtered = filteredReports;

    return Column(
      children: [
        ReportFilterBar(
          searchQuery: searchQuery,
          statusFilter: statusFilter,
          typeFilter: typeFilter,
          dateFilter: dateFilter,
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
            child: filtered.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        icon: Icons.assignment_outlined,
                        message: 'No incident reports found.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 90,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final report = Map<String, dynamic>.from(filtered[index]);
                      final status = report['status']?.toString() ?? '';
                      final isCaptain = AuthService.isCaptain;
                      final isOwner = report['user_id']?.toString() == (AuthService.currentUserId?.toString() ?? '');
                      final canEdit = AuthService.currentRole == 'barangay' && (isCaptain || isOwner) && status == 'Pending';
                      final canUpdateStatus = isCaptain && (status == 'Pending' || status == 'Reviewed');
                      return ReportCard(
                        report: report,
                        actions: [
                          if (canEdit)
                            AppButton(
                              text: 'Edit',
                              icon: Icons.edit_outlined,
                              fullWidth: false,
                              backgroundColor: AppColors.primaryRed,
                              onPressed: () => openEditReport(report),
                            ),
                          if (canUpdateStatus)
                            AppButton(
                              text: 'Update Status',
                              icon: Icons.edit_note_outlined,
                              fullWidth: false,
                              backgroundColor: AppColors.primaryBlue,
                              onPressed: () => showChairmanActions(report),
                            ),
                          AppButton(
                            text: 'View Details',
                            icon: Icons.visibility_outlined,
                            fullWidth: false,
                            backgroundColor: AppColors.primaryBlue,
                            onPressed: () => showReportDetailsSheet(context, report),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
