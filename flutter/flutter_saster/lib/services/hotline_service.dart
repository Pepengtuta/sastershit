import '../constants/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

class HotlineService {
  static Future<Map<String, dynamic>> getHotlines({
    required String role,
    int? barangayId,
    String search = '',
    String category = 'All',
    String? municipality,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_hotlines.php',
      body: {
        'role': role,
        'barangay_id': barangayId,
        'search': search,
        'category': category,
        if (municipality != null && municipality.isNotEmpty)
          'municipality': municipality,
      },
    );
  }

  static Future<Map<String, dynamic>> saveHotline({
    required String hotlineScope,
    int? barangayId,
    required String officeName,
    String municipality = 'Kalibo',
    String category = 'Other',
    String telephoneNumbers = '',
    String cellphoneNumbers = '',
    String hotlineNumber = '',
    String remarks = '',
    String status = 'Active',
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/save_hotline.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'hotline_scope': hotlineScope,
        'barangay_id': barangayId,
        'office_name': officeName,
        'municipality': municipality,
        'category': category,
        'telephone_numbers': telephoneNumbers,
        'cellphone_numbers': cellphoneNumbers,
        'hotline_number': hotlineNumber,
        'remarks': remarks,
        'status': status,
      },
    );
  }

  static Future<Map<String, dynamic>> updateHotline({
    required int id,
    required String hotlineScope,
    int? barangayId,
    required String officeName,
    String municipality = 'Kalibo',
    String category = 'Other',
    String telephoneNumbers = '',
    String cellphoneNumbers = '',
    String hotlineNumber = '',
    String remarks = '',
    String status = 'Active',
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_hotline.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'id': id,
        'hotline_scope': hotlineScope,
        'barangay_id': barangayId,
        'office_name': officeName,
        'municipality': municipality,
        'category': category,
        'telephone_numbers': telephoneNumbers,
        'cellphone_numbers': cellphoneNumbers,
        'hotline_number': hotlineNumber,
        'remarks': remarks,
        'status': status,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteHotline({required int id}) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/delete_hotline.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'id': id,
      },
    );
  }
}
