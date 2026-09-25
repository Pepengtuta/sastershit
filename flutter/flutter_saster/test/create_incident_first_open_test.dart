import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/screens/barangay/create_incident_screen.dart';
import 'package:flutter_saster/services/auth_service.dart';
import 'package:flutter_saster/services/create_incident_cache_database.dart';
import 'package:flutter_saster/services/create_incident_repository.dart';

/// Every request (tile GETs and API POSTs alike) is refused with HTTP 400:
///
/// - API POSTs -> `ApiService` reports `success == false`, exactly like the
///   server being unreachable offline, so the reference-data refreshes end in
///   their offline fallback (which must NOT clear what the cache loaded).
/// - Map tile GETs -> fail to decode instead of crashing, and because the
///   flutter_map built-in tile cache is only touched AFTER a tile downloads,
///   refusing the download keeps that code path (which calls path_provider and
///   can only run in a real async zone) out of the widget test entirely.
class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(url, method: method);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeHttpClient.${invocation.memberName}');
  }
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.url, {this.method = 'GET'});

  final Uri url;
  @override
  final String method;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(400, const <int>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, this._bytes);

  @override
  final int statusCode;
  final List<int> _bytes;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final controller = Stream<List<int>>.fromIterable([_bytes]);
    return controller.listen(
      onData,
      onError: onError as void Function(Object)?,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Injectable stand-in for the reference-data repository.
///
/// The screen reads through `CreateIncidentRepository.instance`; replacing it
/// lets the widget tests drive the exact cache-first screen behavior
/// deterministically. The real SQLite read path (which the app reaches when
/// initState runs in a real async zone, just like `tester.runAsync`) is
/// verified separately below against the actual database.
class _FakeIncidentRepository extends CreateIncidentRepository {
  _FakeIncidentRepository({
    this.types = const [],
    this.centers = const [],
  });

  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> centers;

  /// Counts background refresh attempts so the test can prove the screen
  /// fired them while still showing the cached rows.
  int refreshCalls = 0;

  @override
  Future<CreateIncidentReferenceResult> getCachedDisasterTypes() async =>
      CreateIncidentReferenceResult(rows: types, hasCache: types.isNotEmpty);

  @override
  Future<CreateIncidentReferenceResult> getCachedEvacuationCenters({
    int? barangayId,
    String? barangayName,
  }) async =>
      CreateIncidentReferenceResult(
        rows: centers,
        hasCache: centers.isNotEmpty,
      );

  @override
  Future<CreateIncidentReferenceResult> refreshDisasterTypes() async {
    refreshCalls++;
    return const CreateIncidentReferenceResult(
      offline: true,
      message: 'offline (simulated)',
    );
  }

  @override
  Future<CreateIncidentReferenceResult> refreshEvacuationCenters({
    int? barangayId,
    String? barangayName,
  }) async {
    refreshCalls++;
    return const CreateIncidentReferenceResult(
      offline: true,
      message: 'offline (simulated)',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    AuthService.currentUser = {
      'id': 1,
      'username': 'tanod',
      'name': 'Tanod',
      'role': 'barangay',
      'sub_role': 'tanod',
      'barangay_id': 7,
      'barangay_name': 'Andagaw',
      'municipality': 'Kalibo',
      'population': 5000,
      'can_manage_users': 0,
    };
  });

  tearDown(() {
    AuthService.currentUser = null;
    CreateIncidentRepository.instance = CreateIncidentRepository();
  });

  const cachedTypes = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Typhoon', 'is_natural': 1},
    {'id': 3, 'name': 'Earthquake', 'is_natural': 0},
  ];
  const cachedCenters = <Map<String, dynamic>>[
    {'id': 9, 'center_name': 'Aklan State University', 'status': 'Available'},
  ];

  /// The test binding installs its own FlutterError.onError around each test
  /// body, so benign framework diagnostics from PRE-EXISTING app/widget logic
  /// (not the offline cache work) must be filtered inside the body. Without
  /// this, rendering the real Create Incident screen in a widget test fails:
  /// - ListTile inside the app's DecoratedBox-styled InfoCard reports the
  ///   "ink splashes may be invisible" debug assertion.
  /// - tile image GETs refuse with 400 -> network image decode failures.
  /// - plugin channels (geolocator, path_provider) throw MissingPluginException.
  void swallowBenignFlutterErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('ink splashes')) return;
      if (details.exception is MissingPluginException) return;
      if (text.contains('ImageCodecException') || text.contains('statusCode')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
  }

  Future<void> settle(WidgetTester tester) async {
    // Several pumps: cached rows are set right after the first cache read, and
    // the background iterations let the offline refreshes finish.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// The Create Incident form is a lazy ListView longer than the default
  /// 800x600 test surface, so fields below the fold are never built and the
  /// finders cannot see them. A tall viewport builds the whole form and lets
  /// the dropdown taps land on real coordinates.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openMenu(WidgetTester tester, int index) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectFromOpenMenu(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'first offline opening with a populated cache shows disaster types and '
      'evacuation centers immediately, without network or reopen',
      (tester) async {
    swallowBenignFlutterErrors();
    useTallViewport(tester);

    final repo = _FakeIncidentRepository(
      types: cachedTypes,
      centers: cachedCenters,
    );
    CreateIncidentRepository.instance = repo;

    await tester.pumpWidget(const MaterialApp(home: CreateIncidentScreen()));
    await settle(tester);

    // Cache populated the UI on this very first build: no "first use offline"
    // message, and the disaster type dropdown is present and selectable.
    expect(
      find.textContaining('unavailable offline on first use'),
      findsNothing,
    );
    expect(find.text('Disaster Type'), findsOneWidget);

    await openMenu(tester, 0);
    expect(find.text('Typhoon'), findsWidgets);
    expect(find.text('Earthquake'), findsWidgets);
    await selectFromOpenMenu(tester, 'Typhoon');
    await settle(tester);

    // The background refresh fired (it must have, since the cache read itself
    // cannot set the loading flag to false on an empty cache), and being a
    // failed offline refresh it must have left the cached rows untouched.
    expect(repo.refreshCalls, greaterThan(0));
    expect(find.text('Disaster Type'), findsOneWidget);

    // Enable evacuation: the cached center appears with no offline card.
    await openMenu(tester, 1);
    await selectFromOpenMenu(tester, 'Yes');
    await settle(tester);

    expect(
      find.textContaining('unavailable offline on first use'),
      findsNothing,
    );
    expect(find.text('Evacuation Center'), findsOneWidget);

    // The evacuation center dropdown is a DropdownButtonFormField<int>.
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aklan State University'), findsWidgets);
    await selectFromOpenMenu(tester, 'Aklan State University');
    await settle(tester);
  });

  testWidgets('empty cache plus offline refresh shows the first-use message, '
      'and reopening after a successful refresh behaves identically',
      (tester) async {
    swallowBenignFlutterErrors();
    useTallViewport(tester);

    // First open, empty cache, offline: the message appears and the form can
    // be explicitly retried.
    CreateIncidentRepository.instance = _FakeIncidentRepository();
    await tester.pumpWidget(
      MaterialApp(home: CreateIncidentScreen(key: const ValueKey('first'))),
    );
    await settle(tester);
    expect(
      find.textContaining('unavailable offline on first use'),
      findsOneWidget,
    );

    // Simulate a fresh "reopen" after the cache became populated: a different
    // key forces a brand new State (initState -> cache-read-first) instead of
    // Flutter reusing the previous screen instance.
    final repo = _FakeIncidentRepository(types: cachedTypes);
    CreateIncidentRepository.instance = repo;
    await tester.pumpWidget(
      MaterialApp(home: CreateIncidentScreen(key: const ValueKey('second'))),
    );
    await settle(tester);
    expect(
      find.textContaining('unavailable offline on first use'),
      findsNothing,
    );
    expect(find.text('Disaster Type'), findsOneWidget);

    await openMenu(tester, 0);
    expect(find.text('Typhoon'), findsWidgets);
  });

  testWidgets('the real SQLite cache read returns the seeded rows',
      (tester) async {
    // The widget tests drive screen behavior with an injectable repository
    // because sqflite's isolate-backed futures cannot complete under FakeAsync
    // once initState (fake zone) starts the read. On a device initState runs in
    // a real async zone — the exact conditions this runAsync block reproduces —
    // so this test proves the persistent cache path the app really uses.
    var typesHasCache = false;
    var centersHasCache = false;
    var firstType = '';
    var firstCenter = '';

    await tester.runAsync(() async {
      final cache = CreateIncidentCacheDatabase.instance;
      await cache.replaceDisasterTypes(
        rows: cachedTypes,
        updatedAt: DateTime.now(),
      );
      await cache.replaceEvacuationCenters(
        barangayId: 7,
        barangayName: 'Andagaw',
        rows: cachedCenters,
        updatedAt: DateTime.now(),
      );

      final types =
          await CreateIncidentRepository.instance.getCachedDisasterTypes();
      typesHasCache = types.hasCache;
      firstType = types.rows.isNotEmpty
          ? types.rows.first['name']?.toString() ?? ''
          : '';

      final centers = await CreateIncidentRepository.instance
          .getCachedEvacuationCenters(barangayId: 7, barangayName: 'Andagaw');
      centersHasCache = centers.hasCache;
      firstCenter = centers.rows.isNotEmpty
          ? centers.rows.first['center_name']?.toString() ?? ''
          : '';
    });

    expect(typesHasCache, isTrue);
    expect(firstType, 'Typhoon');
    expect(centersHasCache, isTrue);
    expect(firstCenter, 'Aklan State University');
  });
}