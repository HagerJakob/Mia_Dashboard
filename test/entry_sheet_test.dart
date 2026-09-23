import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/features/dashboard/presentation/dashboard_controller.dart';
import 'package:study_buddy/features/dashboard/presentation/widgets/add_entry_sheet.dart';

void main() {
  final forms =
      <String, Future<void> Function(BuildContext, StudyBuddyController)>{
        'Aufgabe': showTaskSheet,
        'Termin': showScheduleSheet,
        'Notiz': showNoteSheet,
        'Fach': showSubjectSheet,
        'Prüfung': showExamSheet,
        'Erinnerung': showReminderSheet,
      };

  for (final entry in forms.entries) {
    testWidgets('${entry.key}: ESC closes repeatedly while editing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => entry.value(
                    context,
                    ref.read(studyBuddyControllerProvider.notifier),
                  ),
                  child: const Text('Oeffnen'),
                ),
              ),
            ),
          ),
        ),
      );

      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Oeffnen'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(
          attempt == 1 && fields.evaluate().length > 1
              ? fields.last
              : fields.first,
          'Eintrag',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('Oeffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Schließen'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Oeffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
