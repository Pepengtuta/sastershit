import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_saster/main.dart';
import 'package:flutter_saster/screens/login_screen.dart';

void main() {
  testWidgets('app boots to the login screen when no session is saved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SasterApp());

    // Let AuthService.restoreSession() resolve.
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
