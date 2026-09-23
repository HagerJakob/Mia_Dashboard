import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/core/database/app_database.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/domain/dashboard_models.dart';

void main() {
  test('task JSON round-trip preserves extended fields and progress', () {
    final task = TaskItem(
      id: 'task-1',
      title: 'Präsentation vorbereiten',
      description: 'Bilder und Quellen prüfen',
      priority: TaskPriority.high,
      dueAt: DateTime(2028, 2, 29, 18),
      subjectId: 'math',
      category: 'Abgabe',
      estimatedMinutes: 90,
      tags: const ['prüfung', 'ph'],
      subtasks: const [
        TaskSubtask(id: 'a', title: 'Recherche', isCompleted: true),
        TaskSubtask(id: 'b', title: 'Folien', sortOrder: 1),
      ],
      reminders: const [15, 60],
    );

    final decoded = TaskItem.decode(task.id, task.encode());
    expect(decoded.title, task.title);
    expect(decoded.priority, TaskPriority.high);
    expect(decoded.dueAt, DateTime(2028, 2, 29, 18));
    expect(decoded.tags, ['prüfung', 'ph']);
    expect(decoded.completedSubtasks, 1);
    expect(decoded.progress, .5);
  });

  test('old task payloads get safe defaults', () {
    final task = TaskItem.fromJson('old', const {
      'title': 'Alte Aufgabe',
      'done': true,
    });
    expect(task.status, TaskStatus.completed);
    expect(task.priority, TaskPriority.normal);
    expect(task.subtasks, isEmpty);
    expect(task.tags, isEmpty);
  });

  test(
    'local SQLite stores, updates and soft deletes extended tasks',
    () async {
      final database = AppDatabase();
      final repo = DriftStudyBuddyRepository(database);
      addTearDown(repo.dispose);

      final task = TaskItem(
        id: 'local-task',
        title: 'Arbeitsblatt',
        priority: TaskPriority.urgent,
        dueAt: DateTime(2026, 10, 3, 14),
      );
      await repo.addTask(task);
      expect(
        (await repo.loadInitialState()).tasks.single.priority,
        TaskPriority.urgent,
      );

      await repo.updateTask(
        task.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime(2026),
        ),
      );
      expect((await repo.loadInitialState()).tasks.single.done, isTrue);

      await repo.deleteTask(task.id);
      expect((await repo.loadInitialState()).tasks, isEmpty);
      final row = await (database.select(
        database.tasks,
      )..where((r) => r.id.equals(task.id))).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.needsSync, isTrue);
    },
  );
}
