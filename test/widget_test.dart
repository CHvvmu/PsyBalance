// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:psy_balance/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'example-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  testWidgets('App widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PsyBalanceApp());
    await tester.pumpAndSettle();
    expect(find.byType(PsyBalanceApp), findsOneWidget);
  });
}
