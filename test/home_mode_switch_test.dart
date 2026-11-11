import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/features/role/domain/app_role.dart';
import 'package:sos_app/features/role/presentation/home_mode_switch.dart';

void main() {
  testWidgets(
    'icon-only mode switch retains accessible Thai labels and toggles both roles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      var role = AppRole.needHelp;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('th'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HomeModeSwitch(
                role: role,
                onChanged: () => setState(() {
                  role = role == AppRole.needHelp
                      ? AppRole.rescue
                      : AppRole.needHelp;
                }),
              ),
            ),
          ),
        ),
      );
      expect(find.text('โหมดขอความช่วยเหลือ'), findsNothing);
      expect(find.bySemanticsLabel('โหมดขอความช่วยเหลือ'), findsOneWidget);
      expect(tester.getSize(find.byType(HomeModeSwitch)), const Size(100, 52));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(HomeModeSwitch));
      await tester.pumpAndSettle();
      expect(find.text('โหมดกู้ภัย'), findsNothing);
      expect(find.bySemanticsLabel('โหมดกู้ภัย'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(HomeModeSwitch));
      await tester.pumpAndSettle();
      expect(find.text('โหมดขอความช่วยเหลือ'), findsNothing);
      expect(find.bySemanticsLabel('โหมดขอความช่วยเหลือ'), findsOneWidget);
      semantics.dispose();
    },
  );
}
