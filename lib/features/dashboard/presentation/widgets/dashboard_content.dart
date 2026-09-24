import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/responsive_layout.dart';
import '../../../../features/calendar/domain/calendar_models.dart';
import '../../../../features/calendar/domain/calendar_services.dart';
import '../../../../features/calendar/presentation/calendar_controller.dart';
import '../../../../features/statistics/data/analytics_service.dart';
import '../../../../shared/design_system/study_card.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/dashboard_models.dart';
import '../dashboard_controller.dart';
import 'add_entry_sheet.dart';

class DashboardContent extends ConsumerWidget {
  const DashboardContent({required this.state, super.key});

  final StudyBuddyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(calendarControllerProvider);
    final controller = ref.read(studyBuddyControllerProvider.notifier);
    final calendarController = ref.read(calendarControllerProvider.notifier);
    final model = DashboardViewModel.from(
      state: state,
      occurrences: calendarController.occurrences(
        _dayStart(DateTime.now()),
        _dayStart(DateTime.now()).add(const Duration(days: 1)),
      ),
      analytics: const AnalyticsService(),
      now: DateTime.now(),
    );
    final compact = context.isCompact;
    final padding = compact ? 18.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(padding, compact ? 18 : 24, padding, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(
            model: model,
            compact: compact,
            onAddTask: () => showTaskSheet(context, controller),
            onAddEvent: () => showScheduleSheet(context, controller),
            onAddNote: () => showNoteSheet(context, controller),
            onAddExam: () => showExamSheet(context, controller),
            onStartLearning: () => controller.selectDestination(6),
          ),
          const SizedBox(height: 18),
          if (model.activeSession != null) ...[
            _ActiveSessionBanner(
              session: model.activeSession!,
              state: state,
              onOpenTimer: () => controller.selectDestination(6),
            ),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1040;
              if (!desktop) {
                return Column(
                  children: [
                    _TodayCard(model: model),
                    const SizedBox(height: 16),
                    _TasksCard(
                      model: model,
                      onToggle: controller.toggleTask,
                      onAdd: () => showTaskSheet(context, controller),
                      onOpenTasks: () => controller.selectDestination(2),
                    ),
                    const SizedBox(height: 16),
                    _NextExamCard(
                      model: model,
                      onOpenExams: () => controller.selectDestination(5),
                      onStartLearning: () => controller.selectDestination(6),
                    ),
                    const SizedBox(height: 16),
                    _FocusCard(
                      model: model,
                      onOpenTimer: () => controller.selectDestination(6),
                    ),
                    const SizedBox(height: 16),
                    _WeekCard(
                      model: model,
                      onOpenCalendar: () {
                        ref.read(calendarControllerProvider.notifier)
                          ..setView(CalendarView.day)
                          ..selectDate(DateTime.now());
                        controller.selectDestination(1);
                      },
                    ),
                    const SizedBox(height: 16),
                    _BottomGrid(model: model, controller: controller),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _TodayCard(model: model)),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 2,
                        child: _NextExamCard(
                          model: model,
                          onOpenExams: () => controller.selectDestination(5),
                          onStartLearning: () =>
                              controller.selectDestination(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _TasksCard(
                          model: model,
                          onToggle: controller.toggleTask,
                          onAdd: () => showTaskSheet(context, controller),
                          onOpenTasks: () => controller.selectDestination(2),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _FocusCard(
                          model: model,
                          onOpenTimer: () => controller.selectDestination(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _WeekCard(
                    model: model,
                    onOpenCalendar: () {
                      ref.read(calendarControllerProvider.notifier)
                        ..setView(CalendarView.day)
                        ..selectDate(DateTime.now());
                      controller.selectDestination(1);
                    },
                  ),
                  const SizedBox(height: 18),
                  _BottomGrid(model: model, controller: controller),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashboardViewModel {
  const DashboardViewModel({
    required this.now,
    required this.greeting,
    required this.dateLabel,
    required this.timeline,
    required this.relevantTasks,
    required this.overdueTaskCount,
    required this.nextExam,
    required this.upcomingExams,
    required this.todayStudySeconds,
    required this.weekStudySeconds,
    required this.dailyGoalSeconds,
    required this.streakDays,
    required this.weekDays,
    required this.recentNotes,
    required this.activeSession,
    required this.nextAppointment,
  });

  final DateTime now;
  final String greeting;
  final String dateLabel;
  final List<DashboardTimelineItem> timeline;
  final List<TaskItem> relevantTasks;
  final int overdueTaskCount;
  final ExamOverview? nextExam;
  final List<ExamOverview> upcomingExams;
  final int todayStudySeconds;
  final int weekStudySeconds;
  final int dailyGoalSeconds;
  final int streakDays;
  final List<DashboardWeekDay> weekDays;
  final List<NoteItem> recentNotes;
  final StudySession? activeSession;
  final DashboardTimelineItem? nextAppointment;

  static DashboardViewModel from({
    required StudyBuddyState state,
    required List<CalendarOccurrence> occurrences,
    required AnalyticsService analytics,
    required DateTime now,
  }) {
    final today = _dayStart(now);
    final todayRange = AnalyticsRange(
      period: AnalyticsPeriod.custom,
      start: today,
      end: today,
    );
    final weekRange = analytics.weekRange(now);
    final todayReport = analytics.buildReport(state, todayRange);
    final weekReport = analytics.buildReport(state, weekRange);
    final timeline = _buildTimeline(state, occurrences, today)
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return (a.startAt ?? today).compareTo(b.startAt ?? today);
      });
    final relevantTasks = _relevantTasks(state.tasks, now);
    final nextExam = _nextExams(state.exams, now).firstOrNull;
    final weekDays = [
      for (var i = 0; i < 7; i++)
        DashboardWeekDay(
          date: weekRange.start.add(Duration(days: i)),
          studySeconds: weekReport.dailyStudy[i].seconds,
          hasEvent: occurrences.any(
            (occurrence) => sameDay(
              occurrence.startAt,
              weekRange.start.add(Duration(days: i)),
            ),
          ),
          hasExam: state.exams.any(
            (exam) =>
                exam.startAt != null &&
                sameDay(
                  exam.startAt!,
                  weekRange.start.add(Duration(days: i)),
                ) &&
                exam.status != ExamStatus.cancelled,
          ),
          isToday: sameDay(now, weekRange.start.add(Duration(days: i))),
        ),
    ];
    final recentNotes = [...state.notes]
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1900);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });
    return DashboardViewModel(
      now: now,
      greeting: _greeting(now),
      dateLabel: _dateLabel(now),
      timeline: timeline.take(8).toList(),
      relevantTasks: relevantTasks.take(5).toList(),
      overdueTaskCount: state.tasks.where((task) => task.isOverdue).length,
      nextExam: nextExam,
      upcomingExams: _nextExams(state.exams, now).skip(1).take(2).toList(),
      todayStudySeconds: todayReport.studySeconds,
      weekStudySeconds: weekReport.studySeconds,
      dailyGoalSeconds: 2 * 60 * 60,
      streakDays: todayReport.streakStats.currentDays,
      weekDays: weekDays,
      recentNotes: recentNotes.take(4).toList(),
      activeSession: state.studySessions
          .where((session) => session.isActive)
          .firstOrNull,
      nextAppointment: timeline
          .where((item) => item.startAt != null && item.startAt!.isAfter(now))
          .firstOrNull,
    );
  }
}

class DashboardTimelineItem {
  const DashboardTimelineItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.startAt,
    this.endAt,
    this.allDay = false,
    this.color = AppColors.mauve,
  });

  final String id;
  final DashboardTimelineType type;
  final String title;
  final String subtitle;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool allDay;
  final Color color;
}

enum DashboardTimelineType { schedule, exam, taskDeadline }

class DashboardWeekDay {
  const DashboardWeekDay({
    required this.date,
    required this.studySeconds,
    required this.hasEvent,
    required this.hasExam,
    required this.isToday,
  });

  final DateTime date;
  final int studySeconds;
  final bool hasEvent;
  final bool hasExam;
  final bool isToday;
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.model,
    required this.compact,
    required this.onAddTask,
    required this.onAddEvent,
    required this.onAddNote,
    required this.onAddExam,
    required this.onStartLearning,
  });

  final DashboardViewModel model;
  final bool compact;
  final VoidCallback onAddTask;
  final VoidCallback onAddEvent;
  final VoidCallback onAddNote;
  final VoidCallback onAddExam;
  final VoidCallback onStartLearning;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${model.greeting}, Mia ♡',
                  style: compact
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${model.dateLabel} · Dein Tag auf einen Blick',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.mutedInk, height: 1.45),
                ),
              ],
            ),
          ),
          if (!compact)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickButton(
                  label: 'Aufgabe',
                  icon: Icons.add_task_rounded,
                  onTap: onAddTask,
                ),
                _QuickButton(
                  label: 'Termin',
                  icon: Icons.event_rounded,
                  onTap: onAddEvent,
                ),
                _QuickButton(
                  label: 'Notiz',
                  icon: Icons.note_add_rounded,
                  onTap: onAddNote,
                ),
                _QuickButton(
                  label: 'Prüfung',
                  icon: Icons.school_rounded,
                  onTap: onAddExam,
                ),
                FilledButton.icon(
                  onPressed: onStartLearning,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lernen'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ActiveSessionBanner extends StatelessWidget {
  const _ActiveSessionBanner({
    required this.session,
    required this.state,
    required this.onOpenTimer,
  });

  final StudySession session;
  final StudyBuddyState state;
  final VoidCallback onOpenTimer;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      backgroundColor: AppColors.blush,
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: AppColors.mauve),
          const SizedBox(width: 12),
          Expanded(
            child: _LiveSessionText(session: session, state: state),
          ),
          FilledButton.icon(
            onPressed: onOpenTimer,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Zur Session'),
          ),
        ],
      ),
    );
  }
}

class _LiveSessionText extends StatefulWidget {
  const _LiveSessionText({required this.session, required this.state});
  final StudySession session;
  final StudyBuddyState state;

  @override
  State<_LiveSessionText> createState() => _LiveSessionTextState();
}

class _LiveSessionTextState extends State<_LiveSessionText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.state.subjects
        .where((subject) => subject.id == widget.session.subjectId)
        .firstOrNull;
    final elapsed = widget.session.status == StudySessionStatus.paused
        ? widget.session.focusDurationSeconds
        : widget.session.focusDurationSeconds +
              DateTime.now().difference(widget.session.startedAt).inSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.session.status == StudySessionStatus.paused
              ? 'Focus pausiert'
              : 'Focus läuft',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(
          '${subject?.name ?? 'Lernsession'} · ${formatDuration(elapsed)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.model});
  final DashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    final allDay = model.timeline.where((item) => item.allDay).toList();
    final timed = model.timeline.where((item) => !item.allDay).toList();
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Heute', icon: Icons.wb_sunny_outlined),
          if (model.nextAppointment != null) ...[
            const SizedBox(height: 12),
            _NextUp(item: model.nextAppointment!, now: model.now),
          ],
          const SizedBox(height: 16),
          if (allDay.isNotEmpty) ...[
            Text('Ganztägig', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final item in allDay) _TimelineRow(item: item),
          ],
          if (timed.isEmpty && allDay.isEmpty)
            const _EmptyText('Keine Termine mehr für heute.')
          else
            for (final item in timed) _TimelineRow(item: item),
        ],
      ),
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.item, required this.now});
  final DashboardTimelineItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final minutes = item.startAt!.difference(now).inMinutes;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lilac.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me_outlined, color: AppColors.mauve),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Als Nächstes: ${item.title}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(minutes <= 0 ? 'jetzt' : 'in $minutes min'),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});
  final DashboardTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final time = item.allDay
        ? 'ganztägig'
        : item.startAt == null
        ? ''
        : DateFormat.Hm().format(item.startAt!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              time,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: AppColors.mutedInk),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (item.subtitle.isNotEmpty)
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.model,
    required this.onToggle,
    required this.onAdd,
    required this.onOpenTasks,
  });

  final DashboardViewModel model;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Aufgaben',
            icon: Icons.check_circle_outline_rounded,
            actionLabel: 'Aufgabe',
            onAction: onAdd,
          ),
          if (model.overdueTaskCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${model.overdueTaskCount} überfällige Aufgabe${model.overdueTaskCount == 1 ? '' : 'n'}',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (model.relevantTasks.isEmpty)
            const _EmptyText('Für heute ist alles erledigt.')
          else
            for (final task in model.relevantTasks)
              CheckboxListTile(
                value: task.done,
                onChanged: (_) => onToggle(task.id),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(_taskSubtitle(task)),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenTasks,
              child: const Text('Alle Aufgaben anzeigen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextExamCard extends StatelessWidget {
  const _NextExamCard({
    required this.model,
    required this.onOpenExams,
    required this.onStartLearning,
  });
  final DashboardViewModel model;
  final VoidCallback onOpenExams;
  final VoidCallback onStartLearning;

  @override
  Widget build(BuildContext context) {
    final exam = model.nextExam;
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Nächste Prüfung',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 14),
          if (exam == null)
            const _EmptyText('Keine bevorstehende Prüfung.')
          else ...[
            Text(exam.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              _examDateLine(exam),
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: 8),
            Text(
              _daysUntilExam(exam),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (exam.chapters.isNotEmpty) ...[
              LinearProgressIndicator(
                value: exam.computedProgress.clamp(0, 1),
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: AppColors.lilac,
                color: AppColors.mauve,
              ),
              const SizedBox(height: 8),
              Text(
                '${exam.chapters.where((chapter) => chapter.done).length} / ${exam.chapters.length} Themen vorbereitet',
              ),
            ] else
              Text(
                'Fortschritt wird sichtbar, sobald Themen angelegt sind.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onOpenExams,
                  child: const Text('Prüfung öffnen'),
                ),
                FilledButton.icon(
                  onPressed: onStartLearning,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lernen'),
                ),
              ],
            ),
            if (model.upcomingExams.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Weitere Prüfungen',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              for (final item in model.upcomingExams)
                Text(
                  '${item.title} · ${item.dateLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.model, required this.onOpenTimer});
  final DashboardViewModel model;
  final VoidCallback onOpenTimer;

  @override
  Widget build(BuildContext context) {
    final rawProgress = model.dailyGoalSeconds == 0
        ? 0.0
        : model.todayStudySeconds / model.dailyGoalSeconds;
    final progress = rawProgress.clamp(0.0, 1.0);
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Focus', icon: Icons.timer_outlined),
          const SizedBox(height: 14),
          Text('Heute gelernt', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            formatDuration(model.todayStudySeconds),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Text(
            'Tagesziel ${formatDuration(model.todayStudySeconds)} / ${formatDuration(model.dailyGoalSeconds)}',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.mint,
            color: AppColors.sage,
          ),
          const SizedBox(height: 8),
          Text('${(rawProgress * 100).round()} %'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenTimer,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              model.activeSession == null ? 'Lernen starten' : 'Timer öffnen',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.model, required this.onOpenCalendar});
  final DashboardViewModel model;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Diese Woche',
            icon: Icons.view_week_outlined,
            actionLabel: 'Kalender öffnen',
            onAction: onOpenCalendar,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final day in model.weekDays)
                Expanded(child: _WeekDayCell(day: day)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({required this.day});
  final DashboardWeekDay day;

  @override
  Widget build(BuildContext context) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final hasStudy =
        day.studySeconds >= AnalyticsService.learningDayThresholdSeconds;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: day.isToday ? AppColors.blush : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: day.isToday ? AppColors.rose : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            labels[day.date.weekday - 1],
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 3),
          Text(
            '${day.date.day}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Icon(
            hasStudy
                ? Icons.check_circle_rounded
                : day.hasExam
                ? Icons.school_rounded
                : day.hasEvent
                ? Icons.circle
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: hasStudy
                ? AppColors.sage
                : day.hasExam
                ? AppColors.mauve
                : AppColors.mutedInk,
          ),
        ],
      ),
    );
  }
}

class _BottomGrid extends StatelessWidget {
  const _BottomGrid({required this.model, required this.controller});
  final DashboardViewModel model;
  final StudyBuddyController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final children = [
          _RecentNotesCard(
            model: model,
            onOpenNotes: () => controller.selectDestination(3),
          ),
          _ProgressCard(model: model),
        ];
        if (!wide) {
          return Column(
            children: [children[0], const SizedBox(height: 16), children[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 18),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class _RecentNotesCard extends StatelessWidget {
  const _RecentNotesCard({required this.model, required this.onOpenNotes});
  final DashboardViewModel model;
  final VoidCallback onOpenNotes;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Letzte Notizen',
            icon: Icons.edit_note_outlined,
            actionLabel: 'Notizen',
            onAction: onOpenNotes,
          ),
          const SizedBox(height: 12),
          if (model.recentNotes.isEmpty)
            const _EmptyText('Noch keine Notizen.')
          else
            for (final note in model.recentNotes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.notes_rounded,
                  color: AppColors.mauve,
                ),
                title: Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  note.preview.isEmpty ? 'Keine Vorschau' : note.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.model});
  final DashboardViewModel model;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Lernfortschritt',
            icon: Icons.insights_outlined,
          ),
          const SizedBox(height: 14),
          _MetricRow('Diese Woche', formatDuration(model.weekStudySeconds)),
          _MetricRow('Lernstreak', '${model.streakDays} Tage'),
          _MetricRow('Heute', formatDuration(model.todayStudySeconds)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mauve),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedInk),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.mutedInk));
  }
}

List<DashboardTimelineItem> _buildTimeline(
  StudyBuddyState state,
  List<CalendarOccurrence> occurrences,
  DateTime today,
) {
  final items = <DashboardTimelineItem>[
    for (final occurrence in occurrences)
      DashboardTimelineItem(
        id: occurrence.event.id,
        type: DashboardTimelineType.schedule,
        title: occurrence.event.title,
        subtitle: occurrence.event.location.isEmpty
            ? occurrence.event.category
            : '${occurrence.event.category} · ${occurrence.event.location}',
        startAt: occurrence.startAt,
        endAt: occurrence.endAt,
        allDay: occurrence.event.allDay,
        color: occurrence.event.color,
      ),
    for (final exam in state.exams)
      if (exam.startAt != null &&
          sameDay(exam.startAt!, today) &&
          exam.status != ExamStatus.cancelled)
        DashboardTimelineItem(
          id: exam.id,
          type: DashboardTimelineType.exam,
          title: exam.title,
          subtitle: exam.room.isEmpty ? 'Prüfung' : 'Prüfung · ${exam.room}',
          startAt: exam.startAt,
          endAt: exam.endAt,
          color: AppColors.mauve,
        ),
    for (final task in state.tasks)
      if (!task.done && task.dueAt != null && sameDay(task.dueAt!, today))
        DashboardTimelineItem(
          id: task.id,
          type: DashboardTimelineType.taskDeadline,
          title: task.title,
          subtitle: 'Aufgabe fällig',
          startAt: task.dueAt,
          color: AppColors.sage,
        ),
  ];
  return items;
}

List<TaskItem> _relevantTasks(List<TaskItem> tasks, DateTime now) {
  final today = _dayStart(now);
  final result = tasks.where((task) {
    if (task.done) return false;
    return task.isOverdue ||
        (task.dueAt != null && sameDay(task.dueAt!, today)) ||
        (task.startAt != null && sameDay(task.startAt!, today)) ||
        task.priority == TaskPriority.high ||
        task.priority == TaskPriority.urgent;
  }).toList();
  result.sort((a, b) => _taskRank(a).compareTo(_taskRank(b)));
  return result;
}

int _taskRank(TaskItem task) {
  if (task.isOverdue) return 0;
  if (task.dueAt != null && sameDay(task.dueAt!, DateTime.now())) return 1;
  if (task.priority == TaskPriority.urgent) return 2;
  if (task.priority == TaskPriority.high) return 3;
  return 4;
}

List<ExamOverview> _nextExams(List<ExamOverview> exams, DateTime now) {
  final today = _dayStart(now);
  final result =
      exams
          .where(
            (exam) =>
                exam.startAt != null &&
                !exam.startAt!.isBefore(today) &&
                exam.status != ExamStatus.cancelled,
          )
          .toList()
        ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
  return result;
}

String _greeting(DateTime now) {
  if (now.hour < 11) return 'Guten Morgen';
  if (now.hour < 17) return 'Guten Nachmittag';
  return 'Guten Abend';
}

String _dateLabel(DateTime date) {
  const weekdays = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  const months = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]}';
}

DateTime _dayStart(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _taskSubtitle(TaskItem task) {
  final parts = <String>[];
  if (task.dueAt != null) {
    parts.add(
      task.isOverdue ? 'Überfällig' : DateFormat.Hm().format(task.dueAt!),
    );
  }
  if (task.estimatedMinutes != null) parts.add('${task.estimatedMinutes} min');
  if (task.priority == TaskPriority.high ||
      task.priority == TaskPriority.urgent) {
    parts.add(task.priority == TaskPriority.urgent ? 'Sehr wichtig' : 'Hoch');
  }
  return parts.isEmpty ? task.category : parts.join(' · ');
}

String _examDateLine(ExamOverview exam) {
  if (exam.startAt == null) return exam.dateLabel;
  final date =
      '${exam.startAt!.day.toString().padLeft(2, '0')}.${exam.startAt!.month.toString().padLeft(2, '0')}.${exam.startAt!.year}';
  final time = DateFormat.Hm().format(exam.startAt!);
  return '$date · $time';
}

String _daysUntilExam(ExamOverview exam) {
  final days = exam.daysUntil;
  if (days == null) return '';
  if (days == 0) return 'Heute';
  if (days == 1) return 'Morgen';
  return 'Noch $days Tage';
}
