import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_buddy/app/app.dart';

void main() {
  testWidgets('renders the StudyBuddy dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyBuddyApp()));

    expect(find.textContaining('Hallo Mia'), findsOneWidget);
    expect(find.text('Lernstreak'), findsOneWidget);
    expect(find.text('Meine Aufgaben'), findsOneWidget);
    expect(find.text('Focus Timer'), findsOneWidget);
  });
}
