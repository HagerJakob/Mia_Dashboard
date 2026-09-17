import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rrule/rrule.dart';

import '../../dashboard/presentation/dashboard_controller.dart';
import '../domain/calendar_models.dart';
import '../domain/calendar_services.dart';

class CalendarState {
  CalendarState({
    DateTime? selectedDate,
    this.view = CalendarView.month,
    this.events = const [],
    this.categories = const [],
    Set<CalendarSource>? visibleSources,
    this.loading = true,
    this.error,
  }) : selectedDate = selectedDate ?? dayStart(DateTime.now()),
       visibleSources =
           visibleSources ??
           {
             CalendarSource.user,
             CalendarSource.austrianHoliday,
             CalendarSource.phSalzburg,
             CalendarSource.academicPeriod,
           };
  final DateTime selectedDate;
  final CalendarView view;
  final List<CalendarEvent> events;
  final List<CalendarCategory> categories;
  final Set<CalendarSource> visibleSources;
  final bool loading;
  final String? error;

  CalendarState copyWith({
    DateTime? selectedDate,
    CalendarView? view,
    List<CalendarEvent>? events,
    List<CalendarCategory>? categories,
    Set<CalendarSource>? visibleSources,
    bool? loading,
    String? error,
  }) => CalendarState(
    selectedDate: selectedDate ?? this.selectedDate,
    view: view ?? this.view,
    events: events ?? this.events,
    categories: categories ?? this.categories,
    visibleSources: visibleSources ?? this.visibleSources,
    loading: loading ?? this.loading,
    error: error,
  );
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

class CalendarController extends Notifier<CalendarState> {
  final recurrence = const RecurrenceService();
  final holidays = const HolidayService();
  final academic = const AcademicCalendarService();
  final timeline = const StudyTimeline();

  @override
  CalendarState build() {
    Future<void>.microtask(refresh);
    return CalendarState();
  }

  Future<void> refresh() async {
    final repo = ref.read(studyBuddyRepositoryProvider);
    try {
      final events = await repo.calendarEvents();
      final categories = await repo.calendarCategories();
      state = state.copyWith(
        events: events,
        categories: categories,
        loading: false,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  void selectDate(DateTime date) =>
      state = state.copyWith(selectedDate: dayStart(date));
  void setView(CalendarView view) => state = state.copyWith(view: view);
  void toggleSource(CalendarSource source, bool enabled) {
    final sources = {...state.visibleSources};
    enabled ? sources.add(source) : sources.remove(source);
    state = state.copyWith(visibleSources: sources);
  }

  void move(int direction) {
    final date = state.selectedDate;
    final next = switch (state.view) {
      CalendarView.month => DateTime(
        date.year,
        date.month + direction,
        date.day.clamp(
          1,
          DateTime(date.year, date.month + direction + 1, 0).day,
        ),
      ),
      CalendarView.week => calendarDay(date, 7 * direction),
      CalendarView.day => calendarDay(date, direction),
      CalendarView.agenda => DateTime(
        date.year,
        date.month + direction,
        date.day,
      ),
    };
    selectDate(next);
  }

  void today() => selectDate(DateTime.now());

  List<CalendarOccurrence> occurrences(DateTime from, DateTime to) =>
      state.visibleSources.contains(CalendarSource.user)
      ? recurrence.expand(
          state.events.where((e) => e.source == CalendarSource.user).toList(),
          from,
          to,
        )
      : [];

  List<AcademicPeriod> academicPeriods(DateTime from, DateTime to) => [
    ...academic.between(from, to),
    for (final event in state.events)
      if (event.source == CalendarSource.academicPeriod &&
          !event.startAt.isAfter(to) &&
          !event.endAt.isBefore(from))
        AcademicPeriod(
          id: event.id,
          title: event.title,
          description: event.description,
          startDate: dayStart(event.startAt),
          endDate: dayStart(event.endAt.subtract(const Duration(seconds: 1))),
          type: AcademicPeriodType.values.byName(
            event.metadata['type'] ?? 'custom',
          ),
          institution:
              event.metadata['institution'] ??
              AcademicCalendarService.institution,
          studyProgram:
              event.metadata['study_program'] ??
              AcademicCalendarService.studyProgram,
          source: 'Eigener Eintrag',
          sourceUrl: event.metadata['source_url'],
          confirmed: event.metadata['confirmed'] == 'true',
        ),
  ];

  Future<void> save(
    CalendarEvent event, {
    CalendarOccurrence? occurrence,
    RecurrenceScope scope = RecurrenceScope.all,
  }) async {
    if (!event.endAt.isAfter(event.startAt) || event.title.trim().isEmpty) {
      throw ArgumentError('Titel und ein gültiger Zeitraum sind erforderlich.');
    }
    if (occurrence != null && occurrence.isRecurring) {
      final master = state.events.firstWhere(
        (e) => e.id == occurrence.event.seriesId,
        orElse: () =>
            state.events.firstWhere((e) => e.id == occurrence.event.id),
      );
      if (scope == RecurrenceScope.one) {
        await _persist(
          event.copyWith(
            id: occurrence.event.seriesId == null ? _id() : occurrence.event.id,
            seriesId: master.id,
            occurrenceAt: occurrence.originalStart,
            recurrenceRule: null,
          ),
        );
        return;
      }
      if (scope == RecurrenceScope.following) {
        final rule = RecurrenceRule.fromString(master.recurrenceRule!);
        final editedRule = event.recurrenceRule == null
            ? null
            : RecurrenceRule.fromString(event.recurrenceRule!);
        final previousCount = _instancesBefore(
          master,
          occurrence.originalStart!,
        ).length;
        await _truncate(master, occurrence.originalStart!);
        await _persist(
          event.copyWith(
            id: _id(),
            seriesId: null,
            occurrenceAt: null,
            recurrenceRule: editedRule == null
                ? null
                : rule.count != null && editedRule.count == rule.count
                ? editedRule
                      .copyWith(count: rule.count! - previousCount)
                      .toString()
                : editedRule.toString(),
          ),
        );
        return;
      }
      final shift = event.startAt.difference(occurrence.startAt);
      await _persist(
        event.copyWith(
          id: master.id,
          startAt: master.startAt.add(shift),
          endAt: master.startAt.add(shift).add(event.duration),
          seriesId: null,
          occurrenceAt: null,
        ),
      );
      return;
    }
    await _persist(event);
  }

  Future<void> delete(
    CalendarOccurrence occurrence, {
    RecurrenceScope scope = RecurrenceScope.all,
  }) async {
    final repo = ref.read(studyBuddyRepositoryProvider);
    if (!occurrence.isRecurring) {
      await repo.deleteCalendarEvent(occurrence.event.id);
    } else {
      final master = state.events.firstWhere(
        (e) => e.id == occurrence.event.seriesId,
        orElse: () =>
            state.events.firstWhere((e) => e.id == occurrence.event.id),
      );
      if (scope == RecurrenceScope.one) {
        await repo.saveCalendarEvent(
          master.copyWith(
            id: occurrence.event.seriesId == null ? _id() : occurrence.event.id,
            seriesId: master.id,
            occurrenceAt: occurrence.originalStart,
            startAt: occurrence.startAt,
            endAt: occurrence.endAt,
            recurrenceRule: null,
            cancelled: true,
          ),
        );
      } else if (scope == RecurrenceScope.following) {
        await _truncate(master, occurrence.originalStart!);
      } else {
        await repo.deleteCalendarEvent(master.id);
      }
    }
    await refresh();
    unawaited(repo.syncNow().catchError((Object _) {}));
  }

  Future<void> addCategory(CalendarCategory category) async {
    final repo = ref.read(studyBuddyRepositoryProvider);
    await repo.saveCalendarCategory(category);
    await refresh();
    unawaited(repo.syncNow().catchError((Object _) {}));
  }

  Future<void> _persist(CalendarEvent event) async {
    final repo = ref.read(studyBuddyRepositoryProvider);
    await repo.saveCalendarEvent(event);
    await refresh();
    unawaited(repo.syncNow().catchError((Object _) {}));
  }

  Future<void> _truncate(CalendarEvent master, DateTime pivot) async {
    final repo = ref.read(studyBuddyRepositoryProvider);
    final rule = RecurrenceRule.fromString(master.recurrenceRule!);
    final previous = _instancesBefore(master, pivot);
    if (previous.isEmpty) {
      await repo.deleteCalendarEvent(master.id);
      return;
    }
    final oldRule = rule.count != null
        ? rule.copyWith(count: previous.length)
        : rule.copyWith(until: previous.last);
    await repo.saveCalendarEvent(
      master.copyWith(recurrenceRule: oldRule.toString()),
    );
  }

  List<DateTime> _instancesBefore(CalendarEvent master, DateTime pivot) {
    final rule = RecurrenceRule.fromString(master.recurrenceRule!);
    final start = DateTime.utc(
      master.startAt.year,
      master.startAt.month,
      master.startAt.day,
      master.startAt.hour,
      master.startAt.minute,
    );
    final pivotUtc = DateTime.utc(
      pivot.year,
      pivot.month,
      pivot.day,
      pivot.hour,
      pivot.minute,
    );
    return rule.getInstances(start: start, before: pivotUtc).toList();
  }

  String newId() => _id();
  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
