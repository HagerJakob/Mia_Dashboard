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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EntrySheet(
      title: title,
      firstLabel: label,
      firstHint: hint,
      onSave: (first, _) => onSave(first),
    ),
  );
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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EntrySheet(
      title: title,
      firstLabel: firstLabel,
      firstHint: firstHint,
      secondLabel: secondLabel,
      secondHint: secondHint,
      secondMaxLines: secondMaxLines,
      onSave: (first, second) => onSave(first, second!),
    ),
  );
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({
    required this.title,
    required this.firstLabel,
    required this.firstHint,
    required this.onSave,
    this.secondLabel,
    this.secondHint,
    this.secondMaxLines = 1,
  });

  final String title;
  final String firstLabel;
  final String firstHint;
  final String? secondLabel;
  final String? secondHint;
  final int secondMaxLines;
  final void Function(String first, String? second) onSave;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final _firstController = TextEditingController();
  TextEditingController? _secondController;

  @override
  void initState() {
    super.initState();
    if (widget.secondLabel != null) {
      _secondController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _firstController.dispose();
    _secondController?.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _save() {
    final first = _firstController.text.trim();
    final second = _secondController?.text.trim();
    if (first.isEmpty || (second != null && second.isEmpty)) {
      return;
    }
    widget.onSave(first, second);
    _close();
  }

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
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Schliessen',
                onPressed: _close,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _firstController,
            decoration: InputDecoration(
              labelText: widget.firstLabel,
              hintText: widget.firstHint,
            ),
            autofocus: true,
          ),
          if (_secondController != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _secondController,
              maxLines: widget.secondMaxLines,
              decoration: InputDecoration(
                labelText: widget.secondLabel,
                hintText: widget.secondHint,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(onPressed: _close, child: const Text('Abbrechen')),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Speichern'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
