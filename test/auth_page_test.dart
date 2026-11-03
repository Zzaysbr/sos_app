import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/features/auth/data/auth_service.dart';
import 'package:sos_app/features/auth/presentation/auth_page.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService auth;

  setUp(() => auth = MockAuthService());

  Future<void> openReset(WidgetTester tester) async {
    await tester.pumpWidget(_app(auth));
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'person@example.com');
  }

  testWidgets('shows loading and prevents duplicate reset requests', (
    tester,
  ) async {
    final request = Completer<void>();
    when(() => auth.resetPassword(email: any(named: 'email')))
        .thenAnswer((_) => request.future);
    await openReset(tester);

    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    expect(find.text('Sending reset link…'), findsOneWidget);
    verify(() => auth.resetPassword(email: 'person@example.com')).called(1);

    await tester.tap(find.text('Sending reset link…'));
    verifyNever(() => auth.resetPassword(email: 'person@example.com'));
    request.complete();
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
  });

  testWidgets('shows neutral success state after Firebase completes', (
    tester,
  ) async {
    when(() => auth.resetPassword(email: any(named: 'email')))
        .thenAnswer((_) async {});
    await openReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('person@example.com'), findsNWidgets(2));
    expect(find.text('Resend in 30s'), findsOneWidget);
  });

  testWidgets('maps Firebase errors and allows retry', (tester) async {
    var attempts = 0;
    when(() => auth.resetPassword(email: any(named: 'email')))
        .thenAnswer((_) async {
          attempts++;
          if (attempts == 1) {
            throw const AuthException('Network error. Check your connection.');
          }
        });
    await openReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network error'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('validates email before calling Firebase', (tester) async {
    await tester.pumpWidget(_app(auth));
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    verifyNever(() => auth.resetPassword(email: any(named: 'email')));
  });
}

Widget _app(AuthService auth) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: AuthPage(authService: auth),
);
