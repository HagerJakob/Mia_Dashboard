import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rrule/rrule.dart';
import 'package:study_buddy/app/app.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/presentation/dashboard_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('subject page creates subject and recurring calendar event', (
    tester,
  ) async {
    await initializeDateFormatting('de_AT');
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryStudyBuddyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyBuddyRepositoryProvider.overrideWithValue(repository)],
        child: const StudyBuddyApp(),
      ),
    );

    await tester.tap(find.text('Fächer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fach anlegen').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Mathematik');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final state = await repository.loadInitialState();
    expect(state.subjects.single.name, 'Mathematik');

    final event = (await repository.calendarEvents()).single;
    expect(event.title, 'Mathematik');
    expect(event.subjectId, state.subjects.single.id);
    expect(event.category, 'PH-Lehrveranstaltung');
    expect(event.colorValue, state.subjects.single.color.toARGB32());

    final rule = RecurrenceRule.fromString(event.recurrenceRule!);
    expect(rule.frequency, Frequency.weekly);
    expect(rule.until, DateTime.utc(2027, 2, 28, 23, 59));

    await tester.tap(find.byTooltip('Fach bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Didaktik');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    final updatedState = await repository.loadInitialState();
    expect(updatedState.subjects.single.name, 'Didaktik');
    expect((await repository.calendarEvents()).single.title, 'Didaktik');

    await tester.tap(find.byTooltip('Fach löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect((await repository.loadInitialState()).subjects, isEmpty);
    expect(await repository.calendarEvents(), isEmpty);
  });
}
