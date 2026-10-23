// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_saster/screens/shared/assistance_board_screen.dart';
import 'package:flutter_saster/services/assistance_repository.dart';
import 'package:flutter_saster/services/auth_service.dart';
import 'package:flutter_saster/widgets/loading_view.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

/// Injectable stand-in for [AssistanceRepository].
///
/// Injects via the mutable [AssistanceRepository.instance] static, exactly as
/// create_incident_first_open_test.dart does for its repository.
class _FakeAssistanceRepository implements AssistanceRepository {
  int cachedBoardCalls = 0;
  int refreshBoardCalls = 0;

  /// When set, [getCachedBoard] stays in flight until the test completes it.
  /// This is what makes "load in progress" observable: the fake would otherwise
  /// resolve in a microtask and the guard could never be exercised.
  Completer<void>? cacheGate;

  @override
  Future<AssistanceBoardLoadResult> getCachedBoard({
    required int userId,
    required String role,
    String? municipality,
  }) async {
    cachedBoardCalls++;
    final gate = cacheGate;
    if (gate != null) await gate.future;
    return const AssistanceBoardLoadResult();
  }

  @override
  Future<AssistanceBoardLoadResult> refreshBoard({
    required int userId,
    required String role,
    String? municipality,
  }) async {
    refreshBoardCalls++;
    return const AssistanceBoardLoadResult(offline: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Drains every timer that loadBoard() can leave behind:
///   - getCachedBoard.timeout  → 8 s
///   - _isNetworkAvailable.timeout → 5 s
///
/// In the test binding connectivity_plus usually fails fast (no plugin host),
/// which lands in loadBoard's catch block; if it ever hangs instead, the 5 s
/// timeout resolves it. Pumping past both keeps FakeAsync free of pending
/// timers at teardown.
///
/// We do NOT use pumpAndSettle because [CircularProgressIndicator] is an
/// infinite animation that causes pumpAndSettle to time out.
Future<void> _drainLoadBoard(WidgetTester tester) async {
  // One regular frame lets initState's synchronous kick complete.
  await tester.pump();
  // Drive past the 8-s getCachedBoard timeout.
  await tester.pump(const Duration(seconds: 8));
  // Drive past the 5-s connectivity timeout.
  await tester.pump(const Duration(seconds: 5));
  // One more frame to let setState / build settle.
  await tester.pump();
}

/// Swallows [MissingPluginException] and ink-splash warnings that appear when
/// Flutter widgets run under the test binding without a platform host.
void _swallowBenignErrors() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is MissingPluginException) return;
    final text = details.toString();
    if (text.contains('ink splashes')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAssistanceRepository fakeRepo;
  late AssistanceRepository originalRepo;

  setUp(() {
    fakeRepo = _FakeAssistanceRepository();
    originalRepo = AssistanceRepository.instance;
    AssistanceRepository.instance = fakeRepo;

    // AuthService.currentUser is an in-memory map — safe to set in tests
    // without any plugin (same pattern as create_incident_first_open_test.dart).
    AuthService.currentUser = {
      'id': 1,
      'username': 'testpcf',
      'name': 'Test PCF',
      'role': 'pcf',
      'sub_role': '',
      'municipality': 'Kalibo',
    };
  });

  tearDown(() {
    AssistanceRepository.instance = originalRepo;
    AuthService.currentUser = null;
  });

  // ── Test 1 ────────────────────────────────────────────────────────────────
  testWidgets(
    'initState fires loadBoard() immediately — getCachedBoard called without '
    'any user interaction (verifies the bug fix)',
    (tester) async {
      _swallowBenignErrors();
      // Hold the load open so the screen is genuinely mid-load when asserted.
      fakeRepo.cacheGate = Completer<void>();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssistanceBoardScreen())),
      );
      await tester.pump();

      // isLoading is true while the gated cache read is in flight.
      expect(find.byType(LoadingView), findsOneWidget,
          reason: 'Screen must start in loading state after initState');

      // THE key assertion for the bug fix: getCachedBoard was called from
      // initState — no tap, resume event, or refreshToken bump. Before the
      // fix this counter stayed at 0 and the screen spun forever.
      expect(
        fakeRepo.cachedBoardCalls,
        1,
        reason:
            'loadBoard() must be triggered by initState; counter was 0 before '
            'the fix (the bug).',
      );

      fakeRepo.cacheGate!.complete();
      await _drainLoadBoard(tester);
    },
  );

  // ── Test 2 ────────────────────────────────────────────────────────────────
  testWidgets(
    'after load completes the screen exits the spinner — never stuck spinning',
    (tester) async {
      _swallowBenignErrors();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssistanceBoardScreen())),
      );

      // Drain all timers so the async chain reaches its end.
      await _drainLoadBoard(tester);

      // The test binding has no connectivity plugin, so checkConnectivity
      // throws, loadBoard catches it, and with no cache it shows the error.
      expect(find.byType(LoadingView), findsNothing,
          reason: 'Spinner must be gone once the load path completes');

      // ErrorState renders an ElevatedButton labelled 'Retry'.
      expect(
        find.widgetWithText(ElevatedButton, 'Retry'),
        findsOneWidget,
        reason: 'ErrorState with Retry button must be visible',
      );
    },
  );

  // ── Test 3 ────────────────────────────────────────────────────────────────
  testWidgets(
    '_loadInProgress guard prevents double load when didUpdateWidget arrives '
    'while the first load is still in-flight',
    (tester) async {
      _swallowBenignErrors();
      fakeRepo.cacheGate = Completer<void>();

      Widget build(int token) => MaterialApp(
            home: Scaffold(
              body: AssistanceBoardScreen(
                key: const ValueKey('assistance-board'),
                refreshToken: token,
              ),
            ),
          );

      await tester.pumpWidget(build(0));
      await tester.pump();

      // The first load is still blocked inside getCachedBoard.
      expect(fakeRepo.cachedBoardCalls, 1);

      // Bump the token on the same State (didUpdateWidget → loadBoard).
      // The guard must see _loadInProgress == true and return early.
      await tester.pumpWidget(build(1));
      await tester.pump();

      expect(
        fakeRepo.cachedBoardCalls,
        1,
        reason:
            '_loadInProgress flag must suppress the re-entrant didUpdateWidget '
            'call while the first load is still in flight',
      );

      fakeRepo.cacheGate!.complete();
      await _drainLoadBoard(tester);
    },
  );
}
