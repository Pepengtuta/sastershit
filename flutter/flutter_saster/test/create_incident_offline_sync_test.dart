import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_saster/services/auth_service.dart';
import 'package:flutter_saster/services/create_incident_repository.dart';
import 'package:flutter_saster/services/offline_sync_coordinator.dart';

/// Every API request is refused with HTTP 400 so the real singleton
/// repositories fail fast exactly like being offline, while the injected
/// Create Incident repository drives the dataset under test.
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

/// Injectable stand-in for the reference-data repository so the sync step can
/// be exercised without any SQLite or network setup for its own endpoints.
class _FakeCreateIncidentRepository extends CreateIncidentRepository {
  int? evacBarangayId;
  String? evacBarangayName;

  @override
  Future<CreateIncidentReferenceResult> refreshEvacuationCenters({
    int? barangayId,
    String? barangayName,
  }) async {
    evacBarangayId = barangayId;
    evacBarangayName = barangayName;
    return const CreateIncidentReferenceResult(
      rows: [
        {'id': 9, 'center_name': 'Aklan State University', 'status': 'Available'},
      ],
      hasCache: true,
    );
  }

  @override
  Future<CreateIncidentReferenceResult> refreshDisasterTypes() async {
    return const CreateIncidentReferenceResult(
      rows: [{'id': 1, 'name': 'Typhoon', 'is_natural': 1}],
      hasCache: true,
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

  tearDown(() {
    HttpOverrides.global = null;
    AuthService.currentUser = null;
    CreateIncidentRepository.instance = CreateIncidentRepository();
  });

  Map<String, dynamic> barangayUser() => {
        'id': 1,
        'username': 'tanod',
        'name': 'Tanod',
        'role': 'barangay',
        'sub_role': 'tanod',
        'barangay_id': 7,
        'barangay_name': 'Andagaw',
        'municipality': 'Kalibo',
      };

  OfflineSyncDatasetResult datasetOf(
    List<OfflineSyncDatasetResult> results,
  ) =>
      results.firstWhere(
        (r) => r.name == 'create incident evacuation centers',
      );

  test('barangay users pre-cache Create Incident evacuation centers',
      () async {
    AuthService.currentUser = barangayUser();
    final fake = _FakeCreateIncidentRepository();
    CreateIncidentRepository.instance = fake;

    final results = await defaultOfflineDatasets();

    final dataset = datasetOf(results);
    expect(dataset.attempted, isTrue);
    expect(dataset.ok, isTrue);
    expect(fake.evacBarangayId, 7);
    expect(fake.evacBarangayName, 'Andagaw');
  });

  test('admin roles skip the Create Incident evacuation centers dataset',
      () async {
    AuthService.currentUser = {
      ...barangayUser(),
      'role': 'pcf',
      'barangay_id': null,
      'barangay_name': null,
    };
    final fake = _FakeCreateIncidentRepository();
    CreateIncidentRepository.instance = fake;

    final results = await defaultOfflineDatasets();

    final dataset = datasetOf(results);
    expect(dataset.attempted, isFalse);
    expect(fake.evacBarangayId, isNull);
    expect(fake.evacBarangayName, isNull);
  });
}