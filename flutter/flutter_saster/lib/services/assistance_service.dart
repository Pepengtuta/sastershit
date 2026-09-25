import '../constants/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AssistanceService {
  static Future<Map<String, dynamic>> getCenterNeeds({
    required int evacCenterId,
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_center_needs.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'evac_center_id': evacCenterId,
      },
    );
  }

  static Future<Map<String, dynamic>> saveCenterNeeds({
    required int evacCenterId,
    int? totalEvacuees,
    int? families,
    int? pregnant,
    int? lactatingMothers,
    int? infants,
    int? children,
    int? olderPersons,
    int? pwd,
    int? sick,
    int? injured,
    required List<Map<String, dynamic>> items,
    String profileSource = 'manual',
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/save_center_needs.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'evac_center_id': evacCenterId,
        'total_evacuees': totalEvacuees,
        'families': families,
        'pregnant': pregnant,
        'lactating_mothers': lactatingMothers,
        'infants': infants,
        'children': children,
        'older_persons': olderPersons,
        'pwd': pwd,
        'sick': sick,
        'injured': injured,
        'items': items,
        'profile_source': profileSource,
      },
    );
  }

  static Future<Map<String, dynamic>> getBoard({
    String? municipality,
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_assistance_board.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        if (municipality != null && municipality.isNotEmpty)
          'municipality': municipality,
      },
    );
  }

  static Future<Map<String, dynamic>> pledge({
    required int evacCenterId,
    int? needId,
    required String item,
    required String unit,
    required int qty,
    String remarks = '',
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/pledge_assistance.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'evac_center_id': evacCenterId,
        'need_id': needId,
        'item': item,
        'unit': unit,
        'qty': qty,
        'remarks': remarks,
      },
    );
  }

  static Future<Map<String, dynamic>> updateStatus({
    required int assistanceId,
    required String action,
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_assistance_status.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'assistance_id': assistanceId,
        'action': action,
      },
    );
  }

  /// Barangay-side confirmation that a delivered donation physically arrived.
  /// Authorized server-side: Captain/Secretary, own barangay only, Delivered +
  /// not yet confirmed.
  static Future<Map<String, dynamic>> confirmReceived({
    required int assistanceId,
    required int qtyReceived,
  }) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/confirm_assistance_received.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'assistance_id': assistanceId,
        'qty_received': qtyReceived,
      },
    );
  }
}