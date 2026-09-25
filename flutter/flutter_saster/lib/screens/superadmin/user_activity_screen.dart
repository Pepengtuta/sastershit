import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final result = await UserService.getActivityLogs();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        isLoading = false;
        errorMessage = ApiService.userMessage(result['message']?.toString() ?? 'Failed to load activity.');
      });
      return;
    }
    setState(() {
      logs = result['data'] ?? [];
      isLoading = false;
    });
  }

  String actionLabel(String action) {
    switch (action) {
      case 'create':
        return 'Created account';
      case 'update':
        return 'Updated account';
      case 'reset_password':
        return 'Reset password';
      case 'deactivate':
        return 'Deactivated account';
      case 'reactivate':
        return 'Reactivated account';
      default:
        return action;
    }
  }

  Color actionColor(String action) {
    switch (action) {
      case 'create':
        return AppColors.successGreen;
      case 'deactivate':
        return AppColors.primaryRed;
      case 'reactivate':
        return AppColors.successGreen;
      case 'reset_password':
        return AppColors.warningYellow;
      default:
        return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingView();
    if (errorMessage != null) return ErrorState(message: errorMessage!, onRetry: loadLogs);
    if (logs.isEmpty) return const EmptyState(icon: Icons.history, message: 'No activity recorded yet.');

    return RefreshIndicator(
      onRefresh: loadLogs,
      color: AppColors.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = Map<String, dynamic>.from(logs[index]);
          final action = log['action']?.toString() ?? '';
          final color = actionColor(action);
          return InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        actionLabel(action),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      log['created_at']?.toString() ?? '',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Target: @${log['target_username'] ?? '-'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'By ${log['actor_name'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if ((log['details']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log['details'].toString(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
