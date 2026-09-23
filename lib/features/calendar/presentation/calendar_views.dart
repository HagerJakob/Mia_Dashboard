import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/design_system/study_card.dart';
import '../../../shared/design_system/study_radius.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../domain/calendar_models.dart';
import '../domain/calendar_services.dart';
import 'calendar_controller.dart';
import 'calendar_editor.dart';
import 'academic_period_editor.dart';

class CalendarViews extends ConsumerWidget {
  const CalendarViews({required this.state, super.key});
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (state.view) {
    CalendarView.month => _MonthView(state: state),
    CalendarView.week => _TimelineView(state: state, week: true),
    CalendarView.day => _TimelineView(state: state, week: false),
    CalendarView.agenda => _AgendaView(state: state),
  };
}

class _MonthView extends ConsumerWidget {
  const _MonthView({required this.state});
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final first = monthStart(state.selectedDate);
    final last = monthEnd(state.selectedDate);
    final cells = visibleMonthGrid(state.selectedDate);
    final compact = MediaQuery.sizeOf(context).width < 700;
    final occurrences = controller.occurrences(first, last);
    final holidays =
        state.visibleSources.contains(CalendarSource.austrianHoliday)
        ? controller.holidays.between(first, last)
        : <AustrianHoliday>[];
    final periods = controller.academicPeriods(first, last);
    final academicVisible = state.visibleSources.contains(
      CalendarSource.academicPeriod,
    );
    final phVisible = state.visibleSources.contains(CalendarSource.phSalzburg);

    final grid = Column(
      children: [
        Row(
          children: [
            for (final day in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < cells.length ~/ 7; row++)
          SizedBox(
            height: compact ? 50 : 112,
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _monthCell(
                      context,
                      ref,
                      cells[row * 7 + column],
                      occurrences,
                      holidays,
                      periods,
                      academicVisible,
                      phVisible,
                      compact,
                      controller,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 28, 0, compact ? 12 : 28, 80),
      child: Column(
        children: [
          StudyCard(padding: EdgeInsets.zero, child: grid),
          ...[
            const SizedBox(height: 18),
            _DaySummary(
              date: state.selectedDate,
              occurrences: controller.occurrences(
                dayStart(state.selectedDate),
                nextDay(state.selectedDate),
              ),
              holiday: holidays
                  .where((h) => sameDay(h.date, state.selectedDate))
                  .firstOrNull,
              periods: periods
                  .where(
                    (p) =>
                        (isAcademicBreak(p.type)
                            ? academicVisible
                            : phVisible) &&
                        !p.startDate.isAfter(state.selectedDate) &&
                        !p.endDate.isBefore(state.selectedDate),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthCell(
    BuildContext context,
    WidgetRef ref,
    DateTime? date,
    List<CalendarOccurrence> occurrences,
    List<AustrianHoliday> holidays,
    List<AcademicPeriod> periods,
    bool academicVisible,
    bool phVisible,
    bool compact,
    CalendarController controller,
  ) {
    if (date == null) return const _EmptyMonthCell();
    return _MonthDay(
      date: date,
      selected: sameDay(date, state.selectedDate),
      occurrences: occurrences
          .where((o) => overlaps(o.startAt, o.endAt, date, nextDay(date)))
          .toList(),
      holiday: holidays.where((h) => sameDay(h.date, date)).firstOrNull,
      periods: periods
          .where(
            (p) =>
                (isAcademicBreak(p.type) ? academicVisible : phVisible) &&
                !p.startDate.isAfter(date) &&
                !p.endDate.isBefore(date),
          )
          .toList(),
      compact: compact,
      onTap: () => controller.selectDate(date),
      onDoubleTap: () => showCalendarEditor(context, ref, initialDate: date),
      onEventTap: (o) => showCalendarDetail(context, ref, o),
    );
  }
}

class _EmptyMonthCell extends StatelessWidget {
  const _EmptyMonthCell();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: .6),
          left: BorderSide(color: AppColors.border, width: .6),
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _MonthDay extends StatelessWidget {
  const _MonthDay({
    required this.date,
    required this.selected,
    required this.occurrences,
    required this.periods,
    required this.compact,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEventTap,
    this.holiday,
  });
  final DateTime date;
  final bool selected, compact;
  final List<CalendarOccurrence> occurrences;
  final AustrianHoliday? holiday;
  final List<AcademicPeriod> periods;
  final VoidCallback onTap, onDoubleTap;
  final ValueChanged<CalendarOccurrence> onEventTap;

  @override
  Widget build(BuildContext context) {
    final today = sameDay(date, DateTime.now());
    final weekend = date.weekday >= DateTime.saturday;
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: StudyRadius.small,
        child: Container(
          padding: EdgeInsets.all(compact ? 4 : 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blush.withValues(alpha: .58)
                : periods.any((p) => isAcademicBreak(p.type))
                ? AppColors.mint.withValues(alpha: .34)
                : weekend
                ? AppColors.surface.withValues(alpha: .55)
                : Colors.transparent,
            border: const Border(
              top: BorderSide(color: AppColors.border, width: .6),
              left: BorderSide(color: AppColors.border, width: .6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 24 : 28,
                    height: compact ? 24 : 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: today ? AppColors.mauve : Colors.transparent,
                      borderRadius: StudyRadius.full,
                      border: selected && !today
                          ? Border.all(color: AppColors.mauve)
                          : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: selected || today
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: today ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                  if (compact && occurrences.isNotEmpty)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: occurrences.first.event.color,
                        ),
                      ),
                    ),
                ],
              ),
              if (!compact) ...[
                if (holiday != null)
                  Text(
                    holiday!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mauve,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                for (final period in periods.take(1))
                  Text(
                    'PH · ${period.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedInk,
                    ),
                  ),
                for (final occurrence in occurrences.take(
                  holiday == null && periods.isEmpty ? 3 : 2,
                ))
                  InkWell(
                    onTap: () => onEventTap(occurrence),
                    borderRadius: StudyRadius.small,
                    child: _EventChip(occurrence: occurrence),
                  ),
                if (occurrences.length >
                    (holiday == null && periods.isEmpty ? 3 : 2))
                  Text(
                    '+ ${occurrences.length - (holiday == null && periods.isEmpty ? 3 : 2)} weitere',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedInk,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.occurrence});

  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final event = occurrence.event;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: .12),
        borderRadius: StudyRadius.small,
        border: Border.all(color: event.color.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: event.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${event.allDay ? '' : '${DateFormat.Hm().format(occurrence.startAt)} '} ${event.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (event.priority == EventPriority.veryImportant) ...[
            const SizedBox(width: 3),
            Icon(Icons.priority_high_rounded, size: 12, color: event.color),
          ],
        ],
      ),
    );
  }
}

class _DaySummary extends ConsumerWidget {
  const _DaySummary({
    required this.date,
    required this.occurrences,
    required this.periods,
    this.tasks = const [],
    this.exams = const [],
    this.holiday,
  });
  final DateTime date;
  final List<CalendarOccurrence> occurrences;
  final List<AcademicPeriod> periods;
  final List<TaskItem> tasks;
  final List<ExamOverview> exams;
  final AustrianHoliday? holiday;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        DateFormat('EEEE, d. MMMM', 'de_AT').format(date),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (holiday != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            holiday!.title,
            style: const TextStyle(color: AppColors.mauve),
          ),
        ),
      for (final period in periods)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.school_outlined),
          title: Text(period.title),
          subtitle: Text(
            period.source == 'Eigener Eintrag'
                ? 'Eigener Hochschulzeitraum'
                : 'PH Salzburg',
          ),
          onTap: () async {
            final action = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(period.title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('dd.MM.yyyy').format(period.startDate)} – ${DateFormat('dd.MM.yyyy').format(period.endDate)}',
                    ),
                    if (period.description.isNotEmpty) Text(period.description),
                    Text(period.institution),
                    if (period.sourceUrl != null)
                      Text('Quelle: ${period.sourceUrl}'),
                    Text(period.confirmed ? 'Bestätigt' : 'Unbestätigt'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen'),
                  ),
                  if (period.source == 'Eigener Eintrag') ...[
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'delete'),
                      child: const Text('Löschen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      child: const Text('Bearbeiten'),
                    ),
                  ],
                ],
              ),
            );
            if (!context.mounted || period.source != 'Eigener Eintrag') return;
            if (action == 'edit') {
              await showAcademicPeriodEditor(context, ref, existing: period);
            }
            if (action == 'delete') {
              final event = ref
                  .read(calendarControllerProvider)
                  .events
                  .where((e) => e.id == period.id)
                  .firstOrNull;
              if (event != null) {
                await ref
                    .read(calendarControllerProvider.notifier)
                    .delete(
                      CalendarOccurrence(event, event.startAt, event.endAt),
                    );
              }
            }
          },
        ),
      if (occurrences.isEmpty &&
          periods.isEmpty &&
          tasks.isEmpty &&
          exams.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Text('Noch keine Termine an diesem Tag.'),
        ),
      for (final exam in exams)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.school_rounded, color: AppColors.mauve),
          title: Text(exam.title),
          subtitle: Text(
            [
              if (exam.startAt != null) DateFormat.Hm().format(exam.startAt!),
              'Prüfung',
              exam.subject,
            ].join(' · '),
          ),
          onTap: () => ref
              .read(studyBuddyControllerProvider.notifier)
              .selectDestination(5),
        ),
      for (final task in tasks)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            tooltip: task.done ? 'Wieder öffnen' : 'Erledigen',
            onPressed: () => ref
                .read(studyBuddyControllerProvider.notifier)
                .toggleTask(task.id),
            icon: Icon(
              task.done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: task.done ? AppColors.sage : AppColors.mauve,
            ),
          ),
          title: Text(task.title),
          subtitle: Text(
            [
              if (task.dueAt != null) DateFormat.Hm().format(task.dueAt!),
              'Aufgabe',
              if (task.priority == TaskPriority.high) 'Hoch',
              if (task.priority == TaskPriority.urgent) 'Dringend',
            ].join(' · '),
          ),
          onTap: () => ref
              .read(studyBuddyControllerProvider.notifier)
              .selectDestination(2),
        ),
      for (final occurrence in occurrences)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 6,
            backgroundColor: occurrence.event.color,
          ),
          title: Text(occurrence.event.title),
          subtitle: Text(
            occurrence.event.allDay
                ? 'Ganztägig'
                : '${DateFormat.Hm().format(occurrence.startAt)}–${DateFormat.Hm().format(occurrence.endAt)}',
          ),
          onTap: () => showCalendarDetail(context, ref, occurrence),
        ),
    ],
  );
}

class _TimelineView extends ConsumerStatefulWidget {
  const _TimelineView({required this.state, required this.week});
  final CalendarState state;
  final bool week;
  static const hourHeight = 56.0;

  @override
  ConsumerState<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<_TimelineView> {
  static const hourHeight = _TimelineView.hourHeight;
  final _scrollController = ScrollController(
    initialScrollOffset: 7 * _TimelineView.hourHeight,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final state = widget.state;
    final first = widget.week
        ? weekStart(state.selectedDate)
        : dayStart(state.selectedDate);
    final count = widget.week ? 7 : 1;
    final narrow = MediaQuery.sizeOf(context).width < 820;
    final visibleCount = widget.week && narrow ? 3 : count;
    final displayFirst = widget.week && narrow ? state.selectedDate : first;
    final days = [
      for (var i = 0; i < visibleCount; i++) calendarDay(displayFirst, i),
    ];
    final occurrences = controller.occurrences(
      displayFirst,
      nextDay(days.last),
    );
    final dayHolidays =
        state.visibleSources.contains(CalendarSource.austrianHoliday)
        ? controller.holidays.between(displayFirst, nextDay(displayFirst))
        : <AustrianHoliday>[];
    final dayPeriods = controller
        .academicPeriods(displayFirst, displayFirst)
        .where(
          (p) => state.visibleSources.contains(
            isAcademicBreak(p.type)
                ? CalendarSource.academicPeriod
                : CalendarSource.phSalzburg,
          ),
        )
        .toList();
    return Column(
      children: [
        if (!widget.week && (dayHolidays.isNotEmpty || dayPeriods.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Wrap(
              spacing: 10,
              children: [
                for (final holiday in dayHolidays)
                  Chip(label: Text(holiday.title)),
                for (final period in dayPeriods)
                  Chip(label: Text('PH · ${period.title}')),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 52),
              for (final day in days)
                Expanded(
                  child: InkWell(
                    onDoubleTap: () =>
                        showCalendarEditor(context, ref, initialDate: day),
                    onTap: () => controller.selectDate(day),
                    borderRadius: StudyRadius.medium,
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE', 'de_AT').format(day),
                          style: TextStyle(
                            color: sameDay(day, DateTime.now())
                                ? AppColors.mauve
                                : AppColors.mutedInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _TimelineDayNumber(
                          day: day,
                          selected: sameDay(day, state.selectedDate),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: Row(
            children: [
              const SizedBox(width: 52),
              for (final day in days)
                Expanded(
                  child: Center(
                    child: Text(
                      occurrences
                          .where(
                            (o) =>
                                o.event.allDay &&
                                overlaps(o.startAt, o.endAt, day, nextDay(day)),
                          )
                          .map((o) => o.event.title)
                          .join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: 24 * hourHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Column(
                      children: [
                        for (var hour = 0; hour < 24; hour++)
                          SizedBox(
                            height: hourHeight,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in days)
                    Expanded(
                      child: _DayTimeline(
                        day: day,
                        occurrences: occurrences
                            .where(
                              (o) =>
                                  !o.event.allDay &&
                                  overlaps(
                                    o.startAt,
                                    o.endAt,
                                    day,
                                    nextDay(day),
                                  ),
                            )
                            .toList(),
                        onCreate: (time) =>
                            showCalendarEditor(context, ref, initialDate: time),
                        onOpen: (event) =>
                            showCalendarDetail(context, ref, event),
                        onMenu: (position, event) =>
                            _eventMenu(context, ref, position, event),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineDayNumber extends StatelessWidget {
  const _TimelineDayNumber({required this.day, required this.selected});

  final DateTime day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final today = sameDay(day, DateTime.now());
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: today ? AppColors.mauve : Colors.transparent,
        borderRadius: StudyRadius.full,
        border: selected && !today ? Border.all(color: AppColors.mauve) : null,
      ),
      child: Text(
        '${day.day}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: today ? Colors.white : AppColors.ink,
          fontWeight: today || selected ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.day,
    required this.occurrences,
    required this.onCreate,
    required this.onOpen,
    required this.onMenu,
  });
  final DateTime day;
  final List<CalendarOccurrence> occurrences;
  final ValueChanged<DateTime> onCreate;
  final ValueChanged<CalendarOccurrence> onOpen;
  final void Function(Offset, CalendarOccurrence) onMenu;

  @override
  Widget build(BuildContext context) {
    const hourHeight = _TimelineView.hourHeight;
    final positions = _overlapPositions(occurrences);
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          for (var hour = 0; hour < 24; hour++)
            Positioned(
              top: hour * hourHeight,
              left: 0,
              right: 0,
              height: hourHeight,
              child: GestureDetector(
                onDoubleTap: () =>
                    onCreate(DateTime(day.year, day.month, day.day, hour)),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: .7),
                      left: BorderSide(color: AppColors.border, width: .7),
                    ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < occurrences.length; i++)
            Builder(
              builder: (context) {
                final event = occurrences[i];
                final start = event.startAt.isBefore(day) ? day : event.startAt;
                final end = event.endAt.isAfter(nextDay(day))
                    ? nextDay(day)
                    : event.endAt;
                final top = (start.hour * 60 + start.minute) / 60 * hourHeight;
                final height =
                    ((end.difference(start).inMinutes / 60) * hourHeight).clamp(
                      22.0,
                      24 * hourHeight - top,
                    );
                final lane = positions[i].$1, lanes = positions[i].$2;
                return Positioned(
                  top: top,
                  height: height,
                  left: constraints.maxWidth * lane / lanes + 2,
                  width: constraints.maxWidth / lanes - 4,
                  child: Material(
                    color: event.event.color.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(5),
                    child: InkWell(
                      onTap: () => onOpen(event),
                      onSecondaryTapDown: (details) =>
                          onMenu(details.globalPosition, event),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          '${DateFormat.Hm().format(event.startAt)} ${event.event.title}',
                          maxLines: height > 38 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (sameDay(day, now))
            Positioned(
              top: (now.hour * 60 + now.minute) / 60 * hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 2, color: AppColors.mauve),
            ),
        ],
      ),
    );
  }

  List<(int, int)> _overlapPositions(List<CalendarOccurrence> items) {
    final result = List<(int, int)>.filled(items.length, (0, 1));
    final indexes = [for (var i = 0; i < items.length; i++) i]
      ..sort((a, b) => items[a].startAt.compareTo(items[b].startAt));
    var group = <int>[];
    DateTime? groupEnd;
    void flush() {
      final lanes = <DateTime>[];
      final assigned = <int, int>{};
      for (final index in group) {
        var lane = lanes.indexWhere(
          (end) => !end.isAfter(items[index].startAt),
        );
        if (lane < 0) {
          lane = lanes.length;
          lanes.add(items[index].endAt);
        } else {
          lanes[lane] = items[index].endAt;
        }
        assigned[index] = lane;
      }
      for (final index in group) {
        result[index] = (assigned[index]!, lanes.length);
      }
      group = [];
    }

    for (final index in indexes) {
      if (groupEnd != null && !items[index].startAt.isBefore(groupEnd)) {
        flush();
      }
      group.add(index);
      if (groupEnd == null || items[index].endAt.isAfter(groupEnd)) {
        groupEnd = items[index].endAt;
      }
    }
    flush();
    return result;
  }
}

class _AgendaView extends ConsumerWidget {
  const _AgendaView({required this.state});
  final CalendarState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calendarControllerProvider.notifier);
    final dashboardState = ref.watch(studyBuddyControllerProvider);
    final start = dayStart(state.selectedDate);
    final end = calendarDay(start, 31);
    final items = controller
        .occurrences(start, end)
        .where((occurrence) => occurrence.event.subjectId == null)
        .toList();
    final dueTasks = dashboardState.tasks
        .where(
          (task) =>
              task.dueAt != null &&
              !task.dueAt!.isBefore(start) &&
              task.dueAt!.isBefore(end),
        )
        .toList();
    final dueExams = dashboardState.exams
        .where(
          (exam) =>
              exam.startAt != null &&
              !exam.startAt!.isBefore(start) &&
              exam.startAt!.isBefore(end) &&
              exam.effectiveStatus != ExamStatus.cancelled,
        )
        .toList();
    final holidays =
        state.visibleSources.contains(CalendarSource.austrianHoliday)
        ? controller.holidays.between(start, end)
        : <AustrianHoliday>[];
    final periods = controller
        .academicPeriods(start, end)
        .where(
          (p) => state.visibleSources.contains(
            isAcademicBreak(p.type)
                ? CalendarSource.academicPeriod
                : CalendarSource.phSalzburg,
          ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
      children: [
        for (var i = 0; i < 31; i++)
          Builder(
            builder: (context) {
              final day = calendarDay(start, i);
              final dayItems = items
                  .where((o) => overlaps(o.startAt, o.endAt, day, nextDay(day)))
                  .toList();
              final holiday = holidays
                  .where((h) => sameDay(h.date, day))
                  .firstOrNull;
              final dayPeriods = periods
                  .where(
                    (p) =>
                        !p.startDate.isAfter(day) && !p.endDate.isBefore(day),
                  )
                  .toList();
              final dayTasks = dueTasks
                  .where(
                    (task) => task.dueAt != null && sameDay(task.dueAt!, day),
                  )
                  .toList();
              final dayExams = dueExams
                  .where(
                    (exam) =>
                        exam.startAt != null && sameDay(exam.startAt!, day),
                  )
                  .toList();
              if (dayItems.isEmpty &&
                  dayTasks.isEmpty &&
                  dayExams.isEmpty &&
                  holiday == null &&
                  dayPeriods.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _DaySummary(
                  date: day,
                  occurrences: dayItems,
                  holiday: holiday,
                  periods: dayPeriods,
                  tasks: dayTasks,
                  exams: dayExams,
                ),
              );
            },
          ),
        if (items.isEmpty &&
            dueTasks.isEmpty &&
            dueExams.isEmpty &&
            holidays.isEmpty &&
            periods.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Keine Einträge in den nächsten 31 Tagen.'),
          ),
      ],
    );
  }
}

Future<void> _eventMenu(
  BuildContext context,
  WidgetRef ref,
  Offset position,
  CalendarOccurrence occurrence,
) async {
  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: const [
      PopupMenuItem(value: 'open', child: Text('Details / Bearbeiten')),
      PopupMenuItem(value: 'duplicate', child: Text('Duplizieren')),
      PopupMenuItem(value: 'delete', child: Text('Löschen')),
    ],
  );
  if (!context.mounted) return;
  if (choice == 'open') showCalendarDetail(context, ref, occurrence);
  if (choice == 'duplicate') {
    final controller = ref.read(calendarControllerProvider.notifier);
    await controller.save(
      occurrence.event.copyWith(
        id: controller.newId(),
        startAt: occurrence.startAt,
        endAt: occurrence.endAt,
        seriesId: null,
        occurrenceAt: null,
        recurrenceRule: null,
      ),
    );
  }
  if (choice == 'delete') {
    if (!context.mounted) return;
    final scope = occurrence.isRecurring
        ? await askRecurrenceScope(context, 'Was möchtest du löschen?')
        : RecurrenceScope.all;
    if (!context.mounted) return;
    if (scope != null) {
      await ref
          .read(calendarControllerProvider.notifier)
          .delete(occurrence, scope: scope);
    }
  }
}

Future<void> showCalendarDetail(
  BuildContext context,
  WidgetRef ref,
  CalendarOccurrence occurrence,
) async {
  final event = occurrence.event;
  final subject = ref
      .read(studyBuddyControllerProvider)
      .subjects
      .where((s) => s.id == event.subjectId)
      .firstOrNull;
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          CircleAvatar(radius: 7, backgroundColor: event.color),
          const SizedBox(width: 10),
          Expanded(child: Text(event.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat(
              'EEEE, d. MMMM yyyy',
              'de_AT',
            ).format(occurrence.startAt),
          ),
          Text(
            event.allDay
                ? 'Ganztägig'
                : '${DateFormat.Hm().format(occurrence.startAt)}–${DateFormat.Hm().format(occurrence.endAt)}',
          ),
          if (event.location.isNotEmpty) Text('Ort: ${event.location}'),
          if (subject != null) Text('Fach: ${subject.name}'),
          if (event.recurrenceRule != null || occurrence.isRecurring)
            const Text('Wiederkehrender Termin'),
          if (event.reminders.isNotEmpty)
            Text('Erinnerung: ${event.reminders.first} Minuten vorher'),
          if (event.priority == EventPriority.veryImportant)
            const Text('! Sehr wichtig'),
          if (event.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(event.description),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'delete'),
          child: const Text('Löschen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'edit'),
          child: const Text('Bearbeiten'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    showCalendarEditor(context, ref, occurrence: occurrence);
  }
  if (action == 'delete') {
    final scope = occurrence.isRecurring
        ? await askRecurrenceScope(context, 'Was möchtest du löschen?')
        : RecurrenceScope.all;
    if (scope != null) {
      await ref
          .read(calendarControllerProvider.notifier)
          .delete(occurrence, scope: scope);
    }
  }
}
