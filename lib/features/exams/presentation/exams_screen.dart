import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/design_system/study_badge.dart';
import '../../../shared/design_system/study_card.dart';
import '../../../shared/design_system/study_empty_state.dart';
import '../../../shared/design_system/study_radius.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

enum ExamSmartList { all, upcoming, today, week, month, preparing, completed }

class ExamsScreen extends ConsumerStatefulWidget {
  const ExamsScreen({super.key});

  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> {
  final _search = TextEditingController();
  var _list = ExamSmartList.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBuddyControllerProvider);
    final exams = _visibleExams(state);
    final nextExam =
        state.exams
            .where((exam) => !exam.isCompleted && exam.startAt != null)
            .toList()
          ..sort(_dateCompare);
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: compact
          ? FloatingActionButton(
              tooltip: 'Neue Prüfung',
              onPressed: () => _openEditor(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!compact)
              SizedBox(
                width: 220,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 8, 20),
                  children: [
                    for (final list in ExamSmartList.values)
                      _SmartListTile(
                        list: list,
                        selected: _list == list,
                        count: _countFor(state.exams, list),
                        onTap: () => setState(() => _list = list),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 20,
                  20,
                  compact ? 16 : 28,
                  90,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Prüfungen',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (!compact)
                        FilledButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Neue Prüfung'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ExamSummary(
                    nextExam: nextExam.firstOrNull,
                    upcoming: state.exams
                        .where((exam) => _isUpcomingExam(exam))
                        .length,
                    thisWeek: state.exams
                        .where((exam) => _isThisWeek(exam.startAt))
                        .length,
                    completed: state.exams
                        .where((exam) => exam.isCompleted)
                        .length,
                  ),
                  const SizedBox(height: 14),
                  StudyCard(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: compact ? double.infinity : 320,
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Suchen...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (compact)
                          DropdownButton<ExamSmartList>(
                            value: _list,
                            isExpanded: true,
                            items: [
                              for (final list in ExamSmartList.values)
                                DropdownMenuItem(
                                  value: list,
                                  child: Text(
                                    _smartLabel(list),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _list = value!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (exams.isEmpty)
                    const StudyCard(
                      child: StudyEmptyState(
                        icon: Icons.school_rounded,
                        message: 'Noch keine passenden Prüfungen.',
                      ),
                    )
                  else ...[
                    for (final entry in _group(exams).entries) ...[
                      _GroupHeader(title: entry.key, count: entry.value.length),
                      const SizedBox(height: 8),
                      for (final exam in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExamRow(
                            exam: exam,
                            subjectName: _subjectName(state, exam),
                            onOpen: () => _openEditor(exam),
                            onDelete: () => _deleteExam(exam),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ExamOverview> _visibleExams(StudyBuddyState state) {
    final query = _search.text.trim().toLowerCase();
    final exams = state.exams.where((exam) {
      if (!_inSmartList(exam, _list)) return false;
      if (query.isEmpty) return true;
      return [
        exam.title,
        exam.subject,
        exam.location,
        exam.room,
        exam.examiner,
        exam.description,
      ].any((text) => text.toLowerCase().contains(query));
    }).toList()..sort(_dateCompare);
    return exams;
  }

  Map<String, List<ExamOverview>> _group(List<ExamOverview> exams) {
    final result = <String, List<ExamOverview>>{};
    for (final exam in exams) {
      result.putIfAbsent(_groupLabel(exam), () => []).add(exam);
    }
    return result;
  }

  Future<void> _openEditor([ExamOverview? exam]) async {
    final result = await showDialog<ExamOverview>(
      context: context,
      builder: (_) => _ExamEditor(exam: exam),
    );
    if (result == null || !mounted) return;
    await ref.read(studyBuddyControllerProvider.notifier).saveExam(result);
  }

  Future<void> _deleteExam(ExamOverview exam) async {
    await ref.read(studyBuddyControllerProvider.notifier).deleteExam(exam.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Prüfung gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () =>
              ref.read(studyBuddyControllerProvider.notifier).saveExam(exam),
        ),
      ),
    );
  }
}

class _ExamSummary extends StatelessWidget {
  const _ExamSummary({
    required this.nextExam,
    required this.upcoming,
    required this.thisWeek,
    required this.completed,
  });

  final ExamOverview? nextExam;
  final int upcoming;
  final int thisWeek;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nächste Prüfung',
                  style: TextStyle(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextExam?.title ?? 'Noch nichts eingetragen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (nextExam != null) ...[
                  const SizedBox(height: 4),
                  Text(_dateTimeLabel(nextExam!.startAt, nextExam!.dateLabel)),
                ],
              ],
            ),
          ),
          _SummaryPill(label: 'Bevorstehend', value: '$upcoming'),
          _SummaryPill(label: 'Diese Woche', value: '$thisWeek'),
          _SummaryPill(label: 'Abgeschlossen', value: '$completed'),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: const TextStyle(color: AppColors.mutedInk)),
    ],
  );
}

class _SmartListTile extends StatelessWidget {
  const _SmartListTile({
    required this.list,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final ExamSmartList list;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.blush : AppColors.surface,
        borderRadius: StudyRadius.medium,
        child: ListTile(
          dense: true,
          onTap: onTap,
          title: Text(_smartLabel(list)),
          trailing: count == 0 ? null : StudyBadge(label: '$count'),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$count', style: const TextStyle(color: AppColors.mutedInk)),
      ],
    ),
  );
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({
    required this.exam,
    required this.subjectName,
    required this.onOpen,
    required this.onDelete,
  });

  final ExamOverview exam;
  final String subjectName;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = exam.computedProgress;
    return StudyCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: StudyRadius.large,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  StudyBadge(
                    label: _statusLabel(exam.effectiveStatus),
                    color: _statusColor(exam.effectiveStatus),
                  ),
                  IconButton(
                    tooltip: 'Löschen',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(subjectName.isEmpty ? exam.subject : subjectName),
                  Text(_typeLabel(exam.examType)),
                  if (exam.startAt != null)
                    Text(_dateTimeLabel(exam.startAt, exam.dateLabel)),
                  if (exam.location.isNotEmpty) Text(exam.location),
                  if (_resultLabel(exam).isNotEmpty) Text(_resultLabel(exam)),
                  Text(_countdownLabel(exam)),
                ],
              ),
              if (exam.chapters.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: StudyRadius.full,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: AppColors.blush,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _statusColor(exam.effectiveStatus),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).round()} % vorbereitet · ${exam.chapters.where((chapter) => chapter.done).length}/${exam.chapters.length} Themen',
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamEditor extends ConsumerStatefulWidget {
  const _ExamEditor({this.exam});

  final ExamOverview? exam;

  @override
  ConsumerState<_ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends ConsumerState<_ExamEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _room = TextEditingController();
  final _onlineUrl = TextEditingController();
  final _examiner = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _topic = TextEditingController();
  final _grade = TextEditingController();
  final _pointsAchieved = TextEditingController();
  final _pointsMaximum = TextEditingController();
  String? _subjectId;
  String _subjectText = '';
  var _type = ExamType.written;
  var _status = ExamStatus.planned;
  var _priority = TaskPriority.normal;
  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _preparationStartAt;
  var _topics = <ChapterProgress>[];
  var _reminders = <int>[];
  var _showMore = false;
  bool? _passed;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    if (exam != null) {
      _title.text = exam.title;
      _subjectText = exam.subject;
      _subjectId = exam.subjectId;
      _type = exam.examType;
      _status = exam.status;
      _priority = exam.priority;
      _startAt = exam.startAt;
      _endAt = exam.endAt;
      _preparationStartAt = exam.preparationStartAt;
      _location.text = exam.location;
      _room.text = exam.room;
      _onlineUrl.text = exam.onlineUrl;
      _examiner.text = exam.examiner;
      _description.text = exam.description;
      _notes.text = exam.notes;
      _topics = [...exam.chapters];
      _reminders = [...exam.reminders];
      _grade.text = exam.grade?.toString() ?? '';
      _pointsAchieved.text = exam.pointsAchieved?.toString() ?? '';
      _pointsMaximum.text = exam.pointsMaximum?.toString() ?? '';
      _passed = exam.passed;
      _showMore =
          exam.description.isNotEmpty ||
          exam.notes.isNotEmpty ||
          exam.chapters.isNotEmpty ||
          exam.grade != null ||
          exam.location.isNotEmpty ||
          exam.room.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _room.dispose();
    _onlineUrl.dispose();
    _examiner.dispose();
    _description.dispose();
    _notes.dispose();
    _topic.dispose();
    _grade.dispose();
    _pointsAchieved.dispose();
    _pointsMaximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(studyBuddyControllerProvider).subjects;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.exam == null
                          ? 'Neue Prüfung'
                          : 'Prüfung bearbeiten',
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
                        controller: _title,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Titel *'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Bitte einen Titel eingeben.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _subjectId,
                              decoration: const InputDecoration(
                                labelText: 'Fach',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Kein Fach'),
                                ),
                                for (final subject in subjects)
                                  DropdownMenuItem<String?>(
                                    value: subject.id,
                                    child: Text(
                                      subject.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(() {
                                _subjectId = value;
                                _subjectText =
                                    subjects
                                        .where((subject) => subject.id == value)
                                        .firstOrNull
                                        ?.name ??
                                    _subjectText;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: DropdownButtonFormField<ExamType>(
                              isExpanded: true,
                              initialValue: _type,
                              decoration: const InputDecoration(
                                labelText: 'Prüfungsart',
                              ),
                              items: [
                                for (final type in ExamType.values)
                                  DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      _typeLabel(type),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _type = value!),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickStart,
                            icon: const Icon(Icons.event_rounded),
                            label: Text(
                              _startAt == null
                                  ? 'Datum wählen'
                                  : _dateTimeLabel(_startAt, ''),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(labelText: 'Ort'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _showMore = !_showMore),
                        icon: Icon(
                          _showMore
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        label: const Text('Weitere Optionen'),
                      ),
                      if (_showMore) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<TaskPriority>(
                                isExpanded: true,
                                initialValue: _priority,
                                decoration: const InputDecoration(
                                  labelText: 'Priorität',
                                ),
                                items: [
                                  for (final priority in TaskPriority.values)
                                    DropdownMenuItem(
                                      value: priority,
                                      child: Text(
                                        _priorityLabel(priority),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _priority = value!),
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              child: DropdownButtonFormField<ExamStatus>(
                                isExpanded: true,
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                ),
                                items: [
                                  for (final status in ExamStatus.values)
                                    DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        _statusLabel(status),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) => setState(() {
                                  _status = value!;
                                  if (_status == ExamStatus.passed) {
                                    _passed = true;
                                  }
                                  if (_status == ExamStatus.failed) {
                                    _passed = false;
                                  }
                                }),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickPreparationStart,
                              icon: const Icon(Icons.flag_outlined),
                              label: Text(
                                _preparationStartAt == null
                                    ? 'Lernbeginn'
                                    : DateFormat('dd.MM.yyyy')
                                          .format(_preparationStartAt!),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickEnd,
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                _endAt == null
                                    ? 'Endzeit'
                                    : DateFormat.Hm().format(_endAt!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _room,
                          decoration: const InputDecoration(labelText: 'Raum'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _onlineUrl,
                          decoration: const InputDecoration(
                            labelText: 'Online-Link',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _examiner,
                          decoration: const InputDecoration(
                            labelText: 'Prüfer/in',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Beschreibung',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Lernstoff',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _topic,
                                decoration: const InputDecoration(
                                  labelText: 'Thema',
                                ),
                                onSubmitted: (_) => _addTopic(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Thema hinzufügen',
                              onPressed: _addTopic,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        for (final topic in _topics)
                          CheckboxListTile(
                            value: topic.done,
                            onChanged: (value) => setState(() {
                              _topics = [
                                for (final item in _topics)
                                  if (item.id == topic.id)
                                    item.copyWith(done: value)
                                  else
                                    item,
                              ];
                            }),
                            title: Text(topic.title),
                            contentPadding: EdgeInsets.zero,
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _reminders.isEmpty
                              ? null
                              : _reminders.first,
                          decoration: const InputDecoration(
                            labelText: 'Erinnerung',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                'Zur Startzeit',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1440,
                              child: Text(
                                '1 Tag vorher',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 2880,
                              child: Text(
                                '2 Tage vorher',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 10080,
                              child: Text(
                                '1 Woche vorher',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 20160,
                              child: Text(
                                '2 Wochen vorher',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(() {
                            _reminders = value == null ? [] : [value];
                          }),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Ergebnis',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 130,
                              child: TextFormField(
                                controller: _grade,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Note',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                controller: _pointsAchieved,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Punkte',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextFormField(
                                controller: _pointsMaximum,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Von',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 190,
                              child: DropdownButton<bool?>(
                                value: _passed,
                                isExpanded: true,
                                hint: const Text('Bestanden?'),
                                items: const [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'Offen',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text(
                                      'Bestanden',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text(
                                      'Nicht bestanden',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  _passed = value;
                                  if (value == true) {
                                    _status = ExamStatus.passed;
                                  }
                                  if (value == false) {
                                    _status = ExamStatus.failed;
                                  }
                                  if (value == null &&
                                      (_status == ExamStatus.passed ||
                                          _status == ExamStatus.failed)) {
                                    _status = ExamStatus.resultPending;
                                  }
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notizen',
                          ),
                        ),
                      ],
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

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 8),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _startAt == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(_startAt!),
    );
    if (!mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
      _endAt ??= _startAt!.add(const Duration(hours: 1, minutes: 30));
    });
  }

  Future<void> _pickEnd() async {
    final start = _startAt ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: _endAt == null
          ? TimeOfDay.fromDateTime(start.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(_endAt!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _endAt = DateTime(
        start.year,
        start.month,
        start.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickPreparationStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _preparationStartAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 8),
    );
    if (date == null || !mounted) return;
    setState(() => _preparationStartAt = date);
  }

  void _addTopic() {
    final title = _topic.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _topics = [
        ..._topics,
        ChapterProgress(
          title,
          false,
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sortOrder: _topics.length,
        ),
      ];
      _topic.clear();
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Endzeit darf nicht vor dem Beginn liegen.'),
        ),
      );
      return;
    }
    final grade = double.tryParse(_grade.text.trim().replaceAll(',', '.'));
    final pointsAchieved = double.tryParse(
      _pointsAchieved.text.trim().replaceAll(',', '.'),
    );
    final pointsMaximum = double.tryParse(
      _pointsMaximum.text.trim().replaceAll(',', '.'),
    );
    if (pointsAchieved != null &&
        pointsMaximum != null &&
        pointsAchieved > pointsMaximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erreichte Punkte dürfen nicht höher als die Gesamtpunkte sein.',
          ),
        ),
      );
      return;
    }
    final old = widget.exam;
    final subjects = ref.read(studyBuddyControllerProvider).subjects;
    final subjectName = _subjectId == null
        ? (_subjectText.isEmpty ? _title.text.trim() : _subjectText)
        : subjects
                  .where((subject) => subject.id == _subjectId)
                  .firstOrNull
                  ?.name ??
              _subjectText;
    final start = _startAt;
    final hasResult =
        grade != null ||
        pointsAchieved != null ||
        pointsMaximum != null ||
        _passed != null;
    final status = _passed == null
        ? (hasResult && _status == ExamStatus.planned
              ? ExamStatus.resultPending
              : _status)
        : (_passed! ? ExamStatus.passed : ExamStatus.failed);
    Navigator.pop(
      context,
      (old ??
              ExamOverview(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                subject: subjectName,
                dateLabel: _dateTimeLabel(start, ''),
              ))
          .copyWith(
            title: _title.text.trim(),
            subject: subjectName,
            dateLabel: _dateTimeLabel(start, old?.dateLabel ?? ''),
            subjectId: _subjectId,
            examType: _type,
            startAt: start,
            endAt: _endAt,
            location: _location.text.trim(),
            room: _room.text.trim(),
            onlineUrl: _onlineUrl.text.trim(),
            examiner: _examiner.text.trim(),
            description: _description.text.trim(),
            status: status,
            priority: _priority,
            preparationStartAt: _preparationStartAt,
            notes: _notes.text.trim(),
            chapters: _topics,
            reminders: _reminders,
            progress: _topics.isEmpty
                ? (old?.progress ?? 0)
                : _topics.where((topic) => topic.done).length / _topics.length,
            grade: grade,
            pointsAchieved: pointsAchieved,
            pointsMaximum: pointsMaximum,
            passed: _passed,
            createdAt: old?.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );
  }
}

int _dateCompare(ExamOverview a, ExamOverview b) {
  final left = a.startAt ?? DateTime(9999);
  final right = b.startAt ?? DateTime(9999);
  return left.compareTo(right);
}

bool _inSmartList(ExamOverview exam, ExamSmartList list) => switch (list) {
  ExamSmartList.all => true,
  ExamSmartList.upcoming => _isUpcomingExam(exam),
  ExamSmartList.today => _isToday(exam.startAt),
  ExamSmartList.week => _isThisWeek(exam.startAt),
  ExamSmartList.month => _isThisMonth(exam.startAt),
  ExamSmartList.preparing => exam.effectiveStatus == ExamStatus.preparing,
  ExamSmartList.completed => exam.isCompleted,
};

bool _isUpcomingExam(ExamOverview exam) {
  if (exam.isCompleted || exam.startAt == null) return false;
  final date = exam.startAt!;
  final today = DateTime.now();
  return !date.isBefore(DateTime(today.year, today.month, today.day));
}

int _countFor(List<ExamOverview> exams, ExamSmartList list) =>
    exams.where((exam) => _inSmartList(exam, list)).length;

String _groupLabel(ExamOverview exam) {
  if (exam.isCompleted) return 'Abgeschlossen';
  if (_isToday(exam.startAt)) return 'Heute';
  if (_isThisWeek(exam.startAt)) return 'Diese Woche';
  if (_isThisMonth(exam.startAt)) return 'Diesen Monat';
  return 'Bevorstehend';
}

String _subjectName(StudyBuddyState state, ExamOverview exam) {
  if (exam.subjectId == null) return exam.subject;
  return state.subjects
          .where((subject) => subject.id == exam.subjectId)
          .firstOrNull
          ?.name ??
      exam.subject;
}

String _smartLabel(ExamSmartList list) => switch (list) {
  ExamSmartList.all => 'Alle',
  ExamSmartList.upcoming => 'Bevorstehend',
  ExamSmartList.today => 'Heute',
  ExamSmartList.week => 'Diese Woche',
  ExamSmartList.month => 'Diesen Monat',
  ExamSmartList.preparing => 'Vorbereitung läuft',
  ExamSmartList.completed => 'Abgeschlossen',
};

String _typeLabel(ExamType type) => switch (type) {
  ExamType.written => 'Klausur',
  ExamType.oral => 'Mündliche Prüfung',
  ExamType.practical => 'Praktische Prüfung',
  ExamType.presentation => 'Präsentation',
  ExamType.assignment => 'Abgabe',
  ExamType.portfolio => 'Portfolio',
  ExamType.colloquium => 'Kolloquium',
  ExamType.test => 'Test',
  ExamType.courseExam => 'Lehrveranstaltungsprüfung',
  ExamType.moduleExam => 'Modulprüfung',
  ExamType.schoolPractice => 'Schulpraxis',
  ExamType.other => 'Sonstige Prüfung',
};

String _statusLabel(ExamStatus status) => switch (status) {
  ExamStatus.planned => 'Geplant',
  ExamStatus.preparing => 'Vorbereitung läuft',
  ExamStatus.today => 'Heute',
  ExamStatus.written => 'Geschrieben',
  ExamStatus.resultPending => 'Ergebnis offen',
  ExamStatus.passed => 'Bestanden',
  ExamStatus.failed => 'Nicht bestanden',
  ExamStatus.cancelled => 'Abgesagt',
};

Color _statusColor(ExamStatus status) => switch (status) {
  ExamStatus.today => AppColors.mauve,
  ExamStatus.preparing => AppColors.lavender,
  ExamStatus.passed => AppColors.sage,
  ExamStatus.failed => const Color(0xFFC66B6B),
  ExamStatus.cancelled => AppColors.mutedInk,
  _ => AppColors.mauve,
};

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.none => 'Keine',
  TaskPriority.low => 'Niedrig',
  TaskPriority.normal => 'Normal',
  TaskPriority.high => 'Hoch',
  TaskPriority.urgent => 'Dringend',
};

String _dateTimeLabel(DateTime? date, String fallback) {
  if (date == null) return fallback.isEmpty ? 'Kein Datum' : fallback;
  return DateFormat('dd.MM.yyyy HH:mm').format(date);
}

String _countdownLabel(ExamOverview exam) {
  final days = exam.daysUntil;
  if (days == null) return 'Ohne Datum';
  if (days == 0) return 'Heute';
  if (days == 1) return 'Morgen';
  if (days < 0) return 'Vor ${days.abs()} Tagen';
  if (days <= 14) return 'Noch $days Tage';
  final weeks = (days / 7).floor();
  if (weeks <= 8) return 'Noch $weeks Wochen';
  return 'In $days Tagen';
}

String _resultLabel(ExamOverview exam) {
  final parts = <String>[];
  if (exam.grade != null) parts.add('Note ${_numberLabel(exam.grade!)}');
  if (exam.pointsAchieved != null || exam.pointsMaximum != null) {
    final achieved = exam.pointsAchieved == null
        ? '-'
        : _numberLabel(exam.pointsAchieved!);
    final maximum = exam.pointsMaximum == null
        ? '-'
        : _numberLabel(exam.pointsMaximum!);
    parts.add('$achieved/$maximum Punkte');
  }
  if (exam.passed != null) {
    parts.add(exam.passed! ? 'Bestanden' : 'Nicht bestanden');
  }
  return parts.join(' · ');
}

String _numberLabel(double value) {
  final rounded = value.roundToDouble();
  if (value == rounded) return rounded.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

bool _isToday(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool _isThisWeek(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - now.weekday + 1);
  final end = start.add(const Duration(days: 7));
  return !date.isBefore(start) && date.isBefore(end);
}

bool _isThisMonth(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month;
}
