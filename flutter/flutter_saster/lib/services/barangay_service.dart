import '../constants/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

class BarangayService {
  static Future<Map<String, dynamic>> getBarangays() async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_barangays.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
      },
    );
  }

  static Future<Map<String, dynamic>> updatePopulation({
    required int barangayId,
    required int population,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_barangay_population.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'barangay_id': barangayId,
        'population': population,
      },
    );
  }
}
