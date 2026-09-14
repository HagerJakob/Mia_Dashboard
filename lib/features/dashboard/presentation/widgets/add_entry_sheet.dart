import 'package:flutter/material.dart';

import '../dashboard_controller.dart';

Future<void> showScheduleSheet(
  BuildContext context,
  StudyBuddyController controller,
) {
  return _showTwoFieldSheet(
    context: context,
    title: 'Termin eintragen',
    firstLabel: 'Uhrzeit',
    secondLabel: 'Titel',
    firstHint: '09:00',
    secondHint: 'Vorlesung, Lernen, Pause...',
    onSave: controller.addScheduleItem,
  );
}

Future<void> showTaskSheet(
  BuildContext context,
  StudyBuddyController controller,
) {
  return _showOneFieldSheet(
    context: context,
    title: 'Aufgabe erstellen',
    label: 'Aufgabe',
    hint: 'Was steht an?',
    onSave: controller.addTask,
  );
}

Future<void> showNoteSheet(
  BuildContext context,
  StudyBuddyController controller,
) {
  return _showTwoFieldSheet(
    context: context,
    title: 'Notiz schreiben',
    firstLabel: 'Titel',
    secondLabel: 'Notiz',
    firstHint: 'Kurz notiert',
    secondHint: 'Gedanken, Mitschrift, Idee...',
    onSave: controller.addNote,
    secondMaxLines: 4,
  );
}

Future<void> showSubjectSheet(
  BuildContext context,
  StudyBuddyController controller,
) {
  return _showOneFieldSheet(
    context: context,
    title: 'Fach anlegen',
    label: 'Fach',
    hint: 'Mathematik, BWL, Englisch...',
    onSave: controller.addSubject,
  );
}

Future<void> showExamSheet(
  BuildContext context,
  StudyBuddyController controller,
) {
  return _showTwoFieldSheet(
    context: context,
    title: 'Pruefung eintragen',
    firstLabel: 'Fach',
    secondLabel: 'Datum',
    firstHint: 'Mathematik',
    secondHint: '23. Oktober',
    onSave: controller.addExam,
  );
}

Future<void> showReminderSheet(
  BuildContext context,
  StudyBuddyController controller,
) {
  return _showTwoFieldSheet(
    context: context,
    title: 'Erinnerung anlegen',
    firstLabel: 'Titel',
    secondLabel: 'Wann?',
    firstHint: 'Unterlagen vorbereiten',
    secondHint: 'Morgen, 18:00',
    onSave: controller.addReminder,
  );
}

Future<void> _showOneFieldSheet({
  required BuildContext context,
  required String title,
  required String label,
  required String hint,
  required ValueChanged<String> onSave,
}) {
  final controller = TextEditingController();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetFrame(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label, hintText: hint),
            autofocus: true,
          ),
          const SizedBox(height: 18),
          _SaveButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              onSave(value);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

Future<void> _showTwoFieldSheet({
  required BuildContext context,
  required String title,
  required String firstLabel,
  required String secondLabel,
  required String firstHint,
  required String secondHint,
  required void Function(String first, String second) onSave,
  int secondMaxLines = 1,
}) {
  final firstController = TextEditingController();
  final secondController = TextEditingController();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetFrame(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: firstController,
            decoration: InputDecoration(
              labelText: firstLabel,
              hintText: firstHint,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: secondController,
            maxLines: secondMaxLines,
            decoration: InputDecoration(
              labelText: secondLabel,
              hintText: secondHint,
            ),
          ),
          const SizedBox(height: 18),
          _SaveButton(
            onPressed: () {
              final first = firstController.text.trim();
              final second = secondController.text.trim();
              if (first.isEmpty || second.isEmpty) {
                return;
              }
              onSave(first, second);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    firstController.dispose();
    secondController.dispose();
  });
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Speichern'),
      ),
    );
  }
}
