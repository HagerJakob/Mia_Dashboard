import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
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
    final first = weekStart(monthStart(state.selectedDate));
    final last = calendarDay(
      weekStart(
        DateTime(state.selectedDate.year, state.selectedDate.month + 1, 0),
      ),
      7,
    );
    final days = DateTime.utc(
      last.year,
      last.month,
      last.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
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
        for (var row = 0; row < days ~/ 7; row++)
          SizedBox(
            height: compact ? 48 : 116,
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _MonthDay(
                      date: calendarDay(first, row * 7 + column),
                      currentMonth: state.selectedDate.month,
                      selected: sameDay(
                        calendarDay(first, row * 7 + column),
                        state.selectedDate,
                      ),
                      occurrences: occurrences
                          .where(
                            (o) => overlaps(
                              o.startAt,
                              o.endAt,
                              calendarDay(first, row * 7 + column),
                              calendarDay(first, row * 7 + column + 1),
                            ),
                          )
                          .toList(),
                      holiday: holidays
                          .where(
                            (h) => sameDay(
                              h.date,
                              calendarDay(first, row * 7 + column),
                            ),
                          )
                          .firstOrNull,
                      periods: periods
                          .where(
                            (p) =>
                                (isAcademicBreak(p.type)
                                    ? academicVisible
                                    : phVisible) &&
                                !p.startDate.isAfter(
                                  calendarDay(first, row * 7 + column),
                                ) &&
                                !p.endDate.isBefore(
                                  calendarDay(first, row * 7 + column),
                                ),
                          )
                          .toList(),
                      compact: compact,
                      onTap: () => controller.selectDate(
                        calendarDay(first, row * 7 + column),
                      ),
                      onDoubleTap: () => showCalendarEditor(
                        context,
                        ref,
                        initialDate: first.add(
                          Duration(days: row * 7 + column),
                        ),
                      ),
                      onEventTap: (o) => showCalendarDetail(context, ref, o),
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: grid,
          ),
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
}

class _MonthDay extends StatelessWidget {
  const _MonthDay({
    required this.date,
    required this.currentMonth,
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
  final int currentMonth;
  final bool selected, compact;
  final List<CalendarOccurrence> occurrences;
  final AustrianHoliday? holiday;
  final List<AcademicPeriod> periods;
  final VoidCallback onTap, onDoubleTap;
  final ValueChanged<CalendarOccurrence> onEventTap;

  @override
  Widget build(BuildContext context) {
    final today = sameDay(date, DateTime.now());
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 3 : 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blush.withValues(alpha: .42)
                : periods.any((p) => isAcademicBreak(p.type))
                ? const Color(0xFFF2F4F0)
                : Colors.transparent,
            border: Border.all(color: AppColors.border, width: .5),
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
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: selected || today
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: today
                            ? Colors.white
                            : date.month == currentMonth
                            ? AppColors.ink
                            : AppColors.mutedInk,
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
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: occurrence.event.color.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: occurrence.event.color,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${occurrence.event.allDay ? '' : '${DateFormat.Hm().format(occurrence.startAt)} '} ${occurrence.event.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _DaySummary extends ConsumerWidget {
  const _DaySummary({
    required this.date,
    required this.occurrences,
    required this.periods,
    this.holiday,
  });
  final DateTime date;
  final List<CalendarOccurrence> occurrences;
  final List<AcademicPeriod> periods;
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
      if (occurrences.isEmpty && periods.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Text('Noch keine Termine an diesem Tag.'),
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
                    child: Column(
                      children: [
                        Text(DateFormat('EEE', 'de_AT').format(day)),
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.titleMedium,
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
    final start = dayStart(state.selectedDate);
    final end = calendarDay(start, 31);
    final items = controller.occurrences(start, end);
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
              if (dayItems.isEmpty && holiday == null && dayPeriods.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _DaySummary(
                  date: day,
                  occurrences: dayItems,
                  holiday: holiday,
                  periods: dayPeriods,
                ),
              );
            },
          ),
        if (items.isEmpty && holidays.isEmpty && periods.isEmpty)
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
