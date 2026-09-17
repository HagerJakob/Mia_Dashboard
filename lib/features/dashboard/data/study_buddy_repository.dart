import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart' hide CalendarCategory;
import '../../../core/supabase/supabase_service.dart';
import '../../../core/sync/study_sync.dart';
import '../../calendar/domain/calendar_models.dart';
import '../domain/dashboard_models.dart';

abstract interface class StudyBuddyRepository {
  Future<StudyBuddyState> loadInitialState();
  Future<void> addScheduleItem(TimedItem item);
  Future<void> addTask(TaskItem item);
  Future<void> updateTask(TaskItem item);
  Future<void> addNote(NoteItem item);
  Future<void> addSubject(SubjectItem item);
  Future<void> addExam(ExamOverview exam);
  Future<void> addReminder(ReminderItem reminder);
  Future<List<CalendarEvent>> calendarEvents();
  Future<List<CalendarCategory>> calendarCategories();
  Future<void> saveCalendarEvent(CalendarEvent event);
  Future<void> deleteCalendarEvent(String id);
  Future<void> saveCalendarCategory(CalendarCategory category);
  Future<void> syncNow();
  Future<void> dispose();
}

StudyBuddyRepository createStudyBuddyRepository() {
  if (kIsWeb) {
    return InMemoryStudyBuddyRepository();
  }

  return DriftStudyBuddyRepository(AppDatabase());
}

class InMemoryStudyBuddyRepository implements StudyBuddyRepository {
  InMemoryStudyBuddyRepository();

  StudyBuddyState _state = const StudyBuddyState();
  final Map<String, CalendarEvent> _calendarEvents = {};
  final Map<String, CalendarCategory> _calendarCategories = {};

  @override
  Future<List<CalendarEvent>> calendarEvents() async =>
      _calendarEvents.values.toList();
  @override
  Future<List<CalendarCategory>> calendarCategories() async =>
      _calendarCategories.values.toList();
  @override
  Future<void> saveCalendarEvent(CalendarEvent event) async =>
      _calendarEvents[event.id] = event;
  @override
  Future<void> deleteCalendarEvent(String id) async =>
      _calendarEvents.remove(id);
  @override
  Future<void> saveCalendarCategory(CalendarCategory category) async =>
      _calendarCategories[category.id] = category;

  @override
  Future<StudyBuddyState> loadInitialState() async => _state;

  @override
  Future<void> addScheduleItem(TimedItem item) async {
    _state = _state.copyWith(schedule: [..._state.schedule, item]);
  }

  @override
  Future<void> addTask(TaskItem item) async {
    _state = _state.copyWith(tasks: [..._state.tasks, item]);
  }

  @override
  Future<void> updateTask(TaskItem item) async {
    _state = _state.copyWith(
      tasks: [
        for (final task in _state.tasks)
          if (task.id == item.id) item else task,
      ],
    );
  }

  @override
  Future<void> addNote(NoteItem item) async {
    _state = _state.copyWith(notes: [..._state.notes, item]);
  }

  @override
  Future<void> addSubject(SubjectItem item) async {
    _state = _state.copyWith(subjects: [..._state.subjects, item]);
  }

  @override
  Future<void> addExam(ExamOverview exam) async {
    _state = _state.copyWith(exams: [..._state.exams, exam]);
  }

  @override
  Future<void> addReminder(ReminderItem reminder) async {
    _state = _state.copyWith(reminders: [..._state.reminders, reminder]);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> syncNow() async {}
}

class DriftStudyBuddyRepository implements StudyBuddyRepository {
  DriftStudyBuddyRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<CalendarEvent>> calendarEvents() async => [
    for (final row in await _database.activeScheduleEntries())
      if (row.eventJson != null) CalendarEvent.decode(row.id, row.eventJson!),
  ];

  @override
  Future<List<CalendarCategory>> calendarCategories() async => [
    for (final row in await (_database.select(
      _database.calendarCategories,
    )..where((r) => r.deletedAt.isNull())).get())
      CalendarCategory(row.id, row.name, row.colorValue),
  ];

  @override
  Future<void> saveCalendarEvent(CalendarEvent event) async {
    final now = DateTime.now();
    final existing = await (_database.select(
      _database.scheduleEntries,
    )..where((r) => r.id.equals(event.id))).getSingleOrNull();
    await _database
        .into(_database.scheduleEntries)
        .insertOnConflictUpdate(
          ScheduleEntriesCompanion.insert(
            id: event.id,
            time: event.allDay
                ? 'Ganztägig'
                : '${event.startAt.hour.toString().padLeft(2, '0')}:${event.startAt.minute.toString().padLeft(2, '0')}',
            title: event.title,
            eventJson: Value(event.encode()),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            needsSync: const Value(true),
          ),
        );
  }

  @override
  Future<void> deleteCalendarEvent(String id) async {
    await (_database.update(
      _database.scheduleEntries,
    )..where((r) => r.id.equals(id))).write(
      ScheduleEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        needsSync: const Value(true),
      ),
    );
  }

  @override
  Future<void> saveCalendarCategory(CalendarCategory category) async {
    final now = DateTime.now();
    final existing = await (_database.select(
      _database.calendarCategories,
    )..where((r) => r.id.equals(category.id))).getSingleOrNull();
    await _database
        .into(_database.calendarCategories)
        .insertOnConflictUpdate(
          CalendarCategoriesCompanion.insert(
            id: category.id,
            name: category.name,
            colorValue: category.colorValue,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            needsSync: const Value(true),
          ),
        );
  }

  Future<void> _syncQueue = Future.value();

  @override
  Future<void> syncNow() {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      return Future.value();
    }
    _syncQueue = _syncQueue
        .catchError((Object _) {})
        .then((_) => StudySync(_database, client).run());
    return _syncQueue;
  }

  @override
  Future<StudyBuddyState> loadInitialState() async {
    final schedule = await _database.activeScheduleEntries();
    final tasks = await _database.activeTasks();
    final notes = await _database.activeNotes();
    final subjects = await _database.activeSubjects();
    final exams = await _database.activeExams();
    final reminders = await _database.activeReminders();

    return StudyBuddyState(
      schedule: [
        for (final item in schedule)
          TimedItem(id: item.id, time: item.time, title: item.title),
      ],
      tasks: [
        for (final task in tasks)
          TaskItem(id: task.id, title: task.title, done: task.done),
      ],
      notes: [
        for (final note in notes)
          NoteItem(id: note.id, title: note.title, body: note.body),
      ],
      subjects: [
        for (final subject in subjects)
          SubjectItem(
            id: subject.id,
            name: subject.name,
            color: Color(subject.colorValue),
          ),
      ],
      exams: [
        for (final exam in exams)
          ExamOverview(
            id: exam.id,
            subject: exam.subject,
            dateLabel: exam.dateLabel,
            progress: exam.progress,
          ),
      ],
      reminders: [
        for (final reminder in reminders)
          ReminderItem(
            id: reminder.id,
            title: reminder.title,
            dateLabel: reminder.dateLabel,
          ),
      ],
    );
  }

  @override
  Future<void> addScheduleItem(TimedItem item) {
    final now = DateTime.now();
    return _database
        .into(_database.scheduleEntries)
        .insert(
          ScheduleEntriesCompanion.insert(
            id: item.id,
            time: item.time,
            title: item.title,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> addTask(TaskItem item) {
    final now = DateTime.now();
    return _database
        .into(_database.tasks)
        .insert(
          TasksCompanion.insert(
            id: item.id,
            title: item.title,
            done: Value(item.done),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> updateTask(TaskItem item) {
    return (_database.update(
      _database.tasks,
    )..where((task) => task.id.equals(item.id))).write(
      TasksCompanion(
        done: Value(item.done),
        updatedAt: Value(DateTime.now()),
        needsSync: const Value(true),
      ),
    );
  }

  @override
  Future<void> addNote(NoteItem item) {
    final now = DateTime.now();
    return _database
        .into(_database.notes)
        .insert(
          NotesCompanion.insert(
            id: item.id,
            title: item.title,
            body: Value(item.body),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> addSubject(SubjectItem item) {
    final now = DateTime.now();
    return _database
        .into(_database.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: item.id,
            name: item.name,
            colorValue: Value(item.color.toARGB32()),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> addExam(ExamOverview exam) {
    final now = DateTime.now();
    return _database
        .into(_database.exams)
        .insert(
          ExamsCompanion.insert(
            id: exam.id,
            subject: exam.subject,
            dateLabel: exam.dateLabel,
            progress: Value(exam.progress),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> addReminder(ReminderItem reminder) {
    final now = DateTime.now();
    return _database
        .into(_database.reminders)
        .insert(
          RemindersCompanion.insert(
            id: reminder.id,
            title: reminder.title,
            dateLabel: reminder.dateLabel,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> dispose() {
    return _database.close();
  }
}
