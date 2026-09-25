import '../constants/api_config.dart';
import 'api_service.dart';

class MapDataService {
  static const _pcfVisibleStatuses = {
    'forwarded to pcf',
    'under mdr review',
    'verified',
    'responding',
    'referred to pho',
    'under pho review',
    'resolved',
    'dismissed',
  };

  static Future<Map<String, dynamic>> getMapData({
    required String role,
    int? barangayId,
    int? userId,
    String? municipality,
  }) async {
    final result = await ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_map_data.php',
      body: {
        'role': role,
        'barangay_id': barangayId,
        'user_id': userId,
        if (municipality != null && municipality.isNotEmpty)
          'municipality': municipality,
      },
    );

    // The backend WHERE clause is already role-scoped. Only MDR (pcf) still
    // re-filters client-side; pho now trusts the backend's wider result set
    // (PHO pipeline + MDR-level statuses for the Governor's optional layer).
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != 'pcf' || result['success'] != true) {
      return result;
    }

    final rawData = result['data'];
    if (rawData is! Map) return result;

    final data = Map<String, dynamic>.from(rawData);
    final incidents = data['incidents'];
    if (incidents is List) {
      data['incidents'] = incidents.where((incident) {
        if (incident is! Map) return false;
        final status =
            incident['status']?.toString().trim().toLowerCase() ?? '';
        return _pcfVisibleStatuses.contains(status);
      }).toList();
    }

    return {...result, 'data': data};
  }
}
