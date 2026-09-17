import 'package:drift/drift.dart';

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';

class StudySync {
  StudySync(this.database, this.client);

  final AppDatabase database;
  final SupabaseClient client;

  Future<void> run() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    for (final kind in const [
      'schedule',
      'task',
      'note',
      'subject',
      'exam',
      'reminder',
      'calendar_category',
    ]) {
      final local = await _localRows(kind);
      for (final row in local.where((row) => row['needs_sync'] == true)) {
        await client.from('study_items').upsert({
          'owner_id': user.id,
          'kind': kind,
          'id': row['id'],
          'payload': row['payload'],
          'updated_at': (row['updated_at'] as DateTime)
              .toUtc()
              .toIso8601String(),
          'deleted_at': (row['deleted_at'] as DateTime?)
              ?.toUtc()
              .toIso8601String(),
        });
        await _markClean(
          kind,
          row['id'] as String,
          row['updated_at'] as DateTime,
        );
      }

      // Keep each query below Supabase's default 1000 row response limit.
      var offset = 0;
      while (true) {
        final remote = await client
            .from('study_items')
            .select()
            .eq('owner_id', user.id)
            .eq('kind', kind)
            .order('updated_at')
            .range(offset, offset + 499);
        for (final item in remote) {
          await _applyRemote(kind, item);
        }
        if (remote.length < 500) break;
        offset += 500;
      }
    }
  }

  Future<List<Map<String, Object?>>> _localRows(String kind) async {
    switch (kind) {
      case 'schedule':
        return [
          for (final r in await database.select(database.scheduleEntries).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'time': r.time,
              'title': r.title,
              'created_at': r.createdAt.toUtc().toIso8601String(),
              if (r.eventJson != null) 'event': jsonDecode(r.eventJson!),
            }),
        ];
      case 'task':
        return [
          for (final r in await database.select(database.tasks).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'title': r.title,
              'done': r.done,
            }),
        ];
      case 'note':
        return [
          for (final r in await database.select(database.notes).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'title': r.title,
              'body': r.body,
            }),
        ];
      case 'subject':
        return [
          for (final r in await database.select(database.subjects).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'name': r.name,
              'color_value': r.colorValue,
            }),
        ];
      case 'exam':
        return [
          for (final r in await database.select(database.exams).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'subject': r.subject,
              'date_label': r.dateLabel,
              'progress': r.progress,
            }),
        ];
      case 'calendar_category':
        return [
          for (final r
              in await database.select(database.calendarCategories).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'name': r.name,
              'color_value': r.colorValue,
            }),
        ];
      default:
        return [
          for (final r in await database.select(database.reminders).get())
            _row(r.id, r.updatedAt, r.deletedAt, r.needsSync, {
              'title': r.title,
              'date_label': r.dateLabel,
            }),
        ];
    }
  }

  Map<String, Object?> _row(
    String id,
    DateTime updated,
    DateTime? deleted,
    bool dirty,
    Map<String, Object?> payload,
  ) => {
    'id': id,
    'updated_at': updated,
    'deleted_at': deleted,
    'needs_sync': dirty,
    'payload': payload,
  };

  Future<void> _markClean(String kind, String id, DateTime updated) async {
    switch (kind) {
      case 'schedule':
        await (database.update(database.scheduleEntries)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const ScheduleEntriesCompanion(needsSync: Value(false)));
      case 'task':
        await (database.update(database.tasks)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const TasksCompanion(needsSync: Value(false)));
      case 'note':
        await (database.update(database.notes)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const NotesCompanion(needsSync: Value(false)));
      case 'subject':
        await (database.update(database.subjects)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const SubjectsCompanion(needsSync: Value(false)));
      case 'exam':
        await (database.update(database.exams)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const ExamsCompanion(needsSync: Value(false)));
      case 'reminder':
        await (database.update(database.reminders)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const RemindersCompanion(needsSync: Value(false)));
      case 'calendar_category':
        await (database.update(database.calendarCategories)
              ..where((r) => r.id.equals(id) & r.updatedAt.equals(updated)))
            .write(const CalendarCategoriesCompanion(needsSync: Value(false)));
    }
  }

  Future<void> _applyRemote(String kind, Map<String, dynamic> remote) async {
    final id = remote['id'] as String;
    final updated = DateTime.parse(remote['updated_at'] as String);
    final deleted = remote['deleted_at'] == null
        ? null
        : DateTime.parse(remote['deleted_at'] as String);
    final payload = remote['payload'] as Map<String, dynamic>;
    final local = (await _localRows(kind))
        .where((r) => r['id'] == id)
        .firstOrNull;
    if (local != null &&
        ((local['needs_sync'] as bool) ||
            (local['updated_at'] as DateTime).millisecondsSinceEpoch ~/ 1000 >=
                updated.millisecondsSinceEpoch ~/ 1000)) {
      return;
    }
    switch (kind) {
      case 'schedule':
        await database
            .into(database.scheduleEntries)
            .insertOnConflictUpdate(
              ScheduleEntriesCompanion.insert(
                id: id,
                time: payload['time'] as String,
                title: payload['title'] as String,
                eventJson: Value(
                  payload['event'] == null
                      ? null
                      : jsonEncode(payload['event']),
                ),
                createdAt: payload['created_at'] is String
                    ? DateTime.parse(payload['created_at'] as String)
                    : updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
      case 'task':
        await database
            .into(database.tasks)
            .insertOnConflictUpdate(
              TasksCompanion.insert(
                id: id,
                title: payload['title'] as String,
                done: Value(payload['done'] as bool),
                createdAt: updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
      case 'note':
        await database
            .into(database.notes)
            .insertOnConflictUpdate(
              NotesCompanion.insert(
                id: id,
                title: payload['title'] as String,
                body: Value(payload['body'] as String),
                createdAt: updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
      case 'subject':
        await database
            .into(database.subjects)
            .insertOnConflictUpdate(
              SubjectsCompanion.insert(
                id: id,
                name: payload['name'] as String,
                colorValue: Value(payload['color_value'] as int),
                createdAt: updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
      case 'exam':
        await database
            .into(database.exams)
            .insertOnConflictUpdate(
              ExamsCompanion.insert(
                id: id,
                subject: payload['subject'] as String,
                dateLabel: payload['date_label'] as String,
                progress: Value((payload['progress'] as num).toDouble()),
                createdAt: updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
      case 'reminder':
        await database
            .into(database.reminders)
            .insertOnConflictUpdate(
              RemindersCompanion.insert(
                id: id,
                title: payload['title'] as String,
                dateLabel: payload['date_label'] as String,
                createdAt: updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
      case 'calendar_category':
        await database
            .into(database.calendarCategories)
            .insertOnConflictUpdate(
              CalendarCategoriesCompanion.insert(
                id: id,
                name: payload['name'] as String,
                colorValue: payload['color_value'] as int,
                createdAt: updated,
                updatedAt: updated,
                deletedAt: Value(deleted),
                needsSync: const Value(false),
              ),
            );
    }
  }
}
