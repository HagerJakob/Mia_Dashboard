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

enum TaskSmartList {
  all,
  today,
  tomorrow,
  week,
  upcoming,
  overdue,
  noDeadline,
  important,
  completed,
}

enum TaskSortMode { smart, deadline, priority, created, alpha, updated }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _search = TextEditingController();
  var _list = TaskSmartList.all;
  var _sort = TaskSortMode.smart;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBuddyControllerProvider);
    final tasks = _visibleTasks(state);
    final groups = _group(tasks);
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: compact
          ? FloatingActionButton(
              tooltip: 'Neue Aufgabe',
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
                    for (final list in TaskSmartList.values)
                      _SmartListTile(
                        list: list,
                        selected: _list == list,
                        count: _countFor(state.tasks, list),
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
                          'Aufgaben',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (!compact)
                        FilledButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Neue Aufgabe'),
                        ),
                    ],
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
                          DropdownButton<TaskSmartList>(
                            value: _list,
                            items: [
                              for (final list in TaskSmartList.values)
                                DropdownMenuItem(
                                  value: list,
                                  child: Text(_smartLabel(list)),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _list = value!),
                          ),
                        DropdownButton<TaskSortMode>(
                          value: _sort,
                          items: [
                            for (final sort in TaskSortMode.values)
                              DropdownMenuItem(
                                value: sort,
                                child: Text(_sortLabel(sort)),
                              ),
                          ],
                          onChanged: (value) => setState(() => _sort = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (tasks.isEmpty)
                    StudyCard(
                      child: StudyEmptyState(
                        icon: Icons.checklist_rounded,
                        message: _list == TaskSmartList.today
                            ? 'Für heute ist alles erledigt.'
                            : 'Noch keine passenden Aufgaben.',
                      ),
                    )
                  else
                    for (final entry in groups.entries) ...[
                      _GroupHeader(title: entry.key, count: entry.value.length),
                      const SizedBox(height: 8),
                      for (final task in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TaskRow(
                            task: task,
                            subjectName: _subjectName(state, task.subjectId),
                            onToggle: () => ref
                                .read(studyBuddyControllerProvider.notifier)
                                .toggleTask(task.id),
                            onOpen: () => _openEditor(task),
                            onDelete: () => _deleteTask(task),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TaskItem> _visibleTasks(StudyBuddyState state) {
    final query = _search.text.trim().toLowerCase();
    final filtered = state.tasks.where((task) {
      if (!_inSmartList(task, _list)) return false;
      if (query.isEmpty) return true;
      final subject = _subjectName(state, task.subjectId).toLowerCase();
      return [
        task.title,
        task.description,
        task.category,
        subject,
        ...task.tags,
      ].any((text) => text.toLowerCase().contains(query));
    }).toList();
    filtered.sort(_compareTasks);
    return filtered;
  }

  Map<String, List<TaskItem>> _group(List<TaskItem> tasks) {
    final result = <String, List<TaskItem>>{};
    for (final task in tasks) {
      final label = _groupLabel(task);
      result.putIfAbsent(label, () => []).add(task);
    }
    return result;
  }

  int _compareTasks(TaskItem a, TaskItem b) {
    int priority(TaskItem task) => switch (task.priority) {
      TaskPriority.urgent => 0,
      TaskPriority.high => 1,
      TaskPriority.normal => 2,
      TaskPriority.low => 3,
      TaskPriority.none => 4,
    };

    return switch (_sort) {
      TaskSortMode.deadline => _dateCompare(a.dueAt, b.dueAt),
      TaskSortMode.priority => priority(a).compareTo(priority(b)),
      TaskSortMode.created => _dateCompare(a.createdAt, b.createdAt),
      TaskSortMode.alpha => a.title.compareTo(b.title),
      TaskSortMode.updated => _dateCompare(b.updatedAt, a.updatedAt),
      TaskSortMode.smart =>
        (_rank(a), priority(a), a.dueAt ?? DateTime(9999)).toString().compareTo(
          (_rank(b), priority(b), b.dueAt ?? DateTime(9999)).toString(),
        ),
    };
  }

  int _dateCompare(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int _rank(TaskItem task) {
    if (task.done) return 6;
    if (task.isOverdue) return 0;
    if (_isToday(task.dueAt)) return 1;
    if (task.priority == TaskPriority.urgent ||
        task.priority == TaskPriority.high) {
      return 2;
    }
    if (task.dueAt != null) return 3;
    return 4;
  }

  bool _inSmartList(TaskItem task, TaskSmartList list) => switch (list) {
    TaskSmartList.all => !task.done,
    TaskSmartList.today => _isToday(task.dueAt) && !task.done,
    TaskSmartList.tomorrow => _isTomorrow(task.dueAt) && !task.done,
    TaskSmartList.week => _isThisWeek(task.dueAt) && !task.done,
    TaskSmartList.upcoming => task.dueAt != null && !task.done,
    TaskSmartList.overdue => task.isOverdue,
    TaskSmartList.noDeadline => task.dueAt == null && !task.done,
    TaskSmartList.important =>
      (task.priority == TaskPriority.high ||
              task.priority == TaskPriority.urgent) &&
          !task.done,
    TaskSmartList.completed => task.done,
  };

  int _countFor(List<TaskItem> tasks, TaskSmartList list) =>
      tasks.where((task) => _inSmartList(task, list)).length;

  String _subjectName(StudyBuddyState state, String? id) => id == null
      ? ''
      : state.subjects.where((subject) => subject.id == id).firstOrNull?.name ??
            'Gelöschtes Fach';

  String _groupLabel(TaskItem task) {
    if (task.done) return 'Erledigt';
    if (task.isOverdue) return 'Überfällig';
    if (_isToday(task.dueAt)) return 'Heute';
    if (_isTomorrow(task.dueAt)) return 'Morgen';
    if (_isThisWeek(task.dueAt)) return 'Diese Woche';
    if (task.dueAt == null) return 'Ohne Deadline';
    return 'Später';
  }

  Future<void> _openEditor([TaskItem? task]) async {
    final result = await showDialog<TaskItem>(
      context: context,
      builder: (_) => _TaskEditor(task: task),
    );
    if (result == null || !mounted) return;
    await ref.read(studyBuddyControllerProvider.notifier).saveTask(result);
  }

  Future<void> _deleteTask(TaskItem task) async {
    final deleted = task;
    await ref.read(studyBuddyControllerProvider.notifier).deleteTask(task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Aufgabe gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () =>
              ref.read(studyBuddyControllerProvider.notifier).saveTask(deleted),
        ),
      ),
    );
  }
}

class _SmartListTile extends StatelessWidget {
  const _SmartListTile({
    required this.list,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final TaskSmartList list;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.blush : Colors.transparent,
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

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.subjectName,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
  });

  final TaskItem task;
  final String subjectName;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priority = _priorityLabel(task.priority);
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: StudyRadius.medium,
        child: Row(
          children: [
            IconButton(
              tooltip: task.done ? 'Wieder öffnen' : 'Erledigen',
              onPressed: onToggle,
              icon: Icon(
                task.done ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: task.done ? AppColors.sage : AppColors.mutedInk,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (subjectName.isNotEmpty) Text(subjectName),
                      if (task.dueAt != null) Text(_dateLabel(task.dueAt!)),
                      if (priority.isNotEmpty) Text(priority),
                      if (task.subtasks.isNotEmpty)
                        Text(
                          '${task.completedSubtasks}/${task.subtasks.length} erledigt',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (task.priority == TaskPriority.high ||
                task.priority == TaskPriority.urgent)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: task.priority == TaskPriority.urgent
                      ? const Color(0xFFC66B6B)
                      : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            IconButton(
              tooltip: 'Löschen',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({this.task});

  final TaskItem? task;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final _duration = TextEditingController();
  final _subtask = TextEditingController();
  var _priority = TaskPriority.normal;
  var _category = 'Uni';
  String? _subjectId;
  DateTime? _dueAt;
  var _showMore = false;
  var _subtasks = <TaskSubtask>[];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _title.text = task.title;
      _description.text = task.description;
      _tags.text = task.tags.join(', ');
      _duration.text = task.estimatedMinutes?.toString() ?? '';
      _priority = task.priority;
      _category = task.category;
      _subjectId = task.subjectId;
      _dueAt = task.dueAt;
      _subtasks = [...task.subtasks];
      _showMore =
          task.description.isNotEmpty ||
          task.tags.isNotEmpty ||
          task.estimatedMinutes != null ||
          task.subtasks.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _duration.dispose();
    _subtask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(studyBuddyControllerProvider).subjects;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
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
                      widget.task == null
                          ? 'Neue Aufgabe'
                          : 'Aufgabe bearbeiten',
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
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickDueDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _dueAt == null
                                  ? 'Keine Deadline'
                                  : DateFormat('dd.MM.yyyy HH:mm')
                                        .format(_dueAt!),
                            ),
                          ),
                          DropdownButton<TaskPriority>(
                            value: _priority,
                            items: [
                              for (final priority in TaskPriority.values)
                                DropdownMenuItem(
                                  value: priority,
                                  child: Text(
                                    _priorityLabel(priority).isEmpty
                                        ? 'Keine'
                                        : _priorityLabel(priority),
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _priority = value!),
                          ),
                          DropdownButton<String?>(
                            value: _subjectId,
                            hint: const Text('Fach'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Kein Fach'),
                              ),
                              for (final subject in subjects)
                                DropdownMenuItem<String?>(
                                  value: subject.id,
                                  child: Text(subject.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _subjectId = value),
                          ),
                        ],
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
                        TextFormField(
                          controller: _description,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Beschreibung',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Kategorie',
                          ),
                          items:
                              const [
                                    'Uni',
                                    'Lernen',
                                    'Abgabe',
                                    'Schulpraxis',
                                    'Privat',
                                    'Haushalt',
                                    'Arbeit',
                                    'Sonstiges',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => _category = value!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _tags,
                          decoration: const InputDecoration(
                            labelText: 'Tags, kommagetrennt',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _duration,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Geschätzte Dauer in Minuten',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Unteraufgaben',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _subtask,
                                decoration: const InputDecoration(
                                  labelText: 'Unteraufgabe',
                                ),
                                onSubmitted: (_) => _addSubtask(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Unteraufgabe hinzufügen',
                              onPressed: _addSubtask,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        for (final subtask in _subtasks)
                          CheckboxListTile(
                            value: subtask.isCompleted,
                            onChanged: (value) => setState(() {
                              _subtasks = [
                                for (final item in _subtasks)
                                  if (item.id == subtask.id)
                                    item.copyWith(isCompleted: value)
                                  else
                                    item,
                              ];
                            }),
                            title: Text(subtask.title),
                            contentPadding: EdgeInsets.zero,
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 8),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(_dueAt!),
    );
    if (!mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  void _addSubtask() {
    final title = _subtask.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subtasks = [
        ..._subtasks,
        TaskSubtask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          sortOrder: _subtasks.length,
        ),
      ];
      _subtask.clear();
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final old = widget.task;
    Navigator.pop(
      context,
      (old ??
              TaskItem(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: '',
              ))
          .copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            priority: _priority,
            dueAt: _dueAt,
            subjectId: _subjectId,
            category: _category,
            tags: _tags.text
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList(),
            estimatedMinutes: int.tryParse(_duration.text.trim()),
            subtasks: _subtasks,
            createdAt: old?.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );
  }
}

bool _isToday(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool _isTomorrow(DateTime? date) {
  if (date == null) return false;
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return date.year == tomorrow.year &&
      date.month == tomorrow.month &&
      date.day == tomorrow.day;
}

bool _isThisWeek(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - now.weekday + 1);
  final end = start.add(const Duration(days: 7));
  return !date.isBefore(start) && date.isBefore(end);
}

String _smartLabel(TaskSmartList list) => switch (list) {
  TaskSmartList.all => 'Alle Aufgaben',
  TaskSmartList.today => 'Heute',
  TaskSmartList.tomorrow => 'Morgen',
  TaskSmartList.week => 'Diese Woche',
  TaskSmartList.upcoming => 'Bevorstehend',
  TaskSmartList.overdue => 'Überfällig',
  TaskSmartList.noDeadline => 'Ohne Deadline',
  TaskSmartList.important => 'Wichtig',
  TaskSmartList.completed => 'Erledigt',
};

String _sortLabel(TaskSortMode sort) => switch (sort) {
  TaskSortMode.smart => 'Intelligent',
  TaskSortMode.deadline => 'Deadline',
  TaskSortMode.priority => 'Priorität',
  TaskSortMode.created => 'Erstellt',
  TaskSortMode.alpha => 'Alphabetisch',
  TaskSortMode.updated => 'Zuletzt geändert',
};

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.none => '',
  TaskPriority.low => 'Niedrig',
  TaskPriority.normal => 'Normal',
  TaskPriority.high => 'Hoch',
  TaskPriority.urgent => 'Dringend',
};

String _dateLabel(DateTime date) {
  if (_isToday(date)) return 'Heute ${DateFormat.Hm().format(date)}';
  if (_isTomorrow(date)) return 'Morgen ${DateFormat.Hm().format(date)}';
  return DateFormat('dd.MM.yyyy HH:mm').format(date);
}
