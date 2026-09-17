import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:rrule/rrule.dart';
import 'package:study_buddy/core/database/app_database.dart'
    hide CalendarCategory;
import 'package:study_buddy/features/calendar/domain/calendar_models.dart';
import 'package:study_buddy/features/calendar/domain/calendar_services.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';

void main() {
  const holidays = HolidayService();
  const recurrence = RecurrenceService();

  test('Easter and Austrian fixed/movable holidays', () {
    expect(holidays.easterSunday(2027), DateTime(2027, 3, 28));
    expect(holidays.easterSunday(2028), DateTime(2028, 4, 16));
    final year = holidays.forYear(2028);
    expect(
      year.where((h) => h.title == 'Nationalfeiertag').single.date,
      DateTime(2028, 10, 26),
    );
    expect(
      year.where((h) => h.title == 'Fronleichnam').single.date,
      DateTime(2028, 6, 15),
    );
    expect(year, hasLength(13));
  });

  test('month/week/year boundaries and leap years', () {
    expect(weekStart(DateTime(2026, 9, 1)), DateTime(2026, 8, 31));
    expect(monthEnd(DateTime(2026, 12, 13)), DateTime(2027, 1, 1));
    expect(DateTime(2028, 3, 0), DateTime(2028, 2, 29));
    expect(DateTime(2027, 3, 0), DateTime(2027, 2, 28));
    expect(nextDay(DateTime(2028, 2, 28)), DateTime(2028, 2, 29));
  });

  test('daily, weekly, fortnightly, monthly, yearly recurrence', () {
    final start = DateTime(2028, 2, 29, 10);
    final cases = [
      (Frequency.daily, 1, DateTime(2028, 3, 1, 10)),
      (Frequency.weekly, 1, DateTime(2028, 3, 7, 10)),
      (Frequency.weekly, 2, DateTime(2028, 3, 14, 10)),
      (Frequency.monthly, 1, DateTime(2028, 3, 29, 10)),
      (Frequency.yearly, 1, DateTime(2032, 2, 29, 10)),
    ];
    for (final (frequency, interval, next) in cases) {
      final event = CalendarEvent(
        id: '$frequency',
        title: 'Serie',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        recurrenceRule: recurrence.rule(
          frequency: frequency,
          interval: interval,
        ),
      );
      final items = recurrence.expand(
        [event],
        start,
        next.add(const Duration(days: 1)),
      );
      expect(items.first.startAt, start);
      expect(items[1].startAt, next);
    }
  });

  test('recurrence stops at count and end date', () {
    final start = DateTime(2026, 9, 1, 9);
    CalendarEvent event(String rule) => CalendarEvent(
      id: 'x',
      title: 'LV',
      startAt: start,
      endAt: start.add(const Duration(hours: 2)),
      recurrenceRule: rule,
    );
    final byCount = recurrence.expand(
      [event(recurrence.rule(frequency: Frequency.weekly, count: 3))],
      start,
      DateTime(2027),
    );
    expect(byCount.map((o) => o.startAt.day).toList(), [1, 8, 15]);
    final byDate = recurrence.expand(
      [
        event(
          recurrence.rule(
            frequency: Frequency.weekly,
            until: DateTime(2026, 9, 15, 23),
          ),
        ),
      ],
      start,
      DateTime(2027),
    );
    expect(byDate, hasLength(3));
  });

  test('all-day, overnight, exception and cancellation', () {
    final allDay = CalendarEvent(
      id: 'all',
      title: 'Geburtstag',
      startAt: DateTime(2026, 9, 14),
      endAt: DateTime(2026, 9, 15),
      allDay: true,
    );
    final overnight = CalendarEvent(
      id: 'night',
      title: 'Dienst',
      startAt: DateTime(2026, 9, 14, 23),
      endAt: DateTime(2026, 9, 15, 2),
    );
    expect(
      recurrence
          .expand(
            [allDay, overnight],
            DateTime(2026, 9, 15),
            DateTime(2026, 9, 16),
          )
          .map((o) => o.event.id),
      ['night'],
    );
    final series = overnight.copyWith(
      id: 'series',
      recurrenceRule: recurrence.rule(frequency: Frequency.daily, count: 3),
    );
    final cancel = series.copyWith(
      id: 'cancel',
      seriesId: 'series',
      occurrenceAt: series.startAt.add(const Duration(days: 1)),
      recurrenceRule: null,
      cancelled: true,
    );
    final items = recurrence.expand(
      [series, cancel],
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 18),
    );
    expect(items, hasLength(2));
  });

  test('event JSON round-trip preserves metadata', () {
    final event = CalendarEvent(
      id: '1',
      title: 'Hospitation',
      startAt: DateTime(2028, 2, 29, 9),
      endAt: DateTime(2028, 2, 29, 11),
      category: 'Schulpraxis',
      practice: const {'school': 'VS Salzburg'},
      reminders: const [15, 60],
      priority: EventPriority.important,
      recurrenceRule: recurrence.rule(frequency: Frequency.weekly, count: 8),
    );
    final decoded = CalendarEvent.decode(event.id, event.encode());
    expect(decoded.toJson(), event.toJson());
  });

  test(
    'local SQLite stores events, custom categories and soft delete',
    () async {
      final database = AppDatabase();
      final repo = DriftStudyBuddyRepository(database);
      addTearDown(repo.dispose);
      final event = CalendarEvent(
        id: 'local-event',
        title: 'Prüfung',
        startAt: DateTime(2028, 2, 29, 9),
        endAt: DateTime(2028, 2, 29, 10),
      );
      await repo.saveCalendarEvent(event);
      await repo.saveCalendarCategory(
        const CalendarCategory('custom', 'Physiotherapie', 0xFF75AFA9),
      );
      expect((await repo.calendarEvents()).single.title, 'Prüfung');
      expect((await repo.calendarCategories()).single.name, 'Physiotherapie');
      await repo.deleteCalendarEvent(event.id);
      expect(await repo.calendarEvents(), isEmpty);
      final row = await (database.select(
        database.scheduleEntries,
      )..where((r) => r.id.equals(event.id))).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.needsSync, isTrue);
    },
  );

  test('schema v1 upgrades without removing existing schedule rows', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('''
      CREATE TABLE schedule_entries (
        id TEXT NOT NULL PRIMARY KEY, time TEXT NOT NULL, title TEXT NOT NULL,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        deleted_at INTEGER, needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
    sqlite.execute(
      "INSERT INTO schedule_entries VALUES ('old', '09:00', 'Vorlesung', 1, 1, NULL, 1)",
    );
    sqlite.execute('PRAGMA user_version = 1');
    final database = AppDatabase.withExecutor(NativeDatabase.opened(sqlite));
    addTearDown(database.close);
    final rows = await database.activeScheduleEntries();
    expect(rows.single.title, 'Vorlesung');
    expect(rows.single.eventJson, isNull);
    expect(await database.select(database.calendarCategories).get(), isEmpty);
  });

  test('only confirmed PH periods are shown; timeline is computed', () {
    const academic = AcademicCalendarService();
    final periods = academic.between(DateTime(2026, 9), DateTime(2027, 3));
    expect(periods.every((p) => p.confirmed && p.sourceUrl != null), isTrue);
    expect(periods.any((p) => p.title.contains('09.09.2026')), isFalse);
    expect(academic.between(DateTime(2030), DateTime(2031)), isEmpty);
    expect(const StudyTimeline().semester(DateTime(2026, 10)), 1);
    expect(const StudyTimeline().semester(DateTime(2028, 3)), 4);
  });
}
