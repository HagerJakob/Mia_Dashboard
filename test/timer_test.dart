import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/core/database/app_database.dart' hide StudySession;
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/domain/dashboard_models.dart';

void main() {
  test('study session JSON round-trip preserves focus metadata', () {
    final session = StudySession(
      id: 'session-1',
      mode: TimerMode.pomodoro,
      status: StudySessionStatus.completed,
      startedAt: DateTime(2026, 9, 24, 20, 14),
      endedAt: DateTime(2026, 9, 24, 21, 6),
      subjectId: 'math',
      examId: 'exam-1',
      taskId: 'task-1',
      focusDurationSeconds: 3120,
      pauseDurationSeconds: 300,
      plannedDurationSeconds: 3000,
      pomodoroFocusMinutes: 25,
      pomodoroBreakMinutes: 5,
      pomodoroCyclesCompleted: 2,
      note: 'Kapitel 3 gelernt',
    );

    final decoded = StudySession.decode(session.id, session.encode());
    expect(decoded.mode, TimerMode.pomodoro);
    expect(decoded.status, StudySessionStatus.completed);
    expect(decoded.subjectId, 'math');
    expect(decoded.focusDurationSeconds, 3120);
    expect(decoded.note, 'Kapitel 3 gelernt');
  });

  test(
    'local SQLite stores, updates and soft deletes study sessions',
    () async {
      final database = AppDatabase();
      final repo = DriftStudyBuddyRepository(database);
      addTearDown(repo.dispose);

      final session = StudySession(
        id: 'local-session',
        mode: TimerMode.focus,
        status: StudySessionStatus.active,
        startedAt: DateTime(2026, 9, 24, 20),
      );

      await repo.addStudySession(session);
      expect(
        (await repo.loadInitialState()).studySessions.single.isActive,
        isTrue,
      );

      await repo.updateStudySession(
        session.copyWith(
          status: StudySessionStatus.completed,
          endedAt: DateTime(2026, 9, 24, 21),
          focusDurationSeconds: 3600,
        ),
      );
      final updated = (await repo.loadInitialState()).studySessions.single;
      expect(updated.status, StudySessionStatus.completed);
      expect(updated.focusDurationSeconds, 3600);

      await repo.deleteStudySession(session.id);
      expect((await repo.loadInitialState()).studySessions, isEmpty);
      final row = await (database.select(
        database.studySessions,
      )..where((r) => r.id.equals(session.id))).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.needsSync, isTrue);
    },
  );
}
