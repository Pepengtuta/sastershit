import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_saster/services/api_service.dart';
import 'package:flutter_saster/services/auth_service.dart';
import 'package:flutter_saster/services/offline_sync_coordinator.dart';

class _MemStore implements OfflineSyncStore {
  final data = <int, OfflineSyncRecord>{};

  @override
  Future<OfflineSyncRecord> read(int userId) async =>
      data[userId] ?? const OfflineSyncRecord();

  @override
  Future<void> write(int userId, OfflineSyncRecord record) async {
    data[userId] = record;
  }
}

OfflineSyncDatasetResult _ok(String name) =>
    OfflineSyncDatasetResult(name: name, ok: true);

OfflineSyncDatasetResult _fail(String name) =>
    OfflineSyncDatasetResult(name: name, ok: false);

void main() {
  setUp(() {
    AuthService.currentUser = {
      'id': 1,
      'role': 'barangay',
      'barangay_name': 'Andagaw',
      'municipality': 'Kalibo',
    };
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('syncNow is single-flight: concurrent triggers share one run', () async {
    final store = _MemStore();
    var runs = 0;
    final gate = Completer<void>();
    final coordinator = OfflineSyncCoordinator(
      store: store,
      hasNetwork: () async => true,
      connectivityChanges: const Stream.empty(),
      runDatasets: () async {
        runs++;
        await gate.future;
        return [_ok('hotlines')];
      },
    );

    final first = coordinator.syncNow();
    final second = coordinator.syncNow();
    final third = coordinator.syncNow();

    gate.complete();
    await Future.wait([first, second, third]);

    expect(runs, 1);
    expect(coordinator.status.ready, isTrue);
    expect(coordinator.status.lastSyncedAt, isNotNull);
  });

  test('no network: no datasets run and no failure is recorded', () async {
    final store = _MemStore();
    var runs = 0;
    final coordinator = OfflineSyncCoordinator(
      store: store,
      hasNetwork: () async => false,
      connectivityChanges: const Stream.empty(),
      runDatasets: () async {
        runs++;
        return [_ok('hotlines')];
      },
    );

    await coordinator.syncNow();

    expect(runs, 0);
    expect(coordinator.status.neverSynced, isTrue);
    expect(store.data.containsKey(1), isFalse);
  });

  test('partial failures surface as "some data could not be updated"',
      () async {
    final store = _MemStore();
    final coordinator = OfflineSyncCoordinator(
      store: store,
      hasNetwork: () async => true,
      connectivityChanges: const Stream.empty(),
      runDatasets: () async => [_ok('hotlines'), _fail('map markers')],
    );

    await coordinator.syncNow();

    expect(coordinator.status.running, isFalse);
    expect(coordinator.status.partial, isTrue);
    expect(coordinator.status.hadFailures, isTrue);
    expect(coordinator.status.lastSyncedAt, isNotNull);
    expect(store.data[1]!.hadFailures, isTrue);
  });

  test('skipped datasets never count as failures', () async {
    final store = _MemStore();
    final coordinator = OfflineSyncCoordinator(
      store: store,
      hasNetwork: () async => true,
      connectivityChanges: const Stream.empty(),
      runDatasets: () async => [
        _ok('hotlines'),
        const OfflineSyncDatasetResult(
          name: 'assistance board',
          ok: false,
          attempted: false,
        ),
      ],
    );

    await coordinator.syncNow();

    expect(coordinator.status.ready, isTrue);
    expect(coordinator.status.hadFailures, isFalse);
  });

  test('a failed run keeps the previous last-synced time', () async {
    final store = _MemStore();
    store.data[1] = OfflineSyncRecord(
      lastSyncedAt: DateTime(2026, 9, 21, 10, 0),
      hadFailures: false,
    );
    final coordinator = OfflineSyncCoordinator(
      store: store,
      hasNetwork: () async => true,
      connectivityChanges: const Stream.empty(),
      runDatasets: () async => [_fail('hotlines'), _fail('map markers')],
    );

    await coordinator.refreshFromStore();
    await coordinator.syncNow();

    expect(coordinator.status.lastSyncedAt, DateTime(2026, 9, 21, 10, 0));
    expect(coordinator.status.partial, isTrue);
    expect(store.data[1]!.lastSyncedAt, DateTime(2026, 9, 21, 10, 0));
  });

  test('connectivity restores are debounced', () async {
    final controller = StreamController<List<ConnectivityResult>>.broadcast();
    final store = _MemStore();
    var runs = 0;
    final coordinator = OfflineSyncCoordinator(
      store: store,
      hasNetwork: () async => true,
      connectivityChanges: controller.stream,
      debounce: const Duration(milliseconds: 20),
      pinger: () async => true,
      runDatasets: () async {
        runs++;
        return [_ok('hotlines')];
      },
    );

    await coordinator.start(); // initial sync
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final baseline = runs;
    expect(baseline, 1);

    for (var i = 0; i < 5; i++) {
      controller.add([ConnectivityResult.wifi]);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(runs, baseline + 1);
    await controller.close();
  });

  test('starts silently when no user is signed in', () async {
    AuthService.currentUser = null;
    var runs = 0;
    final coordinator = OfflineSyncCoordinator(
      store: _MemStore(),
      hasNetwork: () async => true,
      connectivityChanges: const Stream.empty(),
      runDatasets: () async {
        runs++;
        return [_ok('hotlines')];
      },
    );

    await coordinator.start();
    expect(runs, 0);
  });

  test('SharedPreferencesOfflineSyncStore round-trips a record', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesOfflineSyncStore();
    final when = DateTime(2026, 9, 21, 9, 30);

    await store.write(
      7,
      OfflineSyncRecord(lastSyncedAt: when, hadFailures: true),
    );
    final read = await store.read(7);

    expect(read.hadFailures, isTrue);
    expect(read.lastSyncedAt, when);
  });

  test('forEachConcurrent caps the number of in-flight tasks', () async {
    var active = 0;
    var maxActive = 0;
    await forEachConcurrent(List.generate(10, (i) => i), 4, (_) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active--;
    });
    expect(maxActive, lessThanOrEqualTo(4));
    expect(active, 0);
  });

  group('api reachability recovery', () {
    test('a restore drives unreachable -> checking -> reachable and resyncs',
        () async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      final store = _MemStore();
      var reachable = false;
      var runs = 0;
      final coordinator = OfflineSyncCoordinator(
        store: store,
        hasNetwork: () async => true,
        connectivityChanges: controller.stream,
        debounce: const Duration(milliseconds: 20),
        probeDelays: const [Duration(seconds: 1)],
        pinger: () async => reachable,
        runDatasets: () async {
          runs++;
          return [_ok('hotlines')];
        },
      );

      final states = <ApiReachabilityStatus>[];
      coordinator.addListener(() => states.add(coordinator.apiStatus));

      await coordinator.start(); // initial sync: status starts unknown
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Simulate the host going dark.
      await coordinator.retryConnection();
      expect(coordinator.apiStatus, ApiReachabilityStatus.unreachable);
      expect(states.contains(ApiReachabilityStatus.checking), isTrue);

      // Wi-Fi comes back: the listener fires and coordinates a retry.
      reachable = true;
      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(coordinator.apiStatus, ApiReachabilityStatus.reachable);
      final idxUnreachable = states.indexOf(ApiReachabilityStatus.unreachable);
      final idxChecking = states.lastIndexOf(ApiReachabilityStatus.checking);
      final idxReachable = states.lastIndexOf(ApiReachabilityStatus.reachable);
      expect(idxUnreachable, isNot(-1));
      expect(idxChecking, greaterThan(idxUnreachable),
          reason: 'restore must flip unreachable back to checking first');
      expect(idxReachable, greaterThan(idxChecking));
      expect(runs, greaterThanOrEqualTo(2));
      expect(coordinator.status.ready, isTrue);

      await controller.close();
      coordinator.dispose();
    });

    test('health checks keep retrying until the host answers', () async {
      var pings = 0;
      var answerAt = 3; // fail twice, then answer
      final store = _MemStore();
      final coordinator = OfflineSyncCoordinator(
        store: store,
        hasNetwork: () async => true,
        connectivityChanges: const Stream.empty(),
        probeDelays: const [
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
        ],
        pinger: () async {
          pings++;
          return pings >= answerAt;
        },
        runDatasets: () async => [_ok('hotlines')],
      );

      unawaited(coordinator.retryConnection());

      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (coordinator.apiStatus != ApiReachabilityStatus.reachable &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(coordinator.apiStatus, ApiReachabilityStatus.reachable);
      expect(pings, greaterThanOrEqualTo(answerAt));
      expect(coordinator.status.ready, isTrue);
      coordinator.dispose();
    });

    test('a throwing dataset runner still releases the sync slot', () async {
      final store = _MemStore();
      var calls = 0;
      final coordinator = OfflineSyncCoordinator(
        store: store,
        hasNetwork: () async => true,
        connectivityChanges: const Stream.empty(),
        runDatasets: () async {
          calls++;
          if (calls == 1) throw StateError('boom');
          return [_ok('hotlines')];
        },
      );

      await coordinator.syncNow(); // throws internally, never escapes
      expect(coordinator.status.running, isFalse);

      await coordinator.syncNow(); // slot was released in finally
      expect(calls, 2);
      expect(coordinator.status.ready, isTrue);
    });

    test('resume and connectivity restore funnel into ONE coordinated retry',
        () async {
      final store = _MemStore();
      var pings = 0;
      var runs = 0;
      final coordinator = OfflineSyncCoordinator(
        store: store,
        hasNetwork: () async => true,
        connectivityChanges: const Stream.empty(),
        pinger: () async {
          pings++;
          return true;
        },
        runDatasets: () async {
          runs++;
          return [_ok('hotlines')];
        },
      );

      final resumed = coordinator.handleAppResumed();
      final fromConnectivity = coordinator.retryConnection();
      await Future.wait([resumed, fromConnectivity]);

      expect(pings, 1, reason: 'resume + restore must share one retry');
      expect(runs, 1);
      expect(coordinator.apiStatus, ApiReachabilityStatus.reachable);
      coordinator.dispose();
    });

    test('a No route to host failure opens the breaker and never blocks later '
        'retries', () async {
      final dead = await _bindDeadPort();
      final port = dead;

      // Real ApiService failure -> coordinator callback -> unreachable.
      final store = _MemStore();
      var pings = 0;
      final coordinator = OfflineSyncCoordinator(
        store: store,
        hasNetwork: () async => true,
        connectivityChanges: const Stream.empty(),
        probeDelays: const [Duration(seconds: 1)],
        pinger: () async {
          pings++;
          return true;
        },
        runDatasets: () async => [_ok('hotlines')],
      );
      await coordinator.start();

      final result = await ApiService.getJson(url: 'http://127.0.0.1:$port/x.php');
      expect(result['success'], isFalse);
      expect(ApiService.isConnectionFailure(message: result['message'] as String),
          isTrue);
      expect(coordinator.apiStatus, ApiReachabilityStatus.unreachable);
      expect(ApiService.isApiUnreachable, isTrue);

      // A retry clears the breaker and probes again (this pinger succeeds).
      await coordinator.retryConnection();
      expect(pings, 1);
      expect(coordinator.apiStatus, ApiReachabilityStatus.reachable);
      expect(ApiService.isApiUnreachable, isFalse,
          reason: 'recovery must never stay stuck on the old failure');

      coordinator.dispose();
      ApiService.resetApiBreaker();
    });
  });
}

Future<int> _bindDeadPort() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close(force: true);
  return port;
}