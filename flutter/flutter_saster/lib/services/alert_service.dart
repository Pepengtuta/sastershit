import '../constants/api_config.dart';
import 'api_service.dart';

class AlertService {
  static Future<Map<String, dynamic>> getAlerts({
    required String role,
    int? barangayId,
    int? userId,
    String search = '',
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_alerts.php',
      body: {
        'role': role,
        'barangay_id': barangayId,
        'user_id': userId,
        'search': search,
      },
    );
  }

  static Future<Map<String, dynamic>> saveAlert({
    required int createdBy,
    required String title,
    required String alertType,
    required String severity,
    required String message,
    required String instructions,
    required String startDatetime,
    required String endDatetime,
    String targetType = 'all',
    List<int> barangayIds = const [],
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/save_alert.php',
      body: {
        'created_by': createdBy,
        'title': title,
        'alert_type': alertType,
        'severity': severity,
        'message': message,
        'instructions': instructions,
        'start_datetime': startDatetime,
        'end_datetime': endDatetime,
        'target_type': targetType,
        'barangay_ids': barangayIds,
      },
    );
  }

  static Future<Map<String, dynamic>> markAlertsRead({
    required int userId,
    required int barangayId,
    required List<int> alertIds,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/mark_alerts_read.php',
      body: {
        'user_id': userId,
        'barangay_id': barangayId,
        'alert_ids': alertIds,
      },
    );
  }

  static Future<Map<String, dynamic>> getUnreadAlertCount({
    required int userId,
    required int barangayId,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_unread_alert_count.php',
      body: {
        'user_id': userId,
        'barangay_id': barangayId,
      },
    );
  }
}
