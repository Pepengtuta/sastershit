import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/alert_repository.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/saved_data_banner.dart';
import '../../widgets/search_box.dart';
import '../../widgets/status_badge.dart';

class PcfAlertsScreen extends StatefulWidget {
  final int refreshToken;
  final VoidCallback? onAlertsRead;

  const PcfAlertsScreen({super.key, this.refreshToken = 0, this.onAlertsRead});

  @override
  State<PcfAlertsScreen> createState() => _PcfAlertsScreenState();
}

class _PcfAlertsScreenState extends State<PcfAlertsScreen> {
  final searchController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> alerts = [];
  DateTime? lastUpdated;
  bool hasCache = false;
  bool offline = false;

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  @override
  void didUpdateWidget(covariant PcfAlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) loadAlerts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  String creatorLabel(Map<String, dynamic> alert) {
    final name = alert['created_by_name']?.toString() ?? '';
    final rawRole = (alert['created_by_role']?.toString() ?? '').toLowerCase();
    final roleText = rawRole.isEmpty
        ? 'System'
        : (rawRole == 'pfc' ? 'Municipal' : rawRole == 'pcf' ? 'Municipal' : rawRole == 'pho' ? 'Provincial' : rawRole.toUpperCase());
    if (name.isEmpty) return 'Created by: $roleText';
    return 'Created by: $name ($roleText)';
  }

  Future<void> markVisibleAlertsRead() async {
    if (ApiService.isApiUnreachable) return;
    if (!(AuthService.currentRole == 'barangay' || AuthService.currentRole == 'brgy')) return;
    final userId = AuthService.currentUserId;
    final barangayId = AuthService.currentBarangayId;
    if (userId == null || barangayId == null) return;

    final ids = alerts
        .map((item) => int.tryParse(Map<String, dynamic>.from(item)['id'].toString()))
        .whereType<int>()
        .toList();

    if (ids.isEmpty) return;

    await AlertService.markAlertsRead(
      userId: userId,
      barangayId: barangayId,
      alertIds: ids,
    );

    if (!mounted) return;
    widget.onAlertsRead?.call();
  }

  Future<void> loadAlerts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await AlertRepository.instance.refresh(
      userId: AuthService.currentUserId ?? 0,
      role: AuthService.currentRole ?? 'barangay',
      barangayId: AuthService.currentBarangayId,
      search: searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      alerts = result.alerts;
      lastUpdated = result.lastUpdated;
      hasCache = result.hasCache;
      offline = result.offline;
      errorMessage = result.offline && !result.hasCache
          ? 'No saved alerts on this device yet. Connect to the server once to download alerts for offline use.'
          : null;
      isLoading = false;
    });

    if (!offline && !ApiService.isApiUnreachable) {
      await markVisibleAlertsRead();
    }
  }

  Widget buildAlertCard(Map<String, dynamic> alert) {
    final isRead = int.tryParse(alert['is_read']?.toString() ?? '0') == 1;
    final validityStatus = alert['validity_status']?.toString() ?? 'Active';
    final start = formatDateTime(alert['start_datetime']);
    final end = formatDateTime(alert['end_datetime']);
    final target = alert['target_label']?.toString() ?? 'All Barangays';
    final instructions = alert['instructions']?.toString() ?? '';

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isRead ? AppColors.textMuted : AppColors.primaryRed,
                foregroundColor: Colors.white,
                child: Icon(isRead ? Icons.notifications_none_outlined : Icons.notifications_active_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert['title']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              StatusBadge(status: alert['severity']?.toString() ?? 'Alert'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(status: validityStatus),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(alert['alert_type']?.toString() ?? 'Alert'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(alert['message']?.toString() ?? ''),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Instructions: $instructions'),
          ],
          const SizedBox(height: 10),
          _MetaLine(icon: Icons.person_outline, text: creatorLabel(alert)),
          _MetaLine(icon: Icons.groups_outlined, text: 'Target: $target'),
          _MetaLine(icon: Icons.date_range_outlined, text: 'Valid: $start → $end'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBox(controller: searchController, hint: 'Search alerts...', onChanged: (_) => loadAlerts()),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (isLoading) return const LoadingView();
              if (errorMessage != null) {
                return ErrorState(message: errorMessage!, onRetry: loadAlerts);
              }

              final list = alerts.isEmpty
                  ? const EmptyState(icon: Icons.notifications_none_outlined, message: 'No alerts found.')
                  : RefreshIndicator(
                      onRefresh: loadAlerts,
                      color: AppColors.primaryRed,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final alert = Map<String, dynamic>.from(alerts[index]);
                          return buildAlertCard(alert);
                        },
                      ),
                    );

              if (!offline || !hasCache) return list;

              return Column(
                children: [
                  SavedDataBanner(
                    title: 'Saved alerts',
                    lastUpdated: lastUpdated,
                    detail: 'A server connection is required for new alerts. Creating alerts is online-only.',
                  ),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}