import 'package:drift/drift.dart';

import 'connection/connection.dart';

part 'app_database.g.dart';

class ScheduleEntries extends Table {
  TextColumn get id => text()();
  TextColumn get time => text()();
  TextColumn get title => text()();
  TextColumn get eventJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFFB56D8C))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Exams extends Table {
  TextColumn get id => text()();
  TextColumn get subject => text()();
  TextColumn get dateLabel => text()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get dateLabel => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ScheduleEntries,
    Tasks,
    Notes,
    Subjects,
    Exams,
    Reminders,
    CalendarCategories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.withExecutor(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(scheduleEntries, scheduleEntries.eventJson);
        await m.createTable(calendarCategories);
      }
    },
  );

  Future<List<ScheduleEntry>> activeScheduleEntries() {
    return (select(scheduleEntries)
          ..where((entry) => entry.deletedAt.isNull())
          ..orderBy([(entry) => OrderingTerm.asc(entry.time)]))
        .get();
  }

  Future<List<Task>> activeTasks() {
    return (select(tasks)
          ..where((task) => task.deletedAt.isNull())
          ..orderBy([(task) => OrderingTerm.asc(task.createdAt)]))
        .get();
  }

  Future<List<Note>> activeNotes() {
    return (select(notes)
          ..where((note) => note.deletedAt.isNull())
          ..orderBy([(note) => OrderingTerm.desc(note.createdAt)]))
        .get();
  }

  Future<List<Subject>> activeSubjects() {
    return (select(subjects)
          ..where((subject) => subject.deletedAt.isNull())
          ..orderBy([(subject) => OrderingTerm.asc(subject.name)]))
        .get();
  }

  Future<List<Exam>> activeExams() {
    return (select(exams)
          ..where((exam) => exam.deletedAt.isNull())
          ..orderBy([(exam) => OrderingTerm.asc(exam.createdAt)]))
        .get();
  }

  Future<List<Reminder>> activeReminders() {
    return (select(reminders)
          ..where((reminder) => reminder.deletedAt.isNull())
          ..orderBy([(reminder) => OrderingTerm.asc(reminder.createdAt)]))
        .get();
  }
}
