import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/startup/presentation/startup_page.dart';

void main() {
  testWidgets('startup animation transitions to the guest-ready home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupPage(
          onReady: (_) => const Scaffold(body: Text('Home ready')),
        ),
      ),
    );

    expect(find.text('Emergency'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Home ready'), findsOneWidget);
  });
}
