import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/app/app.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/presentation/dashboard_controller.dart';
import 'package:study_buddy/shared/design_system/study_assets.dart';
import 'package:study_buddy/shared/design_system/study_svg_asset.dart';

Future<void> _pumpAppAt(WidgetTester tester, Size size) async {
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
  testWidgets('StudyBuddy logo svg asset renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: StudySvgAsset(
              asset: StudyAssets.appIcon,
              width: 64,
              height: 64,
              semanticLabel: 'StudyBuddy Logo',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudySvgAsset), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand assets render in compact and desktop shells', (
    tester,
  ) async {
    await _pumpAppAt(tester, const Size(390, 844));
    expect(find.byType(StudySvgAsset), findsWidgets);
    expect(tester.takeException(), isNull);

    await _pumpAppAt(tester, const Size(1366, 768));
    expect(find.byType(StudySvgAsset), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
