import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rrule/rrule.dart';

import '../../../shared/design_system/study_badge.dart';
import '../../../shared/design_system/study_card.dart';
import '../../../shared/design_system/study_empty_state.dart';
import '../../../shared/design_system/study_radius.dart';
import '../../../theme/app_colors.dart';
import '../../calendar/domain/calendar_models.dart';
import '../../calendar/domain/calendar_services.dart';
import '../../calendar/presentation/calendar_controller.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyBuddyControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: compact
          ? FloatingActionButton(
              tooltip: 'Fach anlegen',
              onPressed: () => _showSubjectDialog(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            20,
            compact ? 16 : 28,
            80,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fächer',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lege Mias Studienfächer an und plane regelmäßige Lehrveranstaltungen direkt im Kalender.',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  FilledButton.icon(
                    onPressed: () => _showSubjectDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Fach anlegen'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            StudyCard(
              child: state.subjects.isEmpty
                  ? const StudyEmptyState(
                      icon: Icons.auto_stories_rounded,
                      message: 'Noch keine Fächer. Das Studium startet frisch, Mia kann hier alles selbst eintragen.',
                    )
                  : Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final subject in state.subjects)
                          SizedBox(
                            width: compact ? double.infinity : 280,
                            child: _SubjectTile(
                              subject: subject,
                              onEdit: () => _showSubjectDialog(
                                context,
                                ref,
                                existing: subject,
                              ),
                              onDelete: () =>
                                  _deleteSubject(context, ref, subject),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            const StudyBadge(
              icon: Icons.calendar_month_rounded,
              label: 'Regelmäßige Termine im 1. Semester enden automatisch am 28.02.2027',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubjectDialog(
    BuildContext context,
    WidgetRef ref, {
    SubjectItem? existing,
  }) async {
    final result = await showDialog<_SubjectDraft>(
      context: context,
      builder: (_) => _SubjectDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;

    final dashboard = ref.read(studyBuddyControllerProvider.notifier);
    final subject = SubjectItem(
      id: existing?.id ?? dashboard.newId(),
      name: result.name,
      color: result.color,
    );
    if (existing == null) {
      await dashboard.addSubjectItem(subject);
    } else {
      await dashboard.updateSubjectItem(subject);
      await _updateLinkedCalendarEvents(ref, subject);
    }

    if (!result.createCalendarEvent || !context.mounted) return;
    final calendar = ref.read(calendarControllerProvider.notifier);
    final start = DateTime(
      result.date.year,
      result.date.month,
      result.date.day,
      result.start.hour,
      result.start.minute,
    );
    final end = DateTime(
      result.date.year,
      result.date.month,
      result.date.day,
      result.end.hour,
      result.end.minute,
    );
    final semesterEnd = _firstSemesterEndFor(start);
    final recurrence = const RecurrenceService().rule(
      frequency: result.repeat == _SubjectRepeat.daily
          ? Frequency.daily
          : Frequency.weekly,
      interval: result.repeat == _SubjectRepeat.fortnightly ? 2 : 1,
      weekdays: result.repeat == _SubjectRepeat.daily ? [] : [start.weekday],
      until: semesterEnd,
    );
    await calendar.save(
      CalendarEvent(
        id: calendar.newId(),
        title: subject.name,
        category: 'PH-Lehrveranstaltung',
        subjectId: subject.id,
        startAt: start,
        endAt: end,
        colorValue: subject.color.toARGB32(),
        recurrenceRule: recurrence,
      ),
    );
  }

  DateTime _firstSemesterEndFor(DateTime start) {
    return const StudyTimeline().semester(start) == 1
        ? DateTime(2027, 2, 28, 23, 59)
        : DateTime(start.year, start.month + 4, start.day, 23, 59);
  }

  Future<void> _updateLinkedCalendarEvents(
    WidgetRef ref,
    SubjectItem subject,
  ) async {
    final calendar = ref.read(calendarControllerProvider.notifier);
    final events = ref.read(calendarControllerProvider).events;
    for (final event in events.where(
      (event) => event.subjectId == subject.id,
    )) {
      await calendar.save(
        event.copyWith(
          title: subject.name,
          colorValue: subject.color.toARGB32(),
        ),
      );
    }
  }

  Future<void> _deleteSubject(
    BuildContext context,
    WidgetRef ref,
    SubjectItem subject,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fach löschen?'),
        content: Text(
          '„${subject.name}“ wird gelöscht. Verknüpfte Kalendertermine zu diesem Fach werden ebenfalls entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final calendar = ref.read(calendarControllerProvider.notifier);
    final events = ref.read(calendarControllerProvider).events;
    for (final event in events.where(
      (event) => event.subjectId == subject.id,
    )) {
      await calendar.delete(
        CalendarOccurrence(event, event.startAt, event.endAt),
      );
    }
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .deleteSubjectItem(subject.id);
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  final SubjectItem subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: StudyRadius.medium,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: StudyRadius.medium,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: subject.color, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  subject.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Fach bearbeiten',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Fach löschen',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _subjectColors = [
  AppColors.mauve,
  AppColors.lavender,
  AppColors.sage,
  Color(0xFF75AFA9),
  Color(0xFFD48695),
  Color(0xFF8A9BC4),
  Color(0xFFD38BAF),
  Color(0xFFB9A7D8),
  Color(0xFFDE9EAA),
  Color(0xFF9BBF90),
  Color(0xFFE3B778),
  Color(0xFF83B7C7),
  Color(0xFFC7A27D),
  Color(0xFF9FA8C7),
];

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          InkWell(
            onTap: () => onSelected(color),
            borderRadius: StudyRadius.full,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected.toARGB32() == color.toARGB32()
                      ? AppColors.ink
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _SubjectRepeat { weekly, fortnightly, daily }

class _SubjectDraft {
  const _SubjectDraft({
    required this.name,
    required this.color,
    required this.createCalendarEvent,
    required this.date,
    required this.start,
    required this.end,
    required this.repeat,
  });

  final String name;
  final Color color;
  final bool createCalendarEvent;
  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;
  final _SubjectRepeat repeat;
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({this.existing});

  final SubjectItem? existing;

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  var _color = AppColors.mauve;
  var _createCalendarEvent = true;
  var _date = DateTime(2026, 10, 1);
  var _start = const TimeOfDay(hour: 9, minute: 0);
  var _end = const TimeOfDay(hour: 10, minute: 30);
  var _repeat = _SubjectRepeat.weekly;
  String? _validation;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _color = existing.color;
      _createCalendarEvent = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.blush,
                      borderRadius: StudyRadius.medium,
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.mauve,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _editing ? 'Fach bearbeiten' : 'Fach anlegen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Fach *'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Bitte einen Fachnamen eingeben.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Farbe',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _ColorPalette(
                        colors: _subjectColors,
                        selected: _color,
                        onSelected: (color) => setState(() => _color = color),
                      ),
                      if (!_editing) ...[
                        const SizedBox(height: 18),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Regelmäßig im Kalender eintragen'),
                          subtitle: const Text(
                            'Für das 1. Semester automatisch begrenzt.',
                          ),
                          value: _createCalendarEvent,
                          onChanged: (value) =>
                              setState(() => _createCalendarEvent = value),
                        ),
                      ],
                      if (_createCalendarEvent) ...[
                        const SizedBox(height: 8),
                        _dateButton(context),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _timeButton(context, 'Von', _start),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _timeButton(context, 'Bis', _end)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<_SubjectRepeat>(
                          initialValue: _repeat,
                          decoration: const InputDecoration(
                            labelText: 'Wiederholen',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: _SubjectRepeat.weekly,
                              child: Text('Wöchentlich'),
                            ),
                            DropdownMenuItem(
                              value: _SubjectRepeat.fortnightly,
                              child: Text('Alle 2 Wochen'),
                            ),
                            DropdownMenuItem(
                              value: _SubjectRepeat.daily,
                              child: Text('Täglich'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _repeat = value!),
                        ),
                      ],
                      if (_validation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _validation!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2026, 9, 1),
          lastDate: DateTime(2031, 7, 31),
        );
        if (picked != null && mounted) setState(() => _date = picked);
      },
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text('Startdatum: ${DateFormat('dd.MM.yyyy').format(_date)}'),
    );
  }

  Widget _timeButton(BuildContext context, String label, TimeOfDay value) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
        );
        if (picked == null || !mounted) return;
        setState(() {
          if (label == 'Von') {
            _start = picked;
          } else {
            _end = picked;
          }
        });
      },
      child: Text(
        '$label: ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final startMinutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    if (_createCalendarEvent && endMinutes <= startMinutes) {
      setState(
        () => _validation = 'Die Endzeit muss nach der Startzeit liegen.',
      );
      return;
    }
    Navigator.pop(
      context,
      _SubjectDraft(
        name: _name.text.trim(),
        color: _color,
        createCalendarEvent: _createCalendarEvent,
        date: _date,
        start: _start,
        end: _end,
        repeat: _repeat,
      ),
    );
  }
}
