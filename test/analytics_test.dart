import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/features/dashboard/domain/dashboard_models.dart';
import 'package:study_buddy/features/statistics/data/analytics_service.dart';

void main() {
  const service = AnalyticsService();

  StudySession session({
    required String id,
    required DateTime start,
    required int minutes,
    String? subjectId,
    String? examId,
    String? taskId,
    TimerMode mode = TimerMode.focus,
    StudySessionStatus status = StudySessionStatus.completed,
  }) {
    return StudySession(
      id: id,
      mode: mode,
      status: status,
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes)),
      focusDurationSeconds: minutes * 60,
      subjectId: subjectId,
      examId: examId,
      taskId: taskId,
    );
  }

  test('study time is aggregated per day, week and month', () {
    final state = StudyBuddyState(
      studySessions: [
        session(id: 'a', start: DateTime(2026, 9, 21, 9), minutes: 60),
        session(id: 'b', start: DateTime(2026, 9, 22, 9), minutes: 30),
        session(id: 'c', start: DateTime(2026, 10, 1, 9), minutes: 90),
      ],
    );

    final week = service.buildReport(
      state,
      service.weekRange(DateTime(2026, 9, 24)),
    );
    final month = service.buildReport(
      state,
      service.monthRange(DateTime(2026, 9, 24)),
    );

    expect(week.studySeconds, 90 * 60);
    expect(week.dailyStudy.first.label, startsWith('Mo'));
    expect(month.studySeconds, 90 * 60);
    expect(month.dailyStudy.length, 30);
  });

  test('study time is aggregated by subject, exam and task', () {
    final state = StudyBuddyState(
      subjects: const [
        SubjectItem(id: 'math', name: 'Mathematik', color: Color(0xFFB56D8C)),
      ],
      exams: const [
        ExamOverview(
          id: 'exam',
          subject: 'Mathematik',
          dateLabel: '01.10.2026',
        ),
      ],
      tasks: const [TaskItem(id: 'task', title: 'Übungsblatt')],
      studySessions: [
        session(
          id: 'a',
          start: DateTime(2026, 9, 21, 9),
          minutes: 45,
          subjectId: 'math',
          examId: 'exam',
          taskId: 'task',
        ),
      ],
    );

    final report = service.buildReport(
      state,
      service.weekRange(DateTime(2026, 9, 24)),
    );

    expect(report.subjectStudy.single.name, 'Mathematik');
    expect(report.examStudy.single.seconds, 45 * 60);
    expect(report.taskStudy.single.seconds, 45 * 60);
  });

  test('previous period comparison handles zero previous period', () {
    final state = StudyBuddyState(
      studySessions: [
        session(id: 'a', start: DateTime(2026, 9, 21, 9), minutes: 60),
      ],
    );

    final report = service.buildReport(
      state,
      service.weekRange(DateTime(2026, 9, 24)),
    );

    expect(report.previousStudySeconds, 0);
    expect(report.differenceToPrevious, 60 * 60);
    expect(report.insights.join(' '), isNot(contains('Infinity')));
    expect(report.insights.join(' '), isNot(contains('NaN')));
  });

  test('session across midnight is split into both local days', () {
    final split = service.splitSessionByDay(
      session(id: 'night', start: DateTime(2026, 9, 24, 23, 30), minutes: 60),
    );

    expect(split, hasLength(2));
    expect(split[0].date, DateTime(2026, 9, 24));
    expect(split[0].seconds, 30 * 60);
    expect(split[1].date, DateTime(2026, 9, 25));
    expect(split[1].seconds, 30 * 60);
  });

  test('task, exam and streak stats use real domain fields', () {
    final state = StudyBuddyState(
      tasks: [
        TaskItem(
          id: 'done',
          title: 'Fertig',
          status: TaskStatus.completed,
          createdAt: DateTime(2026, 9, 21),
          completedAt: DateTime(2026, 9, 22),
        ),
        TaskItem(id: 'late', title: 'Offen', dueAt: DateTime(2020)),
      ],
      exams: const [
        ExamOverview(
          id: 'graded',
          subject: 'Deutsch',
          dateLabel: '22.09.2026',
          status: ExamStatus.passed,
          grade: 2,
        ),
      ],
      studySessions: [
        session(id: 'a', start: DateTime(2026, 9, 21, 9), minutes: 10),
        session(id: 'b', start: DateTime(2026, 9, 22, 9), minutes: 10),
      ],
    );

    final report = service.buildReport(
      state,
      service.weekRange(DateTime(2026, 9, 24)),
    );

    expect(report.taskStats.completed, 1);
    expect(report.taskStats.open, 1);
    expect(report.taskStats.overdue, 1);
    expect(report.examStats.compatibleGradeAverage, 2);
    expect(report.streakStats.studyDaysInRange, 2);
  });

  test('empty dataset and discarded sessions produce zero analytics', () {
    final state = StudyBuddyState(
      studySessions: [
        session(
          id: 'discarded',
          start: DateTime(2026, 9, 21, 9),
          minutes: 60,
          status: StudySessionStatus.discarded,
        ),
      ],
    );

    final report = service.buildReport(
      state,
      service.weekRange(DateTime(2026, 9, 24)),
    );

    expect(report.studySeconds, 0);
    expect(report.sessionCount, 0);
    expect(report.hasStudyData, isFalse);
  });

  test('leap year, month switch and year switch ranges are valid', () {
    final february = service.monthRange(DateTime(2028, 2, 29));
    final december = service.monthRange(DateTime(2026, 12, 31));
    final january = service.shiftRange(december, 1);

    expect(february.dailyStudyLengthForTest, 29);
    expect(january.start, DateTime(2027, 1, 1));
    expect(service.yearRange(DateTime(2027, 1, 1)).start, DateTime(2027));
  });
}

extension on AnalyticsRange {
  int get dailyStudyLengthForTest => end.difference(start).inDays + 1;
}
