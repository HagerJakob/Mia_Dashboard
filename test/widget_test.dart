import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_buddy/app/app.dart';

void main() {
  testWidgets('renders the StudyBuddy dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyBuddyApp()));

    expect(find.textContaining('Mia'), findsOneWidget);
    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Aufgaben'), findsWidgets);
    expect(find.text('Focus'), findsOneWidget);
  });
}
