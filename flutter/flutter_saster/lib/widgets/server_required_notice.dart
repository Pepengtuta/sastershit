import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/offline_sync_coordinator.dart';

/// Message used whenever an online-only mutation (user management, alert
/// publishing, etc.) is attempted while the server is unreachable.
const String kOfflineWriteMessage =
    'Server connection required — this action is online-only and unavailable while offline.';

/// True while the API host is believed unreachable (circuit breaker open or the
/// coordinator's reachability state set).
bool isServerUnreachable() {
  return ApiService.isApiUnreachable ||
      OfflineSyncCoordinator.instance.apiStatus ==
          ApiReachabilityStatus.unreachable;
}

/// Inline banner shown while the server is unreachable. It announces the
/// online-only requirement of user management (and any other write) and
/// rebuilds automatically when the offline coordinator reports the server
/// reachable/unreachable again.
class ServerRequiredNotice extends StatefulWidget {
  const ServerRequiredNotice({super.key, this.message = kOfflineWriteMessage});

  final String message;

  @override
  State<ServerRequiredNotice> createState() => _ServerRequiredNoticeState();
}

class _ServerRequiredNoticeState extends State<ServerRequiredNotice> {
  @override
  void initState() {
    super.initState();
    OfflineSyncCoordinator.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    OfflineSyncCoordinator.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!isServerUnreachable()) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF92400E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}