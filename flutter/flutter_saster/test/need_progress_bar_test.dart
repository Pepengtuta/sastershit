import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_saster/widgets/need_progress_bar.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    int needed = 100,
    int received = 60,
    String unit = 'liters',
    bool fulfilled = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: NeedProgressBar(needed: needed, received: received, unit: unit, fulfilled: fulfilled)),
          ),
        ),
      ),
    );
  }

  testWidgets('phone width (360px): no overflow, both lines present', (tester) async {
    await pumpAt(tester, 360, needed: 100, received: 60, unit: 'liters', fulfilled: false);
    expect(tester.takeException(), isNull, reason: 'narrow phone width must not overflow or clip');
    expect(find.textContaining('Received 60 / needed 100 liters'), findsOneWidget);
    expect(find.textContaining('unmet 40'), findsOneWidget);
  });

  testWidgets('tablet width (800px): one line, no overflow', (tester) async {
    await pumpAt(tester, 800, needed: 100, received: 100, unit: 'liters', fulfilled: true);
    expect(tester.takeException(), isNull, reason: 'tablet width must not overflow');
    expect(find.textContaining('Received 100 / needed 100 liters'), findsOneWidget);
    expect(find.textContaining('unmet 0'), findsOneWidget);
  });

  testWidgets('very narrow (320px) with tight values: no overflow', (tester) async {
    await pumpAt(tester, 320, needed: 50, received: 10, unit: 'pcs', fulfilled: false);
    expect(tester.takeException(), isNull, reason: '320px width must not overflow or clip');
    expect(find.textContaining('Received 10 / needed 50 pcs'), findsOneWidget);
    expect(find.textContaining('unmet 40'), findsOneWidget);
  });

  testWidgets('incoming line rendered when positive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: NeedProgressBar(needed: 100, received: 60, unit: 'liters', incoming: 20),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Incoming (pledged): 20 liters'), findsOneWidget);
  });
}