import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_config.dart';
import 'api_service.dart';

class AuthService {
  static const String _sessionKey = 'saster_current_user';
  static const String _filterMuniKey = 'saster_filter_municipality';

  static Map<String, dynamic>? currentUser;

  // In-memory municipality filter for admin roles (persisted via SharedPreferences).
  static String? _filterMunicipality;

  /// The active municipality filter. Null = "All Municipalities".
  static String? get filterMunicipality => _filterMunicipality;

  /// Set the filter and persist it. Pass null or empty string to clear.
  static Future<void> setFilterMunicipality(String? value) async {
    _filterMunicipality = (value == null || value.isEmpty) ? null : value;
    final prefs = await SharedPreferences.getInstance();
    if (_filterMunicipality == null) {
      await prefs.remove(_filterMuniKey);
    } else {
      await prefs.setString(_filterMuniKey, _filterMunicipality!);
    }
  }

  /// The municipality to send to API calls for admin roles.
  /// Null means all municipalities for province-level roles.
  static String? get effectiveMunicipality {
    final role = currentRole?.toLowerCase() ?? '';
    final isAdmin = role == 'superadmin' || role == 'pcf' || role == 'pho';
    if (!isAdmin) return null;
    if (isMdrKalibo) return 'Kalibo';
    if (isMdrIbajay) return 'Ibajay';
    if (isMayorKalibo) return 'Kalibo';
    if (isMayorIbajay) return 'Ibajay';
    return _filterMunicipality;
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final result = await ApiService.postJson(
      url: '${ApiConfig.baseUrl}/login.php',
      body: {'username': username, 'password': password},
    );

    if (result['success'] == true && result['data'] != null) {
      currentUser = Map<String, dynamic>.from(result['data']);
      await _saveSession(currentUser!);
      if (_filterMunicipality == null) await _applyPhoDefaultFilter();
    }

    return result;
  }

  static Future<void> _saveSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(user));
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);

    if (raw == null || raw.trim().isEmpty) {
      currentUser = null;
      return false;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        currentUser = Map<String, dynamic>.from(decoded);
        // Restore municipality filter if previously saved
        final savedMuni = prefs.getString(_filterMuniKey);
        _filterMunicipality = (savedMuni == null || savedMuni.isEmpty)
            ? null
            : savedMuni;
        if (_filterMunicipality == null) await _applyPhoDefaultFilter();
        return true;
      }
    } catch (_) {
      currentUser = null;
      await prefs.remove(_sessionKey);
    }

    return false;
  }

  static Future<void> logout() async {
    currentUser = null;
    _filterMunicipality = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_filterMuniKey);
  }

  /// PHO accounts (PHO Admin + PDRRMO) default their municipality filter to
  /// Ibajay on every fresh login. In-memory only: the next login re-applies the
  /// default unless the user picked a filter earlier in the session.
  static Future<void> _applyPhoDefaultFilter() async {
    if (!isPho) return;
    _filterMunicipality = 'Ibajay';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filterMuniKey, _filterMunicipality!);
  }

  static int? get currentUserId {
    final value = currentUser?['id'];
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static int? get currentBarangayId {
    final value = currentUser?['barangay_id'];
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  static String? get currentRole => currentUser?['role']?.toString();
  static String? get currentName => currentUser?['name']?.toString();
  static String? get currentUsername => currentUser?['username']?.toString();
  static String? get currentBarangayName =>
      currentUser?['barangay_name']?.toString();
  static String? get currentMunicipality =>
      currentUser?['municipality']?.toString();

  static int? get currentBarangayPopulation {
    final value = currentUser?['population'];
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  // ── Sub-role (chairman / secretary / tanod) ──
  static String? get currentSubRole => currentUser?['sub_role']?.toString();
  static bool get isCaptain => currentSubRole == 'captain';
  static bool get isSecretary => currentSubRole == 'secretary';
  static bool get isTanod => currentSubRole == 'tanod';
  static bool get canManageUsers =>
      currentUser?['can_manage_users'] == true ||
      currentUser?['can_manage_users'] == 1 ||
      currentUser?['can_manage_users']?.toString() == '1' ||
      currentUser?['can_manage_users']?.toString() == 'True';

  // ── MDR sub-role helpers ──
  static String get normalizedRole => currentRole?.toLowerCase() ?? '';
  static String get normalizedSubRole => currentSubRole?.toLowerCase() ?? '';
  static bool get isPcfAdmin =>
      normalizedRole == 'pcf' && normalizedSubRole == 'mdr_admin';
  static bool get isMdrKalibo =>
      normalizedRole == 'pcf' && normalizedSubRole == 'mdr_kalibo';
  static bool get isMdrIbajay =>
      normalizedRole == 'pcf' && normalizedSubRole == 'mdr_ibajay';
  static bool get isPcfMdr =>
      normalizedRole == 'pcf' &&
      ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay'].contains(normalizedSubRole);

  // ── Mayor observer sub-role helpers (read-only town viewers) ──
  static bool get isMayorKalibo =>
      normalizedRole == 'pcf' && normalizedSubRole == 'mayor_kalibo';
  static bool get isMayorIbajay =>
      normalizedRole == 'pcf' && normalizedSubRole == 'mayor_ibajay';
  static bool get isMayor =>
      normalizedRole == 'pcf' &&
      ['mayor_kalibo', 'mayor_ibajay'].contains(normalizedSubRole);

  /// Mayor observers and the Aklan Governor are fully read-only:
  /// no create/edit/delete anywhere.
  static bool get isReadOnlyObserver =>
      isMayor ||
      (normalizedRole == 'pho' && normalizedSubRole == 'governor');

  // ── PHO / PDRRMO / Governor helpers ──
  // The default Provincial account (role 'pho', empty sub-role) is the PHO Admin.
  static bool get isPhoAdmin => normalizedRole == 'pho' && normalizedSubRole.isEmpty;
  // PDRRMO accounts are province-wide operational rescue-team members.
  static bool get isPdrrmo => normalizedRole == 'pho' && normalizedSubRole == 'pdrrmo';
  // The Aklan Governor is a province-wide read-only observer.
  static bool get isGovernor => normalizedRole == 'pho' && normalizedSubRole == 'governor';
  static bool get isPho =>
      normalizedRole == 'pho' &&
      (normalizedSubRole.isEmpty ||
          normalizedSubRole == 'pdrrmo' ||
          normalizedSubRole == 'governor');

  static String? get currentMdrMunicipality {
    if (isMdrKalibo) return 'Kalibo';
    if (isMdrIbajay) return 'Ibajay';
    if (isMayorKalibo) return 'Kalibo';
    if (isMayorIbajay) return 'Ibajay';
    return null;
  }

  /// Fetch the list of distinct municipalities from the database.
  static Future<List<String>> getMunicipalities() async {
    try {
      final result = await ApiService.postJson(
        url: '${ApiConfig.baseUrl}/get_municipalities.php',
        body: {},
      );
      if (result['success'] == true && result['data'] is List) {
        return (result['data'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return ['Kalibo', 'Ibajay'];
  }
}
