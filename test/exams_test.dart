import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/core/database/app_database.dart';
import 'package:study_buddy/features/dashboard/data/study_buddy_repository.dart';
import 'package:study_buddy/features/dashboard/domain/dashboard_models.dart';

void main() {
  test('exam JSON round-trip preserves extended fields and topic progress', () {
    final exam = ExamOverview(
      id: 'exam-1',
      title: 'Mathematik Klausur',
      subject: 'Mathematik',
      dateLabel: '12.10.2026 09:00',
      subjectId: 'math',
      examType: ExamType.written,
      startAt: DateTime(2026, 10, 12, 9),
      endAt: DateTime(2026, 10, 12, 10, 30),
      location: 'PH Salzburg',
      room: 'B204',
      priority: TaskPriority.high,
      preparationStartAt: DateTime(2026, 9, 20),
      chapters: const [
        ChapterProgress('Mengenlehre', true, id: 'topic-1'),
        ChapterProgress('Geometrie', false, id: 'topic-2', sortOrder: 1),
      ],
      reminders: const [1440, 10080],
      grade: 2,
      pointsAchieved: 82.5,
      pointsMaximum: 100,
      passed: true,
    );

    final decoded = ExamOverview.decode(exam.id, exam.encode());
    expect(decoded.title, 'Mathematik Klausur');
    expect(decoded.subjectId, 'math');
    expect(decoded.examType, ExamType.written);
    expect(decoded.startAt, DateTime(2026, 10, 12, 9));
    expect(decoded.priority, TaskPriority.high);
    expect(decoded.reminders, [1440, 10080]);
    expect(decoded.chapters.length, 2);
    expect(decoded.computedProgress, .5);
    expect(decoded.grade, 2);
    expect(decoded.pointsAchieved, 82.5);
    expect(decoded.pointsMaximum, 100);
    expect(decoded.passed, isTrue);
  });

  test('old exam payloads get safe defaults', () {
    final exam = ExamOverview.fromJson('old-exam', const {
      'subject': 'Deutsch',
      'date_label': '15.10.2026',
      'progress': .25,
    });

    expect(exam.title, 'Deutsch');
    expect(exam.subject, 'Deutsch');
    expect(exam.examType, ExamType.written);
    expect(exam.status, ExamStatus.planned);
    expect(exam.computedProgress, .25);
  });

  test(
    'local SQLite stores, updates and soft deletes extended exams',
    () async {
      final database = AppDatabase();
      final repo = DriftStudyBuddyRepository(database);
      addTearDown(repo.dispose);

      final exam = ExamOverview(
        id: 'local-exam',
        title: 'Pädagogik Prüfung',
        subject: 'Pädagogik',
        dateLabel: '18.11.2026 08:30',
        startAt: DateTime(2026, 11, 18, 8, 30),
        chapters: const [ChapterProgress('Grundlagen', false)],
      );

      await repo.addExam(exam);
      expect(
        (await repo.loadInitialState()).exams.single.startAt,
        exam.startAt,
      );

      await repo.updateExam(
        exam.copyWith(
          chapters: const [ChapterProgress('Grundlagen', true)],
          status: ExamStatus.passed,
          grade: 1,
          pointsAchieved: 47,
          pointsMaximum: 50,
          passed: true,
        ),
      );
      final updated = (await repo.loadInitialState()).exams.single;
      expect(updated.status, ExamStatus.passed);
      expect(updated.computedProgress, 1);
      expect(updated.grade, 1);
      expect(updated.pointsAchieved, 47);
      expect(updated.pointsMaximum, 50);
      expect(updated.passed, isTrue);

      await repo.deleteExam(exam.id);
      expect((await repo.loadInitialState()).exams, isEmpty);
      final row = await (database.select(
        database.exams,
      )..where((r) => r.id.equals(exam.id))).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.needsSync, isTrue);
    },
  );
}
