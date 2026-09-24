import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/features/calendar/domain/calendar_models.dart';
import 'package:study_buddy/features/dashboard/domain/dashboard_models.dart';
import 'package:study_buddy/features/dashboard/presentation/widgets/dashboard_content.dart';
import 'package:study_buddy/features/statistics/data/analytics_service.dart';

void main() {
  const analytics = AnalyticsService();

  test('greeting changes for morning, afternoon and evening', () {
    expect(
      DashboardViewModel.from(
        state: const StudyBuddyState(),
        occurrences: const [],
        analytics: analytics,
        now: DateTime(2026, 9, 24, 8),
      ).greeting,
      'Guten Morgen',
    );
    expect(
      DashboardViewModel.from(
        state: const StudyBuddyState(),
        occurrences: const [],
        analytics: analytics,
        now: DateTime(2026, 9, 24, 14),
      ).greeting,
      'Guten Nachmittag',
    );
    expect(
      DashboardViewModel.from(
        state: const StudyBuddyState(),
        occurrences: const [],
        analytics: analytics,
        now: DateTime(2026, 9, 24, 20),
      ).greeting,
      'Guten Abend',
    );
  });

  test('dashboard combines today events, tasks, exams and notes', () {
    final model = DashboardViewModel.from(
      state: StudyBuddyState(
        tasks: [
          TaskItem(
            id: 'task-today',
            title: 'Arbeitsblatt Mathematik',
            dueAt: DateTime(2026, 9, 24, 14),
          ),
          TaskItem(
            id: 'done',
            title: 'Schon fertig',
            status: TaskStatus.completed,
            completedAt: DateTime(2026, 9, 24, 9),
          ),
        ],
        exams: [
          ExamOverview(
            id: 'exam',
            subject: 'Mathematik',
            title: 'Mathematik Klausur',
            dateLabel: '12.10.2026',
            startAt: DateTime(2026, 10, 12, 9),
            chapters: const [
              ChapterProgress('Grundlagen', true),
              ChapterProgress('Integrale', false),
            ],
          ),
        ],
        notes: [
          NoteItem(
            id: 'note',
            title: 'Didaktik Zusammenfassung',
            body: 'Kapitel 1',
            updatedAt: DateTime(2026, 9, 24, 12),
          ),
        ],
        studySessions: [
          StudySession(
            id: 'session',
            mode: TimerMode.focus,
            status: StudySessionStatus.completed,
            startedAt: DateTime(2026, 9, 24, 10),
            endedAt: DateTime(2026, 9, 24, 11),
            focusDurationSeconds: 3600,
          ),
        ],
      ),
      occurrences: [
        CalendarOccurrence(
          CalendarEvent(
            id: 'event',
            title: 'Pädagogik',
            startAt: DateTime(2026, 9, 24, 11, 30),
            endAt: DateTime(2026, 9, 24, 13),
          ),
          DateTime(2026, 9, 24, 11, 30),
          DateTime(2026, 9, 24, 13),
        ),
      ],
      analytics: analytics,
      now: DateTime(2026, 9, 24, 8),
    );

    expect(model.timeline.map((item) => item.title), contains('Pädagogik'));
    expect(
      model.timeline.map((item) => item.title),
      contains('Arbeitsblatt Mathematik'),
    );
    expect(model.relevantTasks.single.title, 'Arbeitsblatt Mathematik');
    expect(model.nextExam?.title, 'Mathematik Klausur');
    expect(model.nextExam?.computedProgress, 0.5);
    expect(model.recentNotes.single.title, 'Didaktik Zusammenfassung');
    expect(model.todayStudySeconds, 3600);
  });

  test(
    'cancelled exams and completed tasks are not primary dashboard items',
    () {
      final model = DashboardViewModel.from(
        state: StudyBuddyState(
          tasks: [
            TaskItem(
              id: 'done',
              title: 'Erledigt',
              status: TaskStatus.completed,
              dueAt: DateTime(2026, 9, 24),
            ),
          ],
          exams: [
            ExamOverview(
              id: 'cancelled',
              subject: 'Deutsch',
              dateLabel: '25.09.2026',
              startAt: DateTime(2026, 9, 25),
              status: ExamStatus.cancelled,
            ),
          ],
        ),
        occurrences: const [],
        analytics: analytics,
        now: DateTime(2026, 9, 24, 9),
      );

      expect(model.relevantTasks, isEmpty);
      expect(model.nextExam, isNull);
    },
  );
}
