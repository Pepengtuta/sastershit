import 'package:flutter/material.dart';

/// Compact banner that announces "saved" (cached) data is being shown, with
/// the last successful sync time. Used by the Dashboard and Alerts screens when
/// a refresh failed but the previous successful snapshot is still on screen —
/// a friendly "Saved dashboard / Saved alerts" label plus a stale-data note.
///
/// The banner is deliberately indented into the page flow (own margin/padding)
/// so it can also sit inside a ListView without extra wrappers.
class SavedDataBanner extends StatelessWidget {
  const SavedDataBanner({
    super.key,
    required this.title,
    this.lastUpdated,
    this.detail,
    this.icon = Icons.cloud_off_outlined,
    this.margin,
  });

  /// The label, e.g. "Saved dashboard" or "Saved alerts".
  final String title;

  /// The last successful sync time (null shows "earlier").
  final DateTime? lastUpdated;

  /// Extra explanation, e.g. "A server connection is required for new alerts."
  final String? detail;

  final IconData icon;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF92400E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title — awaiting server',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last synced ${_relativeTime(lastUpdated)}.',
                  style: TextStyle(
                    color: const Color(0xFF92400E).withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      color: const Color(0xFF92400E).withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Human-friendly sync time, e.g. "just now", "5 min ago", or a full
  /// "Jan 3 • 4:05 PM".
  static String _relativeTime(DateTime? value) {
    if (value == null) return 'earlier';

    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.isNegative || difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    if (difference.inDays < 3) {
      final days = difference.inDays;
      return days == 1 ? 'yesterday' : '$days days ago';
    }

    final hour12 = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_months[value.month - 1]} ${value.day} • $hour12:$minute $ampm';
  }
}

/// Kept for callers that want the raw text without the container.
String savedDataRelativeTime(DateTime? value) {
  if (value == null) return 'earlier';
  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (difference.inDays < 3) {
    final days = difference.inDays;
    return days == 1 ? 'yesterday' : '$days days ago';
  }
  final hour12 = value.hour == 0
      ? 12
      : (value.hour > 12 ? value.hour - 12 : value.hour);
  final ampm = value.hour >= 12 ? 'PM' : 'AM';
  final minute = value.minute.toString().padLeft(2, '0');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[value.month - 1]} ${value.day} • $hour12:$minute $ampm';
}