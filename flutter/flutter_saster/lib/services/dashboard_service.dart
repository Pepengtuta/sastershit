import '../constants/api_config.dart';
import 'api_service.dart';

class DashboardService {
  static Future<Map<String, dynamic>> getDashboardSummary({
    required String role,
    int? barangayId,
    required int month,
    required int year,
    String subRole = '',
    int? userId,
    String? municipality,
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_dashboard_summary.php',
      body: {
        'role': role,
        'barangay_id': barangayId,
        'month': month,
        'year': year,
        'sub_role': subRole,
        'user_id': userId,
        if (municipality != null && municipality.isNotEmpty)
          'municipality': municipality,
      },
    );
  }
}
