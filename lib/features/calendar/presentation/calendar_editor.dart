import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rrule/rrule.dart';

import '../../../shared/design_system/study_radius.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../domain/calendar_models.dart';
import '../domain/calendar_services.dart';
import 'calendar_controller.dart';

const categoryColors = <String, int>{
  'Universität': 0xFF9C84BF,
  'Vorlesung': 0xFF9C84BF,
  'Übung': 0xFF8A9BC4,
  'Lernen': 0xFF80A996,
  'Prüfung': 0xFFD48695,
  'Arzt': 0xFF75AFA9,
  'Arbeit': 0xFFAAA583,
  'Privat': 0xFFB56D8C,
  'Sport': 0xFF8AA779,
  'Geburtstag': 0xFFD38BAF,
  'Termin': 0xFFB56D8C,
  'Erinnerung': 0xFFA898C5,
  'Schulpraxis': 0xFF789DAD,
  'Hospitation': 0xFF789DAD,
  'Unterricht': 0xFF789DAD,
  'Unterrichtsvorbereitung': 0xFF8A9BC4,
  'Reflexion': 0xFF9E9EBD,
  'PH-Lehrveranstaltung': 0xFF9C84BF,
  'Abgabe': 0xFFD48695,
  'Sonstiges': 0xFFA5A5A5,
};
const eventColorPalette = <int>[
  0xFFB56D8C,
  0xFFD38BAF,
  0xFFE3A6B5,
  0xFF9C84BF,
  0xFFA898C5,
  0xFF8A9BC4,
  0xFF83B7C7,
  0xFF75AFA9,
  0xFF80A996,
  0xFF8AA779,
  0xFFD48695,
  0xFFE3B778,
  0xFFAAA583,
  0xFFC7A27D,
  0xFF9E9EBD,
  0xFFA5A5A5,
];
const practiceCategories = {
  'Schulpraxis',
  'Hospitation',
  'Unterricht',
  'Unterrichtsvorbereitung',
  'Reflexion',
};
const studyCategories = {
  'Universität',
  'Vorlesung',
  'Übung',
  'Lernen',
  'Prüfung',
  'Schulpraxis',
  'Hospitation',
  'Unterricht',
  'Unterrichtsvorbereitung',
  'Reflexion',
  'PH-Lehrveranstaltung',
  'Abgabe',
};

Future<void> showCalendarEditor(
  BuildContext context,
  WidgetRef ref, {
  CalendarOccurrence? occurrence,
  DateTime? initialDate,
}) async {
  final controller = ref.read(calendarControllerProvider.notifier);
  final original = occurrence == null
      ? null
      : ref
                .read(calendarControllerProvider)
                .events
                .where((e) => e.id == occurrence.event.seriesId)
                .firstOrNull ??
            occurrence.event;
  var date = initialDate ?? occurrence?.startAt ?? DateTime.now();
  if (occurrence == null && date.hour == 0 && date.minute == 0) {
    date = DateTime(date.year, date.month, date.day, 9);
  }
  final result = await showDialog<CalendarEvent>(
    context: context,
    builder: (_) => _CalendarEditor(original: original, initialDate: date),
  );
  if (result == null || !context.mounted) return;
  final scope = occurrence?.isRecurring == true
      ? await askRecurrenceScope(context, 'Was möchtest du ändern?')
      : RecurrenceScope.all;
  if (scope == null) return;
  try {
    await controller.save(result, occurrence: occurrence, scope: scope);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Termin konnte nicht gespeichert werden: $error'),
        ),
      );
    }
  }
}

Future<RecurrenceScope?> askRecurrenceScope(
  BuildContext context,
  String title,
) => showDialog<RecurrenceScope>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (scope, label) in [
          (RecurrenceScope.one, 'Nur diesen Termin'),
          (RecurrenceScope.following, 'Diesen und alle folgenden'),
          (RecurrenceScope.all, 'Alle Termine der Serie'),
        ])
          ListTile(
            title: Text(label),
            onTap: () => Navigator.pop(context, scope),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
    ],
  ),
);

class _CalendarEditor extends ConsumerStatefulWidget {
  const _CalendarEditor({required this.initialDate, this.original});
  final CalendarEvent? original;
  final DateTime initialDate;
  @override
  ConsumerState<_CalendarEditor> createState() => _CalendarEditorState();
}

class _CalendarEditorState extends ConsumerState<_CalendarEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title,
      _description,
      _location,
      _online,
      _interval,
      _count,
      _school,
      _className,
      _mentor,
      _area,
      _customReminder,
      _categoryName;
  late DateTime _date, _endDate;
  late TimeOfDay _startTime, _endTime;
  late String _category, _repeat, _endMode, _unit;
  String? _subjectId;
  late bool _allDay, _otherEndDate;
  late EventPriority _priority;
  late int _color, _reminder;
  late Set<int> _weekdays;
  String? _validation;

  @override
  void initState() {
    super.initState();
    final event = widget.original;
    final start = widget.initialDate;
    final end = start.add(event?.duration ?? const Duration(hours: 1));
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _online = TextEditingController(text: event?.onlineUrl ?? '');
    _interval = TextEditingController(text: '2');
    _count = TextEditingController(text: '10');
    _customReminder = TextEditingController(text: '20');
    _categoryName = TextEditingController();
    _school = TextEditingController(text: event?.practice['school'] ?? '');
    _className = TextEditingController(text: event?.practice['class'] ?? '');
    _mentor = TextEditingController(text: event?.practice['mentor'] ?? '');
    _area = TextEditingController(text: event?.practice['area'] ?? '');
    _date = dayStart(start);
    _endDate = dayStart(end);
    _startTime = TimeOfDay.fromDateTime(start);
    _endTime = TimeOfDay.fromDateTime(end);
    _allDay = event?.allDay ?? false;
    _otherEndDate = _allDay
        ? !sameDay(nextDay(start), end)
        : !sameDay(start, end);
    _category = event?.category ?? 'Termin';
    _subjectId = event?.subjectId;
    _priority = event?.priority ?? EventPriority.normal;
    _color = event?.colorValue ?? categoryColors[_category]!;
    _reminder = event?.reminders.firstOrNull ?? -1;
    _repeat = 'Nie';
    _endMode = 'Nie';
    _unit = 'Wochen';
    _weekdays = {start.weekday};
    if (event?.recurrenceRule != null) {
      final rule = RecurrenceRule.fromString(event!.recurrenceRule!);
      _repeat = switch ((rule.frequency, rule.interval ?? 1)) {
        (Frequency.daily, 1) => 'Täglich',
        (Frequency.weekly, 1) => 'Wöchentlich',
        (Frequency.weekly, 2) => 'Alle 2 Wochen',
        (Frequency.monthly, 1) => 'Monatlich',
        (Frequency.yearly, 1) => 'Jährlich',
        _ => 'Benutzerdefiniert',
      };
      _interval.text = '${rule.interval ?? 1}';
      _unit = switch (rule.frequency) {
        Frequency.daily => 'Tage',
        Frequency.weekly => 'Wochen',
        Frequency.monthly => 'Monate',
        _ => 'Jahre',
      };
      if (rule.byWeekDays.isNotEmpty) {
        _weekdays = rule.byWeekDays.map((w) => w.day).toSet();
      }
      if (rule.count != null) {
        _endMode = 'Nach';
        _count.text = '${rule.count}';
      }
      if (rule.until != null) {
        _endMode = 'Am';
        _repeatUntil = DateTime(
          rule.until!.year,
          rule.until!.month,
          rule.until!.day,
        );
      }
    }
  }

  DateTime? _repeatUntil;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _location,
      _online,
      _interval,
      _count,
      _school,
      _className,
      _mentor,
      _area,
      _customReminder,
      _categoryName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _newCategory() async {
    _categoryName.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eigene Kategorie'),
        content: TextField(
          controller: _categoryName,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _categoryName.text.trim()),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await ref
        .read(calendarControllerProvider.notifier)
        .addCategory(
          CalendarCategory(
            DateTime.now().microsecondsSinceEpoch.toString(),
            name,
            _color,
          ),
        );
    if (mounted) setState(() => _category = name);
  }

  DateTime _at(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  void _save() {
    if (!_form.currentState!.validate()) return;
    final start = _allDay ? _date : _at(_date, _startTime);
    final end = _allDay
        ? nextDay(_otherEndDate ? _endDate : _date)
        : _at(_otherEndDate ? _endDate : _date, _endTime);
    if (!end.isAfter(start)) {
      setState(() => _validation = 'Das Ende muss nach dem Beginn liegen.');
      return;
    }
    if (_otherEndDate && _endDate.isBefore(_date)) {
      setState(
        () => _validation = 'Das Enddatum darf nicht vor dem Start liegen.',
      );
      return;
    }
    final interval = _repeat == 'Benutzerdefiniert'
        ? int.tryParse(_interval.text)
        : null;
    final count = _endMode == 'Nach' ? int.tryParse(_count.text) : null;
    if ((_repeat == 'Benutzerdefiniert' &&
            (interval == null || interval <= 0)) ||
        (_repeat != 'Nie' &&
            _endMode == 'Nach' &&
            (count == null || count <= 0))) {
      setState(
        () => _validation = 'Intervall und Anzahl müssen größer als null sein.',
      );
      return;
    }
    if (_repeat != 'Nie' &&
        _endMode == 'Am' &&
        (_repeatUntil == null || _repeatUntil!.isBefore(_date))) {
      setState(
        () => _validation = 'Das Wiederholungsende muss nach dem Start liegen.',
      );
      return;
    }
    String? rule;
    if (_repeat != 'Nie') {
      final frequency = switch (_repeat) {
        'Täglich' => Frequency.daily,
        'Monatlich' => Frequency.monthly,
        'Jährlich' => Frequency.yearly,
        'Benutzerdefiniert' => switch (_unit) {
          'Tage' => Frequency.daily,
          'Monate' => Frequency.monthly,
          'Jahre' => Frequency.yearly,
          _ => Frequency.weekly,
        },
        _ => Frequency.weekly,
      };
      if (frequency == Frequency.weekly && _weekdays.isEmpty) {
        setState(
          () => _validation = 'Bitte mindestens einen Wochentag auswählen.',
        );
        return;
      }
      rule = const RecurrenceService().rule(
        frequency: frequency,
        interval: interval ?? (_repeat == 'Alle 2 Wochen' ? 2 : 1),
        weekdays: frequency == Frequency.weekly ? _weekdays.toList() : [],
        until: _endMode == 'Am' && _repeatUntil != null
            ? DateTime(
                _repeatUntil!.year,
                _repeatUntil!.month,
                _repeatUntil!.day,
                23,
                59,
              )
            : null,
        count: _endMode == 'Nach' ? count : null,
      );
    }
    final reminder = _reminder == -2
        ? int.tryParse(_customReminder.text)
        : _reminder;
    if (reminder == null || reminder < -1) {
      setState(() => _validation = 'Bitte eine gültige Erinnerung wählen.');
      return;
    }
    final source = widget.original?.source ?? CalendarSource.user;
    Navigator.of(context).pop(
      CalendarEvent(
        id:
            widget.original?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        startAt: start,
        endAt: end,
        category: _category,
        subjectId: _subjectId,
        description: _description.text.trim(),
        location: _location.text.trim(),
        onlineUrl: _online.text.trim(),
        allDay: _allDay,
        colorValue: _color,
        priority: _priority,
        recurrenceRule: rule,
        reminders: reminder < 0 ? [] : [reminder],
        source: source,
        practice: practiceCategories.contains(_category)
            ? {
                'school': _school.text.trim(),
                'class': _className.text.trim(),
                'mentor': _mentor.text.trim(),
                'area': _area.text.trim(),
              }
            : {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(calendarControllerProvider);
    final subjects = ref.watch(studyBuddyControllerProvider).subjects;
    final categories = {
      ...categoryColors.keys,
      ...calendar.categories.map((c) => c.name),
    }.toList();
    if (!categories.contains(_category)) categories.add(_category);
    final compact = MediaQuery.sizeOf(context).width < 650;
    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 590,
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
                      Icons.calendar_month_rounded,
                      color: AppColors.mauve,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.original == null
                          ? 'Neuer Termin'
                          : 'Termin bearbeiten',
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
                      const _EditorSectionTitle('Grunddaten'),
                      TextFormField(
                        controller: _title,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Titel *'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Bitte einen Titel eingeben.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Kategorie',
                              ),
                              items: [
                                for (final name in categories)
                                  DropdownMenuItem(
                                    value: name,
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(() {
                                _category = value!;
                                _color =
                                    calendar.categories
                                        .where((c) => c.name == value)
                                        .firstOrNull
                                        ?.colorValue ??
                                    categoryColors[value] ??
                                    _color;
                              }),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eigene Kategorie',
                            onPressed: _newCategory,
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        ],
                      ),
                      if (studyCategories.contains(_category)) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _subjectId,
                          decoration: const InputDecoration(labelText: 'Fach'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Kein Fach'),
                            ),
                            for (final subject in subjects)
                              DropdownMenuItem(
                                value: subject.id,
                                child: Text(subject.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _subjectId = value),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _EditorSectionTitle('Zeit'),
                      _dateButton(
                        'Datum',
                        _date,
                        (date) => setState(() => _date = date),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ganztägig'),
                        value: _allDay,
                        onChanged: (value) => setState(() => _allDay = value!),
                      ),
                      if (!_allDay) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _timeButton(
                                'Von',
                                _startTime,
                                (time) => setState(() => _startTime = time),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _timeButton(
                                'Bis',
                                _endTime,
                                (time) => setState(() => _endTime = time),
                              ),
                            ),
                          ],
                        ),
                      ],
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Endet an einem anderen Tag'),
                        value: _otherEndDate,
                        onChanged: (value) =>
                            setState(() => _otherEndDate = value!),
                      ),
                      if (_otherEndDate)
                        _dateButton(
                          'Enddatum',
                          _endDate,
                          (date) => setState(() => _endDate = date),
                        ),
                      const SizedBox(height: 20),
                      const _EditorSectionTitle('Details'),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(labelText: 'Ort'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _online,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Online-Link',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Beschreibung / Notizen',
                        ),
                      ),
                      if (practiceCategories.contains(_category)) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Schulpraxis',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final (label, controller) in [
                          ('Schule', _school),
                          ('Klasse', _className),
                          ('Mentor/in', _mentor),
                          ('Fach/Bereich', _area),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(labelText: label),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      const _EditorSectionTitle('Organisation'),
                      Text(
                        'Farbe',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final color in eventColorPalette)
                            InkWell(
                              onTap: () => setState(() => _color = color),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(color),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _color == color
                                        ? Colors.black87
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Eigene Farbe',
                            onPressed: _chooseColor,
                            icon: const Icon(Icons.palette_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<EventPriority>(
                        isExpanded: true,
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Wichtigkeit',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: EventPriority.low,
                            child: Text('Niedrig'),
                          ),
                          DropdownMenuItem(
                            value: EventPriority.normal,
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(
                            value: EventPriority.important,
                            child: Text('Wichtig'),
                          ),
                          DropdownMenuItem(
                            value: EventPriority.veryImportant,
                            child: Text('Sehr wichtig'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _priority = value!),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _repeat,
                        decoration: const InputDecoration(
                          labelText: 'Wiederholen',
                        ),
                        items: [
                          for (final value in [
                            'Nie',
                            'Täglich',
                            'Wöchentlich',
                            'Alle 2 Wochen',
                            'Monatlich',
                            'Jährlich',
                            'Benutzerdefiniert',
                          ])
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) => setState(() {
                          _repeat = value!;
                          _weekdays = {_date.weekday};
                        }),
                      ),
                      if (_repeat == 'Benutzerdefiniert') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _interval,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Alle',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _unit,
                                items: [
                                  for (final value in [
                                    'Tage',
                                    'Wochen',
                                    'Monate',
                                    'Jahre',
                                  ])
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _unit = value!),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_repeat == 'Wöchentlich' ||
                          _repeat == 'Alle 2 Wochen' ||
                          (_repeat == 'Benutzerdefiniert' &&
                              _unit == 'Wochen')) ...[
                        const SizedBox(height: 12),
                        const Text('Wiederholen am'),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (var day = 1; day <= 7; day++)
                              FilterChip(
                                label: Text(
                                  [
                                    'Mo',
                                    'Di',
                                    'Mi',
                                    'Do',
                                    'Fr',
                                    'Sa',
                                    'So',
                                  ][day - 1],
                                ),
                                selected: _weekdays.contains(day),
                                onSelected: (selected) => setState(() {
                                  selected
                                      ? _weekdays.add(day)
                                      : _weekdays.remove(day);
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (_repeat != 'Nie') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _endMode,
                          decoration: const InputDecoration(
                            labelText: 'Wiederholung endet',
                          ),
                          items: [
                            for (final value in ['Nie', 'Am', 'Nach'])
                              DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _endMode = value!),
                        ),
                        if (_endMode == 'Am')
                          _dateButton(
                            'Letzter Tag',
                            _repeatUntil ?? _date,
                            (date) => setState(() => _repeatUntil = date),
                          ),
                        if (_endMode == 'Nach')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextFormField(
                              controller: _count,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Anzahl Termine',
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _reminder,
                        decoration: const InputDecoration(
                          labelText: 'Erinnerung',
                        ),
                        items: const [
                          DropdownMenuItem(value: -1, child: Text('Keine')),
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Zur Startzeit'),
                          ),
                          DropdownMenuItem(
                            value: 5,
                            child: Text('5 Minuten vorher'),
                          ),
                          DropdownMenuItem(
                            value: 10,
                            child: Text('10 Minuten vorher'),
                          ),
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 Minuten vorher'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 Minuten vorher'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('1 Stunde vorher'),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text('2 Stunden vorher'),
                          ),
                          DropdownMenuItem(
                            value: 1440,
                            child: Text('1 Tag vorher'),
                          ),
                          DropdownMenuItem(
                            value: -2,
                            child: Text('Benutzerdefiniert'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _reminder = value!),
                      ),
                      if (_reminder == -2)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            controller: _customReminder,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minuten vorher',
                            ),
                          ),
                        ),
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
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Speichern'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Abbrechen'),
                        ),
                      ],
                    )
                  : Row(
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

  Widget _dateButton(
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null && mounted) onChanged(picked);
      },
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text('$label: ${DateFormat('dd.MM.yyyy').format(value)}'),
    ),
  );

  Widget _timeButton(
    String label,
    TimeOfDay value,
    ValueChanged<TimeOfDay> onChanged,
  ) => OutlinedButton(
    onPressed: () async {
      final picked = await showTimePicker(context: context, initialTime: value);
      if (picked != null && mounted) onChanged(picked);
    },
    child: Text(
      '$label: ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
    ),
  );

  Future<void> _chooseColor() async {
    var selected = Color(_color);
    final color = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Eigene Farbe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (name, channel) in [
                ('Rot', 0),
                ('Grün', 1),
                ('Blau', 2),
              ])
                Row(
                  children: [
                    SizedBox(width: 45, child: Text(name)),
                    Expanded(
                      child: Slider(
                        value:
                            [selected.r, selected.g, selected.b][channel] * 255,
                        max: 255,
                        onChanged: (value) => update(
                          () => selected = Color.fromARGB(
                            255,
                            channel == 0
                                ? value.round()
                                : (selected.r * 255).round(),
                            channel == 1
                                ? value.round()
                                : (selected.g * 255).round(),
                            channel == 2
                                ? value.round()
                                : (selected.b * 255).round(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              Container(width: 54, height: 32, color: selected),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, selected.toARGB32()),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (color != null && mounted) setState(() => _color = color);
  }
}

class _EditorSectionTitle extends StatelessWidget {
  const _EditorSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: AppColors.mauve, fontWeight: FontWeight.w800),
      ),
    );
  }
}
