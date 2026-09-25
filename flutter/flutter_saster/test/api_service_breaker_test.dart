import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_saster/services/api_service.dart';

Future<HttpServer> _startServer(List<int> hits) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    hits.add(1);
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write('{"success":true,"data":null}')
      ..close();
  });
  return server;
}

void main() {
  setUp(() {
    ApiService.resetApiBreaker();
    ApiService.unreachableCooldown = const Duration(milliseconds: 50);
  });

  tearDown(() {
    ApiService.resetApiBreaker();
    ApiService.unreachableCooldown = const Duration(seconds: 30);
  });

  test('a connection failure opens the breaker and later requests skip the network', () async {
    // Port with nothing listening -> connect error.
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close(force: true);

    final failed = await ApiService.getJson(url: 'http://127.0.0.1:$deadPort/x.php');
    expect(failed['success'], isFalse);
    expect(ApiService.isConnectionFailure(message: failed['message'] as String), isTrue);
    expect(ApiService.isApiUnreachable, isTrue);
    expect(ApiService.consecutiveConnectionFailures, greaterThanOrEqualTo(1));

    // While open, a request to a LIVE server must NOT reach it.
    final hits = <int>[];
    final live = await _startServer(hits);

    final skipped = await ApiService.getJson(url: 'http://127.0.0.1:${live.port}/x.php');
    expect(skipped['success'], isFalse);
    expect(ApiService.isConnectionFailure(message: skipped['message'] as String), isTrue);
    expect(hits, isEmpty, reason: 'breaker should short-circuit before hitting the network');

    // After the cooldown elapses the breaker resets and traffic flows again.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(ApiService.isApiUnreachable, isFalse);

    final ok = await ApiService.getJson(url: 'http://127.0.0.1:${live.port}/x.php');
    expect(ok['success'], isTrue);
    expect(hits, hasLength(1));

    await live.close(force: true);
  });

  test('resetApiBreaker clears the open breaker state', () async {
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close(force: true);

    await ApiService.getJson(url: 'http://127.0.0.1:$deadPort/x.php');
    expect(ApiService.isApiUnreachable, isTrue);
    expect(ApiService.consecutiveConnectionFailures, greaterThanOrEqualTo(1));

    ApiService.resetApiBreaker();
    expect(ApiService.isApiUnreachable, isFalse);
    expect(ApiService.consecutiveConnectionFailures, 0);
  });

  test('a connection failure notifies the coordinator callback', () async {
    ApiService.resetApiBreaker();
    var notified = 0;
    ApiService.onConnectionFailure = () => notified++;
    try {
      final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = dead.port;
      await dead.close(force: true);

      await ApiService.getJson(url: 'http://127.0.0.1:$deadPort/x.php');
      expect(notified, 1);
    } finally {
      ApiService.onConnectionFailure = null;
      ApiService.resetApiBreaker();
    }
  });

  test('recreateHttpClient swaps the shared client for a fresh one', () async {
    ApiService.resetApiBreaker();
    final oldClient = ApiService.debugClient;

    ApiService.recreateHttpClient();
    expect(ApiService.debugClient, isNot(same(oldClient)),
        reason: 'a stale client must never be reused after network restore');

    // The fresh client still performs requests.
    final hits = <int>[];
    final live = await _startServer(hits);
    final ok = await ApiService.getJson(url: 'http://127.0.0.1:${live.port}/x.php');
    expect(ok['success'], isTrue);
    expect(hits, hasLength(1));
    await live.close(force: true);
  });

  test('timeout and connection failures keep the breaker closed', () async {
    ApiService.resetApiBreaker();
    expect(ApiService.isApiUnreachable, isFalse);
    expect(ApiService.isConnectionFailure(message: 'Connection failed: SocketException'),
        isTrue);
    expect(
        ApiService.isConnectionFailure(
            message: 'Request timed out. Please check your connection and try again.'),
        isTrue);
  });

  group('userMessage', () {
    const generic =
        'Something went wrong. Please check your connection and try again.';

    test('debug builds keep the technical detail', () {
      const raw = 'Connection failed: ClientException with SocketException: '
          'Connection refused (OS Error)';
      expect(ApiService.userMessage(raw, debug: true), raw);
    });

    test('release builds replace raw connection failures with a clean message', () {
      const raw = 'Connection failed: ClientException with SocketException: '
          'Connection refused (OS Error)';
      expect(ApiService.userMessage(raw, debug: false), generic);
    });

    test('friendly server messages pass through unchanged in release', () {
      expect(ApiService.userMessage('You are not authorized to manage users.', debug: false),
          'You are not authorized to manage users.');
      expect(ApiService.userMessage('Barangay id is invalid.', debug: false),
          'Barangay id is invalid.');
    });

    test('timeout messages keep their already-clean wording in release', () {
      const timeout =
          'Request timed out. Please check your connection and try again.';
      expect(ApiService.userMessage(timeout, debug: false), timeout);
    });

    test('technical text not at the start of the message is not stripped', () {
      const mid = 'Refresh failed. Connection failed details logged internally.';
      expect(ApiService.userMessage(mid, debug: false), mid);
    });
  });
}