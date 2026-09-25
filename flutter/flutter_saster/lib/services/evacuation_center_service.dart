import '../constants/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

class EvacuationCenterService {
  static Future<Map<String, dynamic>> getEvacuationCenters({
    required String role,
    int? barangayId,
    String? barangayName,
    String search = '',
    String? municipality,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_evacuation_centers.php',
      body: {
        'role': role,
        'barangay_id': barangayId,
        'barangay_name': barangayName,
        'search': search,
        if (municipality != null && municipality.isNotEmpty)
          'municipality': municipality,
      },
    );
  }

  static Future<Map<String, dynamic>> saveEvacuationCenter({
    required String barangay,
    int? barangayId,
    required String centerName,
    String centerType = 'Evacuation Center',
    int capacity = 0,
    int currentEvacuees = 0,
    String status = 'Available',
    String contactPerson = '',
    String contactNumber = '',
    double? latitude,
    double? longitude,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/save_evacuation_center.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'barangay': barangay,
        'barangay_id': barangayId,
        'center_name': centerName,
        'center_type': centerType,
        'capacity': capacity,
        'current_evacuees': currentEvacuees,
        'status': status,
        'contact_person': contactPerson,
        'contact_number': contactNumber,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  static Future<Map<String, dynamic>> updateEvacuationCenter({
    required int id,
    required String barangay,
    int? barangayId,
    required String centerName,
    String centerType = 'Evacuation Center',
    int capacity = 0,
    int currentEvacuees = 0,
    String status = 'Available',
    String contactPerson = '',
    String contactNumber = '',
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_evacuation_center.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'id': id,
        'barangay': barangay,
        'barangay_id': barangayId,
        'center_name': centerName,
        'center_type': centerType,
        'capacity': capacity,
        'current_evacuees': currentEvacuees,
        'status': status,
        'contact_person': contactPerson,
        'contact_number': contactNumber,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteEvacuationCenter({required int id}) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/delete_evacuation_center.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'id': id,
      },
    );
  }
}
