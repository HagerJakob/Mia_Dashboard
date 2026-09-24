import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_buddy/app/app.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/presentation/dashboard_controller.dart';

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [
    Size(390, 844),
    Size(800, 1280),
    Size(1366, 768),
    Size(1920, 1080),
  ]) {
    testWidgets('dashboard renders without responsive exceptions at $size', (
      tester,
    ) async {
      await _pumpAt(tester, size);
      expect(find.textContaining('Mia'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile more navigation opens secondary features', (
    tester,
  ) async {
    Future<void> openMoreDestination(String label, Finder expected) async {
      await _pumpAt(tester, const Size(390, 844));
      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(expected, findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await openMoreDestination('Notizen', find.text('Ordner'));
    await openMoreDestination('Fächer', find.byTooltip('Fach anlegen'));
    await openMoreDestination('Prüfungen', find.byTooltip('Neue Prüfung'));
    await openMoreDestination('Statistiken', find.text('Statistiken'));
  });

  testWidgets('desktop navigation opens primary screens without exceptions', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1366, 768));

    for (final label in [
      'Kalender',
      'Aufgaben',
      'Notizen',
      'Fächer',
      'Prüfungen',
      'Timer',
      'Statistiken',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('mobile bottom navigation opens core flows', (tester) async {
    await _pumpAt(tester, const Size(390, 844));

    for (final label in ['Kalender', 'Aufgaben', 'Lernen', 'Mehr']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
