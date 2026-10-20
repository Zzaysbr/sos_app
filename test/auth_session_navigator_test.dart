import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/auth/presentation/auth_session_navigator.dart';

void main() {
  testWidgets(
    'account changes remove retained maps, details and dialogs; same session keeps routes',
    (tester) async {
      String owner = 'A';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AuthSessionNavigator(
                ownerId: owner,
                home: (sessionContext) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(sessionContext).push<void>(
                      MaterialPageRoute<void>(
                        builder: (detailContext) => Scaffold(
                          body: TextButton(
                            onPressed: () => showDialog<void>(
                              context: detailContext,
                              useRootNavigator: false,
                              builder: (_) => const AlertDialog(
                                content: Text('A private dialog'),
                              ),
                            ),
                            child: const Text('A private details/map'),
                          ),
                        ),
                      ),
                    ),
                    child: Text('Home $owner'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Home A'));
      await tester.pumpAndSettle();
      update(() {}); // Cancelled/failed sign-in does not replace the session.
      await tester.pumpAndSettle();
      expect(find.text('A private details/map'), findsOneWidget);
      await tester.tap(find.text('A private details/map'));
      await tester.pumpAndSettle();
      expect(find.text('A private dialog'), findsOneWidget);
      update(() => owner = 'B');
      await tester.pumpAndSettle();
      expect(find.text('Home B'), findsOneWidget);
      expect(find.text('A private dialog'), findsNothing);
      expect(find.text('A private details/map'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
