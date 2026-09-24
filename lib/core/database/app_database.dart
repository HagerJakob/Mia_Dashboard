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
  TextColumn get taskJson => text().nullable()();
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
  TextColumn get noteJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NoteFolders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentFolderId => text().nullable()();
  TextColumn get subjectId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFFB56D8C))();
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
  TextColumn get examJson => text().nullable()();
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

class StudySessions extends Table {
  TextColumn get id => text()();
  TextColumn get sessionJson => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
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
    NoteFolders,
    Subjects,
    Exams,
    Reminders,
    CalendarCategories,
    StudySessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.withExecutor(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(scheduleEntries, scheduleEntries.eventJson);
        await m.createTable(calendarCategories);
      }
      if (from < 3) {
        await _createTasksIfMissing();
        await _addColumnIfMissing('tasks', 'task_json', () {
          return m.addColumn(tasks, tasks.taskJson);
        });
      }
      if (from < 4) {
        await _createExamsIfMissing();
        await _addColumnIfMissing('exams', 'exam_json', () {
          return m.addColumn(exams, exams.examJson);
        });
      }
      if (from < 5) {
        await _createNotesIfMissing();
        await _createNoteFoldersIfMissing();
        await _addColumnIfMissing('notes', 'note_json', () {
          return m.addColumn(notes, notes.noteJson);
        });
      }
      if (from < 6) {
        await _createStudySessionsIfMissing();
      }
    },
  );

  Future<void> _createTasksIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        task_json TEXT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createNotesIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        note_json TEXT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createExamsIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS exams (
        id TEXT NOT NULL PRIMARY KEY,
        subject TEXT NOT NULL,
        date_label TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        exam_json TEXT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createNoteFoldersIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS note_folders (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        parent_folder_id TEXT NULL,
        subject_id TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        color_value INTEGER NOT NULL DEFAULT 11955596,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createStudySessionsIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS study_sessions (
        id TEXT NOT NULL PRIMARY KEY,
        session_json TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    Future<void> Function() add,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final exists = columns.any((row) => row.data['name'] == column);
    if (!exists) await add();
  }

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

  Future<List<NoteFolder>> activeNoteFolders() {
    return (select(noteFolders)
          ..where((folder) => folder.deletedAt.isNull())
          ..orderBy([
            (folder) => OrderingTerm.asc(folder.sortOrder),
            (folder) => OrderingTerm.asc(folder.name),
          ]))
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

  Future<List<StudySession>> activeStudySessions() {
    return (select(studySessions)
          ..where((session) => session.deletedAt.isNull())
          ..orderBy([(session) => OrderingTerm.desc(session.startedAt)]))
        .get();
  }
}
