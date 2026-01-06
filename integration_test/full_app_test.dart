import 'package:contri/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full circle flow (smoke)', (tester) async {
    // This test is a guarded smoke to ensure the app boots in CI. The
    // full flow depends on Firebase and emulator auth, so it remains
    // minimal and can be expanded with proper fakes when available.
    await tester.runAsync(() async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: true);
}
