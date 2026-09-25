import '../constants/api_config.dart';
import 'auth_service.dart';
import 'api_service.dart';

class UserService {
  static Future<Map<String, dynamic>> getUsers({String search = ''}) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_users.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'search': search,
      },
    );
  }

  /// Create a user.
  /// [role] is optional — only superadmin passes it (superadmin/pcf/pho/barangay).
  /// [subRole] is for barangay accounts (captain/secretary/tanod) and
  /// PDRRMO accounts (pdrrmo) created by the PHO Admin.
  static Future<Map<String, dynamic>> createUser({
    required String name,
    required String username,
    required String password,
    String? role,            // superadmin only: superadmin/pcf/pho/barangay
    String? subRole,         // barangay: captain/secretary/tanod; PHO: pdrrmo
    int? barangayId,
  }) async {
    final body = <String, dynamic>{
      'acting_user_id': AuthService.currentUserId,
      'name': name,
      'username': username,
      'password': password,
      'barangay_id': barangayId,
    };
    if (role != null) body['role'] = role;
    if (subRole != null) body['sub_role'] = subRole;
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/save_user.php',
      body: body,
    );
  }

  /// Update a user.
  /// [role] is optional — only superadmin passes it.
  /// [subRole] is for barangay accounts and PDRRMO accounts (both the PHO
  /// Admin flow and the superadmin flow use it when changing sub-role).
  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String name,
    required String username,
    String? role,            // superadmin only
    String? subRole,         // barangay/pdrrmo
    int? barangayId,
  }) async {
    final body = <String, dynamic>{
      'acting_user_id': AuthService.currentUserId,
      'user_id': userId,
      'name': name,
      'username': username,
      'barangay_id': barangayId,
    };
    if (role != null) body['role'] = role;
    if (subRole != null) body['sub_role'] = subRole;
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_user.php',
      body: body,
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required int userId,
    required String password,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/reset_user_password.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'user_id': userId,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> toggleStatus({
    required int userId,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/toggle_user_status.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'user_id': userId,
      },
    );
  }

  static Future<Map<String, dynamic>> getActivityLogs() async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_user_activity.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
      },
    );
  }
}
