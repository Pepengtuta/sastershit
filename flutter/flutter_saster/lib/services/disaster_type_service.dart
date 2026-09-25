import '../constants/api_config.dart';
import 'api_service.dart';

class DisasterTypeService {
  static Future<Map<String, dynamic>> getDisasterTypes() {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_disaster_types.php',
      body: {},
    );
  }
}