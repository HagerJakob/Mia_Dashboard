import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_buddy/app/app.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/presentation/dashboard_controller.dart';

void main() {
  testWidgets(
    'calendar opens, ESC repeats, saves and cancels on Windows layout',
    (tester) async {
      await initializeDateFormatting('de_AT');
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyBuddyRepositoryProvider.overrideWithValue(
              InMemoryStudyBuddyRepository(),
            ),
          ],
          child: const StudyBuddyApp(),
        ),
      );
      await tester.tap(find.text('Kalender').first);
      await tester.pumpAndSettle();
      expect(find.text('Neuer Termin'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Neuer Termin'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'Mathematik');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('Neuer Termin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Mathematik');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mathematik'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Neuer Termin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile calendar and editor fit without overflow', (
    tester,
  ) async {
    await initializeDateFormatting('de_AT');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyBuddyRepositoryProvider.overrideWithValue(
            InMemoryStudyBuddyRepository(),
          ),
        ],
        child: const StudyBuddyApp(),
      ),
    );
    await tester.tap(find.text('Kalender').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Neuer Termin'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Neuer Termin'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
