import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/design_system/study_badge.dart';
import '../../../shared/design_system/study_card.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  Timer? _ticker;
  TimerMode _mode = TimerMode.focus;
  String? _subjectId;
  String? _examId;
  String? _taskId;
  int _plannedMinutes = 50;
  int _pomodoroFocus = 25;
  int _pomodoroBreak = 5;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBuddyControllerProvider);
    final active = state.studySessions.where((s) => s.isActive).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 90),
          children: [
            Text('Focus', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
            if (active == null)
              _StartPanel(
                state: state,
                mode: _mode,
                subjectId: _subjectId,
                examId: _examId,
                taskId: _taskId,
                plannedMinutes: _plannedMinutes,
                pomodoroFocus: _pomodoroFocus,
                pomodoroBreak: _pomodoroBreak,
                onMode: (value) => setState(() => _mode = value),
                onSubject: (value) => setState(() => _subjectId = value),
                onExam: (value) => setState(() => _examId = value),
                onTask: (value) => setState(() => _taskId = value),
                onPlannedMinutes: (value) =>
                    setState(() => _plannedMinutes = value),
                onPomodoroFocus: (value) =>
                    setState(() => _pomodoroFocus = value),
                onPomodoroBreak: (value) =>
                    setState(() => _pomodoroBreak = value),
                onStart: _startSession,
              )
            else
              _RunningPanel(
                session: active,
                state: state,
                elapsedSeconds: _elapsed(active),
                remainingSeconds: _remaining(active),
                onPauseResume: () => _togglePause(active),
                onFinish: () => _finishSession(active),
                onDiscard: () => _discardSession(active),
              ),
            const SizedBox(height: 18),
            _TodayPanel(
              state: state,
              onEdit: _editSession,
              onDelete: _deleteSession,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession() async {
    final now = DateTime.now();
    final session = StudySession(
      id: now.microsecondsSinceEpoch.toString(),
      mode: _mode,
      status: StudySessionStatus.active,
      startedAt: now,
      subjectId: _subjectId,
      examId: _examId,
      taskId: _taskId,
      plannedDurationSeconds: _mode == TimerMode.stopwatch
          ? null
          : _plannedMinutes * 60,
      pomodoroFocusMinutes: _mode == TimerMode.pomodoro ? _pomodoroFocus : null,
      pomodoroBreakMinutes: _mode == TimerMode.pomodoro ? _pomodoroBreak : null,
      createdAt: now,
      updatedAt: now,
    );
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .saveStudySession(session);
  }

  Future<void> _togglePause(StudySession session) async {
    final now = DateTime.now();
    final elapsed = _elapsed(session);
    final updated = session.status == StudySessionStatus.paused
        ? session.copyWith(status: StudySessionStatus.active, startedAt: now)
        : session.copyWith(
            status: StudySessionStatus.paused,
            focusDurationSeconds: elapsed,
          );
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .saveStudySession(updated);
  }

  Future<void> _finishSession(StudySession session) async {
    final note = TextEditingController();
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Session abschließen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_formatDuration(_elapsed(session))} gelernt'),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Notiz optional'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
      if (save != true) return;
      final now = DateTime.now();
      final updated = session.copyWith(
        status: StudySessionStatus.completed,
        endedAt: now,
        focusDurationSeconds: _elapsed(session),
        note: note.text.trim(),
        updatedAt: now,
      );
      await ref
          .read(studyBuddyControllerProvider.notifier)
          .saveStudySession(updated);
    } finally {
      note.dispose();
    }
  }

  Future<void> _discardSession(StudySession session) async {
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .deleteStudySession(session.id);
  }

  Future<void> _editSession(StudySession session) async {
    final updated = await showDialog<StudySession>(
      context: context,
      builder: (context) => _EditSessionDialog(
        session: session,
        state: ref.read(studyBuddyControllerProvider),
      ),
    );
    if (updated == null) return;
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .saveStudySession(updated.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> _deleteSession(StudySession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session löschen?'),
        content: Text(
          'Die gespeicherte Session "${_sessionTitle(ref.read(studyBuddyControllerProvider), session)}" wird gelöscht.',
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
    if (confirmed != true) return;
    await ref
        .read(studyBuddyControllerProvider.notifier)
        .deleteStudySession(session.id);
  }

  int _elapsed(StudySession session) {
    if (session.status == StudySessionStatus.paused ||
        session.status == StudySessionStatus.completed) {
      return session.focusDurationSeconds;
    }
    return session.focusDurationSeconds +
        DateTime.now().difference(session.startedAt).inSeconds;
  }

  int? _remaining(StudySession session) {
    final planned = session.plannedDurationSeconds;
    if (planned == null) return null;
    return (planned - _elapsed(session)).clamp(0, planned);
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.state,
    required this.mode,
    required this.subjectId,
    required this.examId,
    required this.taskId,
    required this.plannedMinutes,
    required this.pomodoroFocus,
    required this.pomodoroBreak,
    required this.onMode,
    required this.onSubject,
    required this.onExam,
    required this.onTask,
    required this.onPlannedMinutes,
    required this.onPomodoroFocus,
    required this.onPomodoroBreak,
    required this.onStart,
  });

  final StudyBuddyState state;
  final TimerMode mode;
  final String? subjectId, examId, taskId;
  final int plannedMinutes, pomodoroFocus, pomodoroBreak;
  final ValueChanged<TimerMode> onMode;
  final ValueChanged<String?> onSubject, onExam, onTask;
  final ValueChanged<int> onPlannedMinutes, onPomodoroFocus, onPomodoroBreak;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => StudyCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Was möchtest du lernen?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Dropdown<String?>(
              label: 'Fach',
              value: subjectId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Kein Fach')),
                for (final subject in state.subjects)
                  DropdownMenuItem(
                    value: subject.id,
                    child: Text(subject.name),
                  ),
              ],
              onChanged: onSubject,
            ),
            _Dropdown<String?>(
              label: 'Prüfung',
              value: examId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Keine Prüfung'),
                ),
                for (final exam in state.exams)
                  DropdownMenuItem(value: exam.id, child: Text(exam.title)),
              ],
              onChanged: onExam,
            ),
            _Dropdown<String?>(
              label: 'Aufgabe',
              value: taskId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Keine Aufgabe'),
                ),
                for (final task in state.tasks.where((t) => !t.done))
                  DropdownMenuItem(value: task.id, child: Text(task.title)),
              ],
              onChanged: onTask,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SegmentedButton<TimerMode>(
          segments: const [
            ButtonSegment(value: TimerMode.focus, label: Text('Focus')),
            ButtonSegment(value: TimerMode.pomodoro, label: Text('Pomodoro')),
            ButtonSegment(value: TimerMode.countdown, label: Text('Countdown')),
            ButtonSegment(value: TimerMode.stopwatch, label: Text('Stoppuhr')),
          ],
          selected: {mode},
          onSelectionChanged: (value) => onMode(value.single),
        ),
        const SizedBox(height: 16),
        if (mode != TimerMode.stopwatch)
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in [15, 25, 30, 45, 50, 60, 90])
                ChoiceChip(
                  label: Text('$minutes min'),
                  selected: plannedMinutes == minutes,
                  onSelected: (_) => onPlannedMinutes(minutes),
                ),
            ],
          ),
        if (mode == TimerMode.pomodoro) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: pomodoroFocus.toDouble(),
                        min: 15,
                        max: 60,
                        divisions: 9,
                        label: 'Focus $pomodoroFocus',
                        onChanged: (value) => onPomodoroFocus(value.round()),
                      ),
                    ),
                    Text('Focus $pomodoroFocus min'),
                  ],
                ),
              ),
              SizedBox(
                width: 260,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: pomodoroBreak.toDouble(),
                        min: 5,
                        max: 20,
                        divisions: 3,
                        label: 'Pause $pomodoroBreak',
                        onChanged: (value) => onPomodoroBreak(value.round()),
                      ),
                    ),
                    Text('Pause $pomodoroBreak min'),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Lernen starten'),
        ),
      ],
    ),
  );
}

class _RunningPanel extends StatelessWidget {
  const _RunningPanel({
    required this.session,
    required this.state,
    required this.elapsedSeconds,
    required this.remainingSeconds,
    required this.onPauseResume,
    required this.onFinish,
    required this.onDiscard,
  });

  final StudySession session;
  final StudyBuddyState state;
  final int elapsedSeconds;
  final int? remainingSeconds;
  final VoidCallback onPauseResume, onFinish, onDiscard;

  @override
  Widget build(BuildContext context) {
    final subject = state.subjects
        .where((s) => s.id == session.subjectId)
        .firstOrNull;
    final task = state.tasks.where((t) => t.id == session.taskId).firstOrNull;
    return StudyCard(
      child: Column(
        children: [
          StudyBadge(label: _modeLabel(session.mode)),
          const SizedBox(height: 18),
          if (subject != null)
            Text(
              subject.name.toUpperCase(),
              style: const TextStyle(
                color: AppColors.mauve,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            _formatDuration(remainingSeconds ?? elapsedSeconds),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          if (task != null) Text(task.title),
          if (session.status == StudySessionStatus.paused)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: StudyBadge(label: 'Pausiert'),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onPauseResume,
                icon: Icon(
                  session.status == StudySessionStatus.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
                label: Text(
                  session.status == StudySessionStatus.paused
                      ? 'Fortsetzen'
                      : 'Pause',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Session beenden'),
              ),
              TextButton(onPressed: onDiscard, child: const Text('Verwerfen')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyBuddyState state;
  final ValueChanged<StudySession> onEdit;
  final ValueChanged<StudySession> onDelete;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todaySessions =
        state.studySessions
            .where(
              (s) =>
                  s.status == StudySessionStatus.completed &&
                  s.endedAt != null &&
                  _isSameDay(s.endedAt!, today),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final allSessions =
        state.studySessions
            .where((s) => s.status == StudySessionStatus.completed)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final seconds = todaySessions.fold<int>(
      0,
      (sum, s) => sum + s.focusDurationSeconds,
    );
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heute', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${_formatDuration(seconds)} gelernt'),
          const SizedBox(height: 12),
          if (todaySessions.isEmpty)
            const Text('Heute ist noch keine gespeicherte Session vorhanden.'),
          for (final session in todaySessions.take(6))
            _SessionTile(
              state: state,
              session: session,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          if (allSessions.length > todaySessions.length) ...[
            const SizedBox(height: 18),
            Text(
              'Gespeicherte Sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final session
                in allSessions
                    .where(
                      (s) =>
                          s.endedAt == null || !_isSameDay(s.endedAt!, today),
                    )
                    .take(8))
              _SessionTile(
                state: state,
                session: session,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.state,
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyBuddyState state;
  final StudySession session;
  final ValueChanged<StudySession> onEdit;
  final ValueChanged<StudySession> onDelete;

  @override
  Widget build(BuildContext context) {
    final date = session.endedAt ?? session.startedAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.timer_outlined),
      title: Text(_sessionTitle(state, session)),
      subtitle: Text(
        '${DateFormat('dd.MM.yyyy HH:mm').format(date)} · ${_modeLabel(session.mode)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatDuration(session.focusDurationSeconds)),
          PopupMenuButton<_SessionAction>(
            tooltip: 'Session-Aktionen',
            onSelected: (action) {
              switch (action) {
                case _SessionAction.edit:
                  onEdit(session);
                case _SessionAction.delete:
                  onDelete(session);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SessionAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Bearbeiten'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _SessionAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Löschen'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditSessionDialog extends StatefulWidget {
  const _EditSessionDialog({required this.session, required this.state});

  final StudySession session;
  final StudyBuddyState state;

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  late TimerMode _mode;
  late String? _subjectId;
  late String? _examId;
  late String? _taskId;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TextEditingController _durationController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _mode = session.mode;
    _subjectId = session.subjectId;
    _examId = session.examId;
    _taskId = session.taskId;
    _date = DateTime(
      session.startedAt.year,
      session.startedAt.month,
      session.startedAt.day,
    );
    _startTime = TimeOfDay.fromDateTime(session.startedAt);
    _durationController = TextEditingController(
      text: ((session.focusDurationSeconds / 60).round())
          .clamp(1, 9999)
          .toString(),
    );
    _noteController = TextEditingController(text: session.note);
  }

  @override
  void dispose() {
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session bearbeiten'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<TimerMode>(
                segments: const [
                  ButtonSegment(value: TimerMode.focus, label: Text('Focus')),
                  ButtonSegment(
                    value: TimerMode.pomodoro,
                    label: Text('Pomodoro'),
                  ),
                  ButtonSegment(
                    value: TimerMode.countdown,
                    label: Text('Countdown'),
                  ),
                  ButtonSegment(
                    value: TimerMode.stopwatch,
                    label: Text('Stoppuhr'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.single),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat('dd.MM.yyyy').format(_date)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_startTime.format(context)),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Dauer',
                        suffixText: 'min',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Dropdown<String?>(
                    label: 'Fach',
                    value: _subjectId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Kein Fach'),
                      ),
                      for (final subject in widget.state.subjects)
                        DropdownMenuItem(
                          value: subject.id,
                          child: Text(subject.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _subjectId = value),
                  ),
                  _Dropdown<String?>(
                    label: 'Prüfung',
                    value: _examId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Keine Prüfung'),
                      ),
                      for (final exam in widget.state.exams)
                        DropdownMenuItem(
                          value: exam.id,
                          child: Text(exam.title),
                        ),
                    ],
                    onChanged: (value) => setState(() => _examId = value),
                  ),
                  _Dropdown<String?>(
                    label: 'Aufgabe',
                    value: _taskId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Keine Aufgabe'),
                      ),
                      for (final task in widget.state.tasks)
                        DropdownMenuItem(
                          value: task.id,
                          child: Text(task.title),
                        ),
                    ],
                    onChanged: (value) => setState(() => _taskId = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Notiz'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  void _submit() {
    final durationMinutes = int.tryParse(_durationController.text.trim());
    if (durationMinutes == null || durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib eine gültige Dauer ein.')),
      );
      return;
    }
    final startedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    final durationSeconds = durationMinutes * 60;
    Navigator.pop(
      context,
      widget.session.copyWith(
        mode: _mode,
        subjectId: _subjectId,
        examId: _examId,
        taskId: _taskId,
        startedAt: startedAt,
        endedAt: startedAt.add(Duration(seconds: durationSeconds)),
        focusDurationSeconds: durationSeconds,
        note: _noteController.text.trim(),
        plannedDurationSeconds: _mode == TimerMode.stopwatch
            ? null
            : durationSeconds,
        pomodoroFocusMinutes: _mode == TimerMode.pomodoro
            ? widget.session.pomodoroFocusMinutes ?? 25
            : null,
        pomodoroBreakMinutes: _mode == TimerMode.pomodoro
            ? widget.session.pomodoroBreakMinutes ?? 5
            : null,
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    ),
  );
}

enum _SessionAction { edit, delete }

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDuration(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final rest = safe % 60;
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours > 0) return '${hours}h ${mins.toString().padLeft(2, '0')}';
  return '${mins.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}

String _modeLabel(TimerMode mode) => switch (mode) {
  TimerMode.focus => 'Focus',
  TimerMode.pomodoro => 'Pomodoro',
  TimerMode.countdown => 'Countdown',
  TimerMode.stopwatch => 'Stoppuhr',
};

String _sessionTitle(StudyBuddyState state, StudySession session) {
  final task = state.tasks.where((t) => t.id == session.taskId).firstOrNull;
  if (task != null) return task.title;
  final subject = state.subjects
      .where((s) => s.id == session.subjectId)
      .firstOrNull;
  return subject?.name ?? 'Lernsession';
}
