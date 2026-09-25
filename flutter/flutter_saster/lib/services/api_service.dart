import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);

  /// Shared HTTP client. Replaced by [recreateHttpClient] when the network
  /// changes so stale sockets to a previous gateway never get reused.
  static http.Client _client = http.Client();

  /// Invoked whenever a connection-level failure is recorded (unreachable
  /// host). Used by the offline coordinator to start auto-retry health checks.
  static void Function()? onConnectionFailure;

  /// Closes and discards the shared HTTP client so the next request opens a
  /// fresh socket (required after Wi-Fi/network role changes).
  static void recreateHttpClient() {
    _client.close();
    _client = http.Client();
  }

  @visibleForTesting
  static http.Client get debugClient => _client;

  /// How long incoming requests are short-circuited after a connection-level
  /// failure (unreachable host). Raised by [isApiUnreachable] when the host is
  /// reachable again or the window elapses.
  @visibleForTesting
  static Duration unreachableCooldown = const Duration(seconds: 30);

  static DateTime? _cooldownUntil;
  static int _consecutiveConnectionFailures = 0;
  static String? _lastFailureDetail;

  /// True while the API host is unreachable and requests are being answered
  /// synchronously without touching the network.
  static bool get isApiUnreachable {
    final until = _cooldownUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _cooldownUntil = null;
    _consecutiveConnectionFailures = 0;
    _lastFailureDetail = null;
    return false;
  }

  static int get consecutiveConnectionFailures => _consecutiveConnectionFailures;

  /// Clears the circuit-breaker state (used by tests and manual retries).
  static void resetApiBreaker() {
    _cooldownUntil = null;
    _consecutiveConnectionFailures = 0;
    _lastFailureDetail = null;
  }

  static void _noteConnectionFailure(String detail) {
    _consecutiveConnectionFailures += 1;
    _lastFailureDetail = detail;
    _cooldownUntil = DateTime.now().add(unreachableCooldown);
    onConnectionFailure?.call();
  }

  static Map<String, dynamic> _connectionFailure(String detail) {
    return {
      'success': false,
      'message': 'Connection failed: $detail',
      'data': null,
    };
  }

  static Map<String, dynamic> _connectionFailureShortCircuit() {
    return _connectionFailure(
      _lastFailureDetail ??
          'API host is unreachable - pausing requests until it comes back',
    );
  }

  static bool isConnectionFailure({required String message}) {
    return message.startsWith('Connection failed') ||
        message.startsWith('Request timed out');
  }

  /// Returns [message] for display, hiding technical transport detail in
  /// release builds. Debug builds keep the full detail for development.
  static String userMessage(String message, {bool? debug}) {
    if (debug ?? kDebugMode) return message;
    return message.startsWith('Connection failed')
        ? 'Something went wrong. Please check your connection and try again.'
        : message;
  }

  static Future<Map<String, dynamic>> postJson({
    required String url,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(url);
    assert(
      uri.isAbsolute && !url.contains('](') && !url.startsWith('['),
      'API URL must be a plain absolute URL (no markdown). Got: $url',
    );
    if (kDebugMode) {
      final string = jsonEncode(body);
      debugPrint('[ApiService] POST $uri (timeout ${_timeout.inSeconds}s)');
      debugPrint('[ApiService]   body: ${string.length > 200 ? '${string.substring(0, 200)}...' : string}');
    }
    if (isApiUnreachable) return _connectionFailureShortCircuit();
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...ApiConfig.ngrokHeaders,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (kDebugMode) debugPrint('[ApiService] POST $uri -> HTTP ${response.statusCode}');

      resetApiBreaker();
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
          'data': null,
        };
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'message': 'Server returned invalid data. Please try again.',
          'data': null,
        };
      }
    } on TimeoutException catch (_) {
      if (kDebugMode) debugPrint('[ApiService] POST $uri timed out after ${_timeout.inSeconds}s');
      _noteConnectionFailure('request timed out');
      return {
        'success': false,
        'message': 'Request timed out. Please check your connection and try again.',
        'data': null,
      };
    } catch (error) {
      if (kDebugMode) debugPrint('[ApiService] POST $uri connection error: $error');
      _noteConnectionFailure('$error');
      return _connectionFailure('$error');
    }
  }

  static Future<Map<String, dynamic>> getJson({required String url}) async {
    final uri = Uri.parse(url);
    assert(
      uri.isAbsolute && !url.contains('](') && !url.startsWith('['),
      'API URL must be a plain absolute URL (no markdown). Got: $url',
    );
    if (kDebugMode) debugPrint('[ApiService] GET $uri (timeout ${_timeout.inSeconds}s)');
    if (isApiUnreachable) return _connectionFailureShortCircuit();
    try {
      final response = await _client
          .get(
            uri,
            headers: ApiConfig.ngrokHeaders,
          )
          .timeout(_timeout);

      if (kDebugMode) debugPrint('[ApiService] GET $uri -> HTTP ${response.statusCode}');

      resetApiBreaker();
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
          'data': null,
        };
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'message': 'Server returned invalid data. Please try again.',
          'data': null,
        };
      }
    } on TimeoutException catch (_) {
      if (kDebugMode) debugPrint('[ApiService] GET $uri timed out after ${_timeout.inSeconds}s');
      _noteConnectionFailure('request timed out');
      return {
        'success': false,
        'message': 'Request timed out. Please check your connection and try again.',
        'data': null,
      };
    } catch (error) {
      if (kDebugMode) debugPrint('[ApiService] GET $uri connection error: $error');
      _noteConnectionFailure('$error');
      return _connectionFailure('$error');
    }
  }
}