import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/calendar_models.dart';
import '../domain/calendar_services.dart';
import 'calendar_controller.dart';

Future<void> showAcademicPeriodEditor(
  BuildContext context,
  WidgetRef ref, {
  AcademicPeriod? existing,
  DateTime? initialDate,
}) async {
  final period = await showDialog<AcademicPeriod>(
    context: context,
    builder: (_) => _AcademicPeriodEditor(
      existing: existing,
      initialDate: initialDate ?? DateTime.now(),
    ),
  );
  if (period == null || !context.mounted) return;
  final event = CalendarEvent(
    id: period.id,
    title: period.title,
    startAt: dayStart(period.startDate),
    endAt: nextDay(period.endDate),
    description: period.description,
    category: 'Hochschulzeitraum',
    allDay: true,
    colorValue: 0xFF8BA58E,
    source: CalendarSource.academicPeriod,
    metadata: {
      'type': period.type.name,
      'institution': period.institution,
      'study_program': period.studyProgram,
      'source_url': period.sourceUrl ?? '',
      'confirmed': period.confirmed.toString(),
    },
  );
  await ref.read(calendarControllerProvider.notifier).save(event);
}

class _AcademicPeriodEditor extends StatefulWidget {
  const _AcademicPeriodEditor({required this.initialDate, this.existing});
  final DateTime initialDate;
  final AcademicPeriod? existing;
  @override
  State<_AcademicPeriodEditor> createState() => _AcademicPeriodEditorState();
}

class _AcademicPeriodEditorState extends State<_AcademicPeriodEditor> {
  late final TextEditingController _title, _description, _sourceUrl;
  late DateTime _start, _end;
  late AcademicPeriodType _type;
  late bool _confirmed;
  String? _error;

  @override
  void initState() {
    super.initState();
    final period = widget.existing;
    _title = TextEditingController(text: period?.title ?? '');
    _description = TextEditingController(text: period?.description ?? '');
    _sourceUrl = TextEditingController(text: period?.sourceUrl ?? '');
    _start = period?.startDate ?? dayStart(widget.initialDate);
    _end = period?.endDate ?? _start;
    _type = period?.type ?? AcademicPeriodType.custom;
    _confirmed = period?.confirmed ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _sourceUrl.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() {
        if (start) {
          _start = date;
          if (_end.isBefore(date)) _end = date;
        } else {
          _end = date;
        }
      });
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Bitte einen Titel eingeben.');
      return;
    }
    if (_end.isBefore(_start)) {
      setState(() => _error = 'Das Ende darf nicht vor dem Beginn liegen.');
      return;
    }
    Navigator.pop(
      context,
      AcademicPeriod(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        startDate: _start,
        endDate: _end,
        type: _type,
        institution: AcademicCalendarService.institution,
        studyProgram: AcademicCalendarService.studyProgram,
        source: 'Eigener Eintrag',
        sourceUrl: _sourceUrl.text.trim().isEmpty
            ? null
            : _sourceUrl.text.trim(),
        confirmed: _confirmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hochschulzeitraum',
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
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Titel *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AcademicPeriodType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Art'),
              items: [
                for (final type in AcademicPeriodType.values)
                  DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Von ${DateFormat('dd.MM.yyyy').format(_start)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Bis ${DateFormat('dd.MM.yyyy').format(_end)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Quellenlink (optional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              title: const Text('Daten bestätigt'),
              onChanged: (value) => setState(() => _confirmed = value),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(onPressed: _save, child: const Text('Speichern')),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String _typeLabel(AcademicPeriodType type) => switch (type) {
    AcademicPeriodType.semester => 'Semester',
    AcademicPeriodType.lecturePeriod => 'Lehrveranstaltungszeit',
    AcademicPeriodType.semesterBreak => 'Semesterferien',
    AcademicPeriodType.christmasBreak => 'Weihnachtspause',
    AcademicPeriodType.easterBreak => 'Osterpause',
    AcademicPeriodType.summerBreak => 'Sommerpause',
    AcademicPeriodType.lectureFree => 'Lehrveranstaltungsfrei',
    AcademicPeriodType.enrollmentPeriod => 'Anmeldezeitraum',
    AcademicPeriodType.examPeriod => 'Prüfungszeitraum',
    AcademicPeriodType.phEvent => 'PH-Termin',
    AcademicPeriodType.custom => 'Sonstiges',
  };
}
