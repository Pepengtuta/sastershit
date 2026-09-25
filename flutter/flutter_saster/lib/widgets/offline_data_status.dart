import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/offline_sync_coordinator.dart';
import 'hotline_cache_status.dart' show formatUpdatedAt;

/// Shown when the app has never downloaded offline data. Honest first-use
/// wording: no cached data exists yet, so connect once to save it.
const String kFirstUseOfflineMessage =
    "Your offline data hasn't been downloaded yet.\n\n"
    'Connect to the internet and sign in once to save hotlines, disaster '
    'types, evacuation centers, needs, and map data so they can be viewed '
    'when you are offline.';

/// AppBar icon showing the global offline-data sync state. Tapping opens a
/// dialog with the current status and a manual "Sync offline data" action.
class OfflineDataStatusIndicator extends StatefulWidget {
  const OfflineDataStatusIndicator({super.key});

  @override
  State<OfflineDataStatusIndicator> createState() =>
      _OfflineDataStatusIndicatorState();
}

class _OfflineDataStatusIndicatorState
    extends State<OfflineDataStatusIndicator> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineSyncCoordinator.instance,
      builder: (context, _) {
        final status = OfflineSyncCoordinator.instance.status;
        final running = status.running;
        final apiStatus = OfflineSyncCoordinator.instance.apiStatus;
        final label = reachabilityLabelFor(apiStatus, status);

        final widget = (running || apiStatus == ApiReachabilityStatus.checking)
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(iconFor(status, apiStatus), color: colorFor(status, apiStatus));

        return IconButton(
          tooltip: label,
          onPressed: () => _showStatusDialog(status, apiStatus),
          icon: widget,
        );
      },
    );
  }

  void _showStatusDialog(OfflineSyncStatus status, ApiReachabilityStatus apiStatus) {
    final label = reachabilityLabelFor(apiStatus, status);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Offline data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconFor(status, apiStatus), color: colorFor(status, apiStatus), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (apiStatus == ApiReachabilityStatus.unreachable) ...[
                const SizedBox(height: 10),
                const Text(
                  'The server is unreachable right now. The app is retrying '
                  'automatically - cached data stays available meanwhile.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
              if (apiStatus == ApiReachabilityStatus.checking) ...[
                const SizedBox(height: 10),
                const Text(
                  'Checking the server connection again…',
                  style: TextStyle(fontSize: 13),
                ),
              ],
              if (status.lastSyncedAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Last synchronized '
                  '${formatUpdatedAt(status.lastSyncedAt!)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (status.neverSynced) ...[
                const SizedBox(height: 12),
                const Text(
                  kFirstUseOfflineMessage,
                  style: TextStyle(fontSize: 13),
                ),
              ],
              if (status.partial) ...[
                const SizedBox(height: 12),
                const Text(
                  'Some data could not be updated. Check your connection and '
                  'try again, or connect once more later.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                OfflineSyncCoordinator.instance.retryConnection();
              },
              child: const Text('Retry connection'),
            ),
          ],
        );
      },
    );
  }
}

/// Status line that also reflects the transient API reachability.
String reachabilityLabelFor(
  ApiReachabilityStatus apiStatus,
  OfflineSyncStatus status,
) {
  if (apiStatus == ApiReachabilityStatus.unreachable) {
    return 'Server unreachable — retrying automatically';
  }
  if (apiStatus == ApiReachabilityStatus.checking) {
    return status.running ? 'Reconnecting & preparing offline data…' : 'Reconnecting…';
  }
  return statusLabelFor(status);
}

/// The main status line for the current sync state.
String statusLabelFor(OfflineSyncStatus status) {
  if (status.running) return 'Preparing offline data…';
  if (status.neverSynced) return 'Never synchronized';
  if (status.hadFailures) return 'Some data could not be updated';
  return 'Offline data ready';
}

IconData iconFor(OfflineSyncStatus status, ApiReachabilityStatus apiStatus) {
  if (apiStatus == ApiReachabilityStatus.unreachable) return Icons.cloud_off;
  if (apiStatus == ApiReachabilityStatus.checking) return Icons.cloud_sync;
  if (status.running) return Icons.cloud_sync;
  if (status.neverSynced) return Icons.cloud_queue;
  if (status.hadFailures) return Icons.cloud_off;
  return Icons.cloud_done;
}

Color colorFor(OfflineSyncStatus status, ApiReachabilityStatus apiStatus) {
  if (apiStatus == ApiReachabilityStatus.unreachable) return AppColors.warningYellow;
  if (apiStatus == ApiReachabilityStatus.checking) return Colors.white;
  if (status.running) return Colors.white;
  if (status.neverSynced) return Colors.white70;
  if (status.hadFailures) return AppColors.warningYellow;
  return Colors.greenAccent;
}