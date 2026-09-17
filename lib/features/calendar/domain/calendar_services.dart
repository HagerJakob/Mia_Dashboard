import 'package:rrule/rrule.dart';

import 'calendar_models.dart';

DateTime dayStart(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime nextDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);
DateTime calendarDay(DateTime value, int offset) => DateTime(
  value.year,
  value.month,
  value.day + offset,
  value.hour,
  value.minute,
  value.second,
);
DateTime weekStart(DateTime value) =>
    DateTime(value.year, value.month, value.day - value.weekday + 1);
DateTime monthStart(DateTime value) => DateTime(value.year, value.month);
DateTime monthEnd(DateTime value) => DateTime(value.year, value.month + 1);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool overlaps(DateTime start, DateTime end, DateTime from, DateTime to) =>
    start.isBefore(to) && end.isAfter(from);
bool isAcademicBreak(AcademicPeriodType type) => {
  AcademicPeriodType.semesterBreak,
  AcademicPeriodType.christmasBreak,
  AcademicPeriodType.easterBreak,
  AcademicPeriodType.summerBreak,
  AcademicPeriodType.lectureFree,
}.contains(type);

class RecurrenceService {
  const RecurrenceService();

  List<CalendarOccurrence> expand(
    List<CalendarEvent> events,
    DateTime from,
    DateTime to,
  ) {
    final exceptions = <String, CalendarEvent>{};
    final appliedExceptions = <String>{};
    final masterIds = events
        .where((event) => event.seriesId == null)
        .map((event) => event.id)
        .toSet();
    for (final event in events) {
      if (event.seriesId != null && event.occurrenceAt != null) {
        exceptions['${event.seriesId}:${event.occurrenceAt!.toIso8601String()}'] =
            event;
      }
    }
    final result = <CalendarOccurrence>[];
    for (final event in events) {
      if (event.seriesId != null) continue;
      if (event.recurrenceRule == null) {
        if (!event.cancelled &&
            overlaps(event.startAt, event.endAt, from, to)) {
          result.add(CalendarOccurrence(event, event.startAt, event.endAt));
        }
        continue;
      }
      final rule = RecurrenceRule.fromString(event.recurrenceRule!);
      final duration = event.duration;
      final start = _wallUtc(event.startAt);
      final after = _wallUtc(from.subtract(duration));
      final before = _wallUtc(to);
      for (final instance in rule.getInstances(
        start: start,
        after: after.isBefore(start) ? start : after,
        includeAfter: true,
        before: before,
      )) {
        final occurrenceAt = DateTime(
          instance.year,
          instance.month,
          instance.day,
          instance.hour,
          instance.minute,
          instance.second,
        );
        final override =
            exceptions['${event.id}:${occurrenceAt.toIso8601String()}'];
        if (override != null) appliedExceptions.add(override.id);
        if (override?.cancelled == true) continue;
        final actual = override ?? event;
        final actualStart = override?.startAt ?? occurrenceAt;
        final actualEnd = override?.endAt ?? occurrenceAt.add(duration);
        if (overlaps(actualStart, actualEnd, from, to)) {
          result.add(
            CalendarOccurrence(
              actual,
              actualStart,
              actualEnd,
              originalStart: occurrenceAt,
            ),
          );
        }
      }
    }
    for (final override in exceptions.values) {
      if (!appliedExceptions.contains(override.id) &&
          !override.cancelled &&
          masterIds.contains(override.seriesId) &&
          overlaps(override.startAt, override.endAt, from, to)) {
        result.add(
          CalendarOccurrence(
            override,
            override.startAt,
            override.endAt,
            originalStart: override.occurrenceAt,
          ),
        );
      }
    }
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
    return result;
  }

  DateTime _wallUtc(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
    date.second,
  );

  String rule({
    required Frequency frequency,
    int interval = 1,
    List<int> weekdays = const [],
    DateTime? until,
    int? count,
  }) {
    if (interval <= 0 || (count != null && count <= 0)) {
      throw ArgumentError(
        'Wiederholungsintervall und Anzahl muessen positiv sein.',
      );
    }
    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      byWeekDays: weekdays.map(ByWeekDayEntry.new).toList(),
      until: until == null ? null : _wallUtc(until),
      count: count,
    ).toString();
  }
}

class AustrianHoliday {
  const AustrianHoliday(this.date, this.title);
  final DateTime date;
  final String title;
}

class HolidayService {
  const HolidayService({this.region = 'Salzburg'});
  final String region;

  DateTime easterSunday(int year) {
    final a = year % 19, b = year ~/ 100, c = year % 100;
    final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4, k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    return DateTime(year, month, day);
  }

  List<AustrianHoliday> forYear(int year) {
    final easter = easterSunday(year);
    return [
      AustrianHoliday(DateTime(year, 1, 1), 'Neujahr'),
      AustrianHoliday(DateTime(year, 1, 6), 'Heilige Drei Könige'),
      AustrianHoliday(calendarDay(easter, 1), 'Ostermontag'),
      AustrianHoliday(DateTime(year, 5, 1), 'Staatsfeiertag'),
      AustrianHoliday(calendarDay(easter, 39), 'Christi Himmelfahrt'),
      AustrianHoliday(calendarDay(easter, 50), 'Pfingstmontag'),
      AustrianHoliday(calendarDay(easter, 60), 'Fronleichnam'),
      AustrianHoliday(DateTime(year, 8, 15), 'Mariä Himmelfahrt'),
      AustrianHoliday(DateTime(year, 10, 26), 'Nationalfeiertag'),
      AustrianHoliday(DateTime(year, 11, 1), 'Allerheiligen'),
      AustrianHoliday(DateTime(year, 12, 8), 'Mariä Empfängnis'),
      AustrianHoliday(DateTime(year, 12, 25), 'Christtag'),
      AustrianHoliday(DateTime(year, 12, 26), 'Stefanitag'),
    ];
  }

  List<AustrianHoliday> between(DateTime from, DateTime to) => [
    for (var year = from.year; year <= to.year; year++)
      for (final holiday in forYear(year))
        if (!holiday.date.isBefore(dayStart(from)) && holiday.date.isBefore(to))
          holiday,
  ];
}

class StudyTimeline {
  const StudyTimeline();
  int? semester(DateTime date) {
    if (date.isBefore(DateTime(2026, 10))) return null;
    final academicYear = date.month >= 10 ? date.year : date.year - 1;
    final base = (academicYear - 2026) * 2 + 1;
    return date.month >= 3 && date.month < 10 ? base + 1 : base;
  }

  String? label(DateTime date) {
    final value = semester(date);
    return value == null ? null : '$value. Semester';
  }
}

class AcademicCalendarService {
  const AcademicCalendarService();
  static const institution = 'Pädagogische Hochschule Salzburg Stefan Zweig';
  static const studyProgram = 'Bachelor Lehramt Primarstufe';
  static const studyStart = 'Wintersemester 2026/27';

  // Only source-confirmed periods belong here. School holidays are separate.
  List<AcademicPeriod> get periods => [
    AcademicPeriod(
      id: 'ph-kickoff-2026',
      title: 'Informationstag 1. Semester',
      startDate: DateTime(2026, 9, 30),
      endDate: DateTime(2026, 9, 30),
      type: AcademicPeriodType.phEvent,
      institution: institution,
      studyProgram: studyProgram,
      confirmed: true,
      source: 'PH Salzburg Terminkalender',
      sourceUrl: 'https://phsalzburg.at/termine/liste/seite/19/?tribe-bar-date=2023-08-05',
    ),
    AcademicPeriod(
      id: 'ph-ws-start-2026',
      title: 'Beginn Wintersemester',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 1),
      type: AcademicPeriodType.semester,
      institution: institution,
      studyProgram: studyProgram,
      confirmed: true,
      source: 'PH Salzburg Terminkalender',
      sourceUrl: 'https://phsalzburg.at/termine/liste/seite/19/?tribe-bar-date=2023-08-05',
    ),
    AcademicPeriod(
      id: 'ph-lv-ss-2027-primary',
      title: 'LV-Anmeldung Primarstufe Bachelor',
      startDate: DateTime(2027, 2, 17),
      endDate: DateTime(2027, 2, 18),
      type: AcademicPeriodType.enrollmentPeriod,
      institution: institution,
      studyProgram: studyProgram,
      confirmed: true,
      source: 'PH Salzburg Terminkalender',
      sourceUrl: 'https://phsalzburg.at/termine/kategorie/studium/liste/',
    ),
  ];

  List<AcademicPeriod> between(DateTime from, DateTime to) => periods
      .where((p) => !p.startDate.isAfter(to) && !p.endDate.isBefore(from))
      .toList();
}
