import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/offline_report_sync.dart';
import '../../services/report_queue_repository.dart';
import '../../widgets/empty_state.dart';

/// Shows the reports queued on this device for offline submission, with their
/// local status (waiting to send / sending / sent / failed).
class SavedReportsScreen extends StatefulWidget {
  const SavedReportsScreen({super.key});

  @override
  State<SavedReportsScreen> createState() => _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  List<QueuedReport> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    OfflineReportSync.instance.changes.listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    final records = await ReportQueueRepository.instance.getForUser(userId);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  /// Pull-to-refresh action: force a sync now, then reload the list.
  Future<void> _syncAndReload() async {
    await OfflineReportSync.instance.syncForCurrentUser();
    if (!mounted) return;
    await _load();
  }

  Future<void> _retry(QueuedReport record) async {
    await OfflineReportSync.instance.retryRecord(record.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrying...'),
        backgroundColor: AppColors.warningYellow,
      ),
    );
  }

  (IconData, Color, String) _statusInfo(String status) {
    switch (status) {
      case ReportQueueStatus.sending:
        return (Icons.sync_outlined, AppColors.primaryBlue, 'Sending');
      case ReportQueueStatus.sent:
        return (Icons.check_circle_outline, AppColors.successGreen, 'Sent');
      case ReportQueueStatus.failed:
        return (Icons.error_outline, AppColors.primaryRed, 'Failed');
      default:
        return (Icons.schedule_outlined, AppColors.warningYellow, 'Waiting to send');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reports'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: () => OfflineReportSync.instance.syncForCurrentUser(),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
            : _records.isEmpty
                ? const EmptyState(
                    icon: Icons.outbox_outlined,
                    message: 'No saved reports on this device.',
                  )
                : RefreshIndicator(
                    onRefresh: _syncAndReload,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) =>
                          _buildCard(_records[index]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildCard(QueuedReport record) {
    final (icon, color, label) = _statusInfo(record.status);
    final disasterType = record.payload['disaster_type']?.toString() ?? 'Report';
    final description = record.payload['description']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    disasterType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
            if (record.mediaFiles.isNotEmpty &&
                record.status != ReportQueueStatus.sent) ...[
              const SizedBox(height: 6),
              Text(
                '${record.mediaFiles.length} '
                '${record.mediaFiles.length == 1 ? 'photo/video' : 'photos/videos'} '
                'will upload with this report.',
                style: const TextStyle(color: AppColors.warningYellow, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Saved: ${_formatTime(record.createdAt)}'
              '${record.syncedAt != null ? '  •  Synced: ${_formatTime(record.syncedAt!)}' : ''}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            if (record.incidentId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Server ID: ${record.incidentId}',
                style: const TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            if (record.errorMessage != null && record.status == ReportQueueStatus.failed) ...[
              const SizedBox(height: 6),
              Text(
                record.errorMessage!,
                style: const TextStyle(color: AppColors.primaryRed, fontSize: 12),
              ),
            ],
            if (record.status == ReportQueueStatus.failed) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _retry(record),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    side: const BorderSide(color: AppColors.primaryRed),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '${local.month}/${local.day}/${local.year} $h:$m $ampm';
  }
}