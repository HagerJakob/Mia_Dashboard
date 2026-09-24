import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../dashboard/domain/dashboard_models.dart';

enum AnalyticsPeriod { week, month, semester, year, custom }

class AnalyticsRange {
  const AnalyticsRange({
    required this.period,
    required this.start,
    required this.end,
  });

  final AnalyticsPeriod period;
  final DateTime start;
  final DateTime end;

  AnalyticsRange previous() {
    final days = end.difference(start).inDays + 1;
    final previousEnd = start.subtract(const Duration(days: 1));
    return AnalyticsRange(
      period: period,
      start: previousEnd.subtract(Duration(days: days - 1)),
      end: previousEnd,
    );
  }
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.range,
    required this.previousStudySeconds,
    required this.studySeconds,
    required this.sessionCount,
    required this.averageSessionSeconds,
    required this.longestSessionSeconds,
    required this.shortestMeaningfulSessionSeconds,
    required this.pomodoroCount,
    required this.taskStats,
    required this.examStats,
    required this.streakStats,
    required this.dailyStudy,
    required this.subjectStudy,
    required this.examStudy,
    required this.taskStudy,
    required this.timeOfDayStudy,
    required this.weekdayAverageStudy,
    required this.heatmapDays,
    required this.insights,
  });

  final AnalyticsRange range;
  final int previousStudySeconds;
  final int studySeconds;
  final int sessionCount;
  final int averageSessionSeconds;
  final int longestSessionSeconds;
  final int shortestMeaningfulSessionSeconds;
  final int pomodoroCount;
  final TaskAnalytics taskStats;
  final ExamAnalytics examStats;
  final StreakAnalytics streakStats;
  final List<AnalyticsBucket> dailyStudy;
  final List<SubjectAnalytics> subjectStudy;
  final List<ExamStudyAnalytics> examStudy;
  final List<TaskStudyAnalytics> taskStudy;
  final List<AnalyticsBucket> timeOfDayStudy;
  final List<AnalyticsBucket> weekdayAverageStudy;
  final List<HeatmapDay> heatmapDays;
  final List<String> insights;

  int get activeDays => dailyStudy.where((day) => day.seconds > 0).length;
  int get differenceToPrevious => studySeconds - previousStudySeconds;
  bool get hasStudyData => studySeconds > 0 || sessionCount > 0;
}

class AnalyticsBucket {
  const AnalyticsBucket(this.label, this.seconds, {this.date});
  final String label;
  final int seconds;
  final DateTime? date;
}

class SubjectAnalytics {
  const SubjectAnalytics({
    required this.subjectId,
    required this.name,
    required this.seconds,
    required this.color,
  });

  final String? subjectId;
  final String name;
  final int seconds;
  final Color color;
}

class ExamStudyAnalytics {
  const ExamStudyAnalytics({
    required this.exam,
    required this.seconds,
    required this.sessionCount,
  });

  final ExamOverview exam;
  final int seconds;
  final int sessionCount;
}

class TaskStudyAnalytics {
  const TaskStudyAnalytics({
    required this.task,
    required this.seconds,
    required this.sessionCount,
  });

  final TaskItem task;
  final int seconds;
  final int sessionCount;
}

class TaskAnalytics {
  const TaskAnalytics({
    required this.created,
    required this.completed,
    required this.open,
    required this.overdue,
    required this.completionRate,
  });

  final int created;
  final int completed;
  final int open;
  final int overdue;
  final double completionRate;
}

class ExamAnalytics {
  const ExamAnalytics({
    required this.total,
    required this.completed,
    required this.resultsPending,
    required this.passed,
    required this.failed,
    required this.graded,
    required this.compatibleGradeAverage,
  });

  final int total;
  final int completed;
  final int resultsPending;
  final int passed;
  final int failed;
  final List<ExamOverview> graded;
  final double? compatibleGradeAverage;
}

class StreakAnalytics {
  const StreakAnalytics({
    required this.currentDays,
    required this.longestDays,
    required this.studyDaysInRange,
  });

  final int currentDays;
  final int longestDays;
  final int studyDaysInRange;
}

class HeatmapDay {
  const HeatmapDay({
    required this.date,
    required this.seconds,
    required this.sessionCount,
    required this.level,
    required this.subjectSeconds,
  });

  final DateTime date;
  final int seconds;
  final int sessionCount;
  final int level;
  final Map<String, int> subjectSeconds;
}

class AnalyticsService {
  const AnalyticsService();

  static const int learningDayThresholdSeconds = 10 * 60;
  static const int shortestMeaningfulSessionSeconds = 15 * 60;

  AnalyticsReport buildReport(
    StudyBuddyState state,
    AnalyticsRange range, {
    String? subjectId,
    String? examId,
  }) {
    final currentSessions = _filteredSessions(
      state.studySessions,
      range,
      subjectId: subjectId,
      examId: examId,
    );
    final previousRange = range.previous();
    final previousSessions = _filteredSessions(
      state.studySessions,
      previousRange,
      subjectId: subjectId,
      examId: examId,
    );
    final dailyStudy = _studyByDay(currentSessions, range);
    final previousStudySeconds = _totalSeconds(previousSessions, previousRange);
    final studySeconds = dailyStudy.fold<int>(
      0,
      (sum, bucket) => sum + bucket.seconds,
    );
    final completedSessions = currentSessions
        .where((session) => session.status == StudySessionStatus.completed)
        .toList();
    final tasks = _filteredTasks(state.tasks, range, subjectId: subjectId);
    final exams = _filteredExams(state.exams, range, subjectId: subjectId);
    final studyDayMap = {
      for (final bucket in _studyByDay(state.studySessions, _fullRange()))
        if (bucket.seconds >= learningDayThresholdSeconds)
          _dayKey(bucket.date!),
    };

    return AnalyticsReport(
      range: range,
      previousStudySeconds: previousStudySeconds,
      studySeconds: studySeconds,
      sessionCount: completedSessions.length,
      averageSessionSeconds: completedSessions.isEmpty
          ? 0
          : studySeconds ~/ completedSessions.length,
      longestSessionSeconds: completedSessions.fold<int>(
        0,
        (max, session) => math.max(max, session.focusDurationSeconds),
      ),
      shortestMeaningfulSessionSeconds: completedSessions
          .map((session) => session.focusDurationSeconds)
          .where((seconds) => seconds >= shortestMeaningfulSessionSeconds)
          .fold<int>(
            0,
            (min, seconds) => min == 0 ? seconds : math.min(min, seconds),
          ),
      pomodoroCount: completedSessions
          .where((session) => session.mode == TimerMode.pomodoro)
          .length,
      taskStats: _taskStats(tasks, range),
      examStats: _examStats(exams),
      streakStats: _streakStats(studyDayMap, range),
      dailyStudy: dailyStudy,
      subjectStudy: _studyBySubject(currentSessions, state.subjects, range),
      examStudy: _studyByExam(currentSessions, state.exams, range),
      taskStudy: _studyByTask(currentSessions, state.tasks, range),
      timeOfDayStudy: _studyByTimeOfDay(currentSessions, range),
      weekdayAverageStudy: _weekdayAverages(currentSessions, range),
      heatmapDays: _heatmap(currentSessions, state.subjects, range),
      insights: _insights(
        studySeconds: studySeconds,
        previousSeconds: previousStudySeconds,
        dailyStudy: dailyStudy,
        subjectStudy: _studyBySubject(currentSessions, state.subjects, range),
        averageSessionSeconds: completedSessions.isEmpty
            ? 0
            : studySeconds ~/ completedSessions.length,
      ),
    );
  }

  List<AnalyticsBucket> studyByDay(
    List<StudySession> sessions,
    AnalyticsRange range,
  ) => _studyByDay(sessions, range);

  List<StudyInterval> splitSessionByDay(StudySession session) =>
      _splitSessionByDay(session);

  AnalyticsRange weekRange(DateTime date) {
    final day = _dateOnly(date);
    final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return AnalyticsRange(
      period: AnalyticsPeriod.week,
      start: start,
      end: start.add(const Duration(days: 6)),
    );
  }

  AnalyticsRange monthRange(DateTime date) {
    final start = DateTime(date.year, date.month);
    return AnalyticsRange(
      period: AnalyticsPeriod.month,
      start: start,
      end: DateTime(date.year, date.month + 1, 0),
    );
  }

  AnalyticsRange yearRange(DateTime date) => AnalyticsRange(
    period: AnalyticsPeriod.year,
    start: DateTime(date.year),
    end: DateTime(date.year, 12, 31),
  );

  AnalyticsRange semesterRange(DateTime date) {
    if (date.month >= 9 || date.month <= 2) {
      final year = date.month <= 2 ? date.year - 1 : date.year;
      return AnalyticsRange(
        period: AnalyticsPeriod.semester,
        start: DateTime(year, 9),
        end: DateTime(year + 1, 2, 28),
      );
    }
    return AnalyticsRange(
      period: AnalyticsPeriod.semester,
      start: DateTime(date.year, 3),
      end: DateTime(date.year, 8, 31),
    );
  }

  AnalyticsRange shiftRange(AnalyticsRange range, int direction) {
    return switch (range.period) {
      AnalyticsPeriod.week => weekRange(
        range.start.add(Duration(days: 7 * direction)),
      ),
      AnalyticsPeriod.month => monthRange(
        DateTime(range.start.year, range.start.month + direction),
      ),
      AnalyticsPeriod.semester => semesterRange(
        DateTime(range.start.year, range.start.month + 6 * direction),
      ),
      AnalyticsPeriod.year => yearRange(DateTime(range.start.year + direction)),
      AnalyticsPeriod.custom => AnalyticsRange(
        period: AnalyticsPeriod.custom,
        start: range.start.add(
          Duration(
            days: (range.end.difference(range.start).inDays + 1) * direction,
          ),
        ),
        end: range.end.add(
          Duration(
            days: (range.end.difference(range.start).inDays + 1) * direction,
          ),
        ),
      ),
    };
  }

  List<StudySession> _filteredSessions(
    List<StudySession> sessions,
    AnalyticsRange range, {
    String? subjectId,
    String? examId,
  }) {
    final start = range.start;
    final endExclusive = range.end.add(const Duration(days: 1));
    return sessions.where((session) {
      if (subjectId != null && session.subjectId != subjectId) return false;
      if (examId != null && session.examId != examId) return false;
      if (session.status == StudySessionStatus.discarded) return false;
      final sessionEnd = _sessionEnd(session);
      return sessionEnd.isAfter(start) &&
          session.startedAt.isBefore(endExclusive);
    }).toList();
  }

  List<TaskItem> _filteredTasks(
    List<TaskItem> tasks,
    AnalyticsRange range, {
    String? subjectId,
  }) {
    return tasks.where((task) {
      if (subjectId != null && task.subjectId != subjectId) return false;
      return true;
    }).toList();
  }

  List<ExamOverview> _filteredExams(
    List<ExamOverview> exams,
    AnalyticsRange range, {
    String? subjectId,
  }) {
    return exams.where((exam) {
      if (subjectId != null && exam.subjectId != subjectId) return false;
      final date = exam.startAt ?? exam.createdAt;
      return date == null || _inRange(date, range);
    }).toList();
  }

  List<AnalyticsBucket> _studyByDay(
    List<StudySession> sessions,
    AnalyticsRange range,
  ) {
    final byDay = <String, int>{};
    for (final session in sessions) {
      for (final interval in _splitSessionByDay(session)) {
        if (!_inRange(interval.date, range)) continue;
        byDay.update(
          _dayKey(interval.date),
          (value) => value + interval.seconds,
          ifAbsent: () => interval.seconds,
        );
      }
    }
    final days = range.end.difference(range.start).inDays + 1;
    return [
      for (var i = 0; i < days; i++)
        AnalyticsBucket(
          _dayLabel(range.start.add(Duration(days: i))),
          byDay[_dayKey(range.start.add(Duration(days: i)))] ?? 0,
          date: range.start.add(Duration(days: i)),
        ),
    ];
  }

  int _totalSeconds(List<StudySession> sessions, AnalyticsRange range) =>
      _studyByDay(sessions, range).fold(0, (sum, day) => sum + day.seconds);

  List<StudyInterval> _splitSessionByDay(StudySession session) {
    final end = _sessionEnd(session);
    if (!end.isAfter(session.startedAt) || session.focusDurationSeconds <= 0) {
      return const [];
    }
    final totalWallSeconds = end.difference(session.startedAt).inSeconds;
    if (totalWallSeconds <= 0) return const [];
    final result = <StudyInterval>[];
    var cursor = session.startedAt;
    while (cursor.isBefore(end)) {
      final nextMidnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final partEnd = nextMidnight.isBefore(end) ? nextMidnight : end;
      final wallPart = partEnd.difference(cursor).inSeconds;
      final focusPart =
          (session.focusDurationSeconds * wallPart / totalWallSeconds).round();
      result.add(StudyInterval(_dateOnly(cursor), focusPart));
      cursor = partEnd;
    }
    final drift =
        session.focusDurationSeconds -
        result.fold<int>(0, (sum, interval) => sum + interval.seconds);
    if (result.isNotEmpty && drift != 0) {
      final last = result.removeLast();
      result.add(StudyInterval(last.date, math.max(0, last.seconds + drift)));
    }
    return result;
  }

  List<SubjectAnalytics> _studyBySubject(
    List<StudySession> sessions,
    List<SubjectItem> subjects,
    AnalyticsRange range,
  ) {
    final secondsBySubject = <String?, int>{};
    for (final session in sessions) {
      final seconds = _sessionSecondsInRange(session, range);
      if (seconds <= 0) continue;
      secondsBySubject.update(
        session.subjectId,
        (value) => value + seconds,
        ifAbsent: () => seconds,
      );
    }
    final items = [
      for (final entry in secondsBySubject.entries)
        SubjectAnalytics(
          subjectId: entry.key,
          name:
              subjects
                  .where((subject) => subject.id == entry.key)
                  .firstOrNull
                  ?.name ??
              'Ohne Fach',
          color:
              subjects
                  .where((subject) => subject.id == entry.key)
                  .firstOrNull
                  ?.color ??
              const Color(0xFFB56D8C),
          seconds: entry.value,
        ),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return items;
  }

  List<ExamStudyAnalytics> _studyByExam(
    List<StudySession> sessions,
    List<ExamOverview> exams,
    AnalyticsRange range,
  ) {
    return [
        for (final exam in exams)
          ExamStudyAnalytics(
            exam: exam,
            seconds: sessions
                .where((session) => session.examId == exam.id)
                .fold<int>(
                  0,
                  (sum, session) =>
                      sum + _sessionSecondsInRange(session, range),
                ),
            sessionCount: sessions
                .where(
                  (session) =>
                      session.examId == exam.id &&
                      _sessionSecondsInRange(session, range) > 0,
                )
                .length,
          ),
      ].where((item) => item.seconds > 0 || item.exam.startAt != null).toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
  }

  List<TaskStudyAnalytics> _studyByTask(
    List<StudySession> sessions,
    List<TaskItem> tasks,
    AnalyticsRange range,
  ) {
    return [
        for (final task in tasks)
          TaskStudyAnalytics(
            task: task,
            seconds: sessions
                .where((session) => session.taskId == task.id)
                .fold<int>(
                  0,
                  (sum, session) =>
                      sum + _sessionSecondsInRange(session, range),
                ),
            sessionCount: sessions
                .where(
                  (session) =>
                      session.taskId == task.id &&
                      _sessionSecondsInRange(session, range) > 0,
                )
                .length,
          ),
      ].where((item) => item.seconds > 0).toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
  }

  List<AnalyticsBucket> _studyByTimeOfDay(
    List<StudySession> sessions,
    AnalyticsRange range,
  ) {
    final values = {'Morgen': 0, 'Nachmittag': 0, 'Abend': 0, 'Nacht': 0};
    for (final session in sessions) {
      final label = switch (session.startedAt.hour) {
        >= 6 && < 12 => 'Morgen',
        >= 12 && < 18 => 'Nachmittag',
        >= 18 && < 22 => 'Abend',
        _ => 'Nacht',
      };
      values[label] = values[label]! + _sessionSecondsInRange(session, range);
    }
    return [
      for (final entry in values.entries)
        AnalyticsBucket(entry.key, entry.value),
    ];
  }

  List<AnalyticsBucket> _weekdayAverages(
    List<StudySession> sessions,
    AnalyticsRange range,
  ) {
    final totals = List<int>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final day in _studyByDay(sessions, range)) {
      final date = day.date!;
      totals[date.weekday - 1] += day.seconds;
      counts[date.weekday - 1] += 1;
    }
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return [
      for (var i = 0; i < 7; i++)
        AnalyticsBucket(labels[i], counts[i] == 0 ? 0 : totals[i] ~/ counts[i]),
    ];
  }

  List<HeatmapDay> _heatmap(
    List<StudySession> sessions,
    List<SubjectItem> subjects,
    AnalyticsRange range,
  ) {
    final subjectNames = {
      for (final subject in subjects) subject.id: subject.name,
    };
    final secondsByDay = <String, int>{};
    final sessionsByDay = <String, int>{};
    final subjectsByDay = <String, Map<String, int>>{};
    for (final session in sessions) {
      for (final interval in _splitSessionByDay(session)) {
        if (!_inRange(interval.date, range)) continue;
        final key = _dayKey(interval.date);
        secondsByDay.update(
          key,
          (value) => value + interval.seconds,
          ifAbsent: () => interval.seconds,
        );
        sessionsByDay.update(key, (value) => value + 1, ifAbsent: () => 1);
        final name = subjectNames[session.subjectId] ?? 'Ohne Fach';
        subjectsByDay.putIfAbsent(key, () => {});
        subjectsByDay[key]!.update(
          name,
          (value) => value + interval.seconds,
          ifAbsent: () => interval.seconds,
        );
      }
    }
    final days = range.end.difference(range.start).inDays + 1;
    return [
      for (var i = 0; i < days; i++)
        HeatmapDay(
          date: range.start.add(Duration(days: i)),
          seconds:
              secondsByDay[_dayKey(range.start.add(Duration(days: i)))] ?? 0,
          sessionCount:
              sessionsByDay[_dayKey(range.start.add(Duration(days: i)))] ?? 0,
          level: _heatLevel(
            secondsByDay[_dayKey(range.start.add(Duration(days: i)))] ?? 0,
          ),
          subjectSeconds:
              subjectsByDay[_dayKey(range.start.add(Duration(days: i)))] ??
              const {},
        ),
    ];
  }

  TaskAnalytics _taskStats(List<TaskItem> tasks, AnalyticsRange range) {
    final created = tasks
        .where((task) => _inRange(task.createdAt, range))
        .length;
    final completed = tasks
        .where((task) => task.done && _inRange(task.completedAt, range))
        .length;
    final open = tasks.where((task) => !task.done).length;
    final overdue = tasks
        .where(
          (task) =>
              task.dueAt != null &&
              !task.done &&
              task.dueAt!.isBefore(DateTime.now()),
        )
        .length;
    final relevant = created + completed;
    return TaskAnalytics(
      created: created,
      completed: completed,
      open: open,
      overdue: overdue,
      completionRate: relevant == 0 ? 0 : completed / relevant,
    );
  }

  ExamAnalytics _examStats(List<ExamOverview> exams) {
    final graded = exams
        .where(
          (exam) =>
              exam.grade != null &&
              exam.grade! >= 1 &&
              exam.grade! <= 5 &&
              exam.pointsAchieved == null,
        )
        .toList();
    return ExamAnalytics(
      total: exams.length,
      completed: exams.where((exam) => exam.isCompleted).length,
      resultsPending: exams
          .where((exam) => exam.status == ExamStatus.resultPending)
          .length,
      passed: exams.where((exam) => exam.passed == true).length,
      failed: exams.where((exam) => exam.passed == false).length,
      graded: graded,
      compatibleGradeAverage: graded.isEmpty
          ? null
          : graded.fold<double>(0, (sum, exam) => sum + exam.grade!) /
                graded.length,
    );
  }

  StreakAnalytics _streakStats(Set<String> studyDays, AnalyticsRange range) {
    var current = 0;
    var cursor = _dateOnly(DateTime.now());
    while (studyDays.contains(_dayKey(cursor))) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var longest = 0;
    var running = 0;
    final sorted = studyDays.toList()..sort();
    DateTime? previous;
    for (final key in sorted) {
      final parts = key.split('-').map(int.parse).toList();
      final day = DateTime(parts[0], parts[1], parts[2]);
      if (previous != null && day.difference(previous).inDays == 1) {
        running++;
      } else {
        running = 1;
      }
      longest = math.max(longest, running);
      previous = day;
    }
    final studyDaysInRange = studyDays.where((key) {
      final parts = key.split('-').map(int.parse).toList();
      return _inRange(DateTime(parts[0], parts[1], parts[2]), range);
    }).length;
    return StreakAnalytics(
      currentDays: current,
      longestDays: longest,
      studyDaysInRange: studyDaysInRange,
    );
  }

  List<String> _insights({
    required int studySeconds,
    required int previousSeconds,
    required List<AnalyticsBucket> dailyStudy,
    required List<SubjectAnalytics> subjectStudy,
    required int averageSessionSeconds,
  }) {
    final result = <String>[];
    final diff = studySeconds - previousSeconds;
    if (previousSeconds > 0 && diff != 0) {
      result.add(
        diff > 0
            ? 'Du hast ${formatDuration(diff)} mehr gelernt als im vorherigen Zeitraum.'
            : 'Du hast ${formatDuration(diff.abs())} weniger gelernt als im vorherigen Zeitraum.',
      );
    } else if (previousSeconds == 0 && studySeconds > 0) {
      result.add(
        '${formatDuration(studySeconds)} Lernzeit gegenüber keinem erfassten Wert im vorherigen Zeitraum.',
      );
    }
    final activeDays = dailyStudy.where((day) => day.seconds > 0).length;
    if (activeDays > 0) {
      result.add('Du hast an $activeDays Tagen in diesem Zeitraum gelernt.');
    }
    if (subjectStudy.isNotEmpty && studySeconds > 0) {
      final top = subjectStudy.first;
      final share = (top.seconds / studySeconds * 100).round();
      result.add('${top.name} machte $share % deiner Lernzeit aus.');
    }
    final strongest = dailyStudy.fold<AnalyticsBucket?>(
      null,
      (best, day) => best == null || day.seconds > best.seconds ? day : best,
    );
    if (strongest != null && strongest.seconds > 0) {
      result.add(
        '${strongest.label} war mit ${formatDuration(strongest.seconds)} der lernintensivste Tag.',
      );
    }
    if (averageSessionSeconds > 0) {
      result.add(
        'Deine durchschnittliche Focus Session dauerte ${formatDuration(averageSessionSeconds)}.',
      );
    }
    return result.take(5).toList();
  }

  int _sessionSecondsInRange(StudySession session, AnalyticsRange range) {
    return _splitSessionByDay(session)
        .where((interval) => _inRange(interval.date, range))
        .fold<int>(0, (sum, interval) => sum + interval.seconds);
  }

  DateTime _sessionEnd(StudySession session) =>
      session.endedAt ??
      session.startedAt.add(Duration(seconds: session.focusDurationSeconds));

  AnalyticsRange _fullRange() => AnalyticsRange(
    period: AnalyticsPeriod.custom,
    start: DateTime(2020),
    end: DateTime(2035, 12, 31),
  );

  static int _heatLevel(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes <= 0) return 0;
    if (minutes <= 30) return 1;
    if (minutes <= 60) return 2;
    if (minutes <= 120) return 3;
    return 4;
  }
}

class StudyInterval {
  const StudyInterval(this.date, this.seconds);
  final DateTime date;
  final int seconds;
}

String formatDuration(int seconds) {
  final safe = math.max(0, seconds);
  final totalMinutes = (safe / 60).round();
  if (totalMinutes < 60) return '$totalMinutes min';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '$hours h';
  return '$hours h ${minutes.toString().padLeft(2, '0')} min';
}

String formatDateRange(AnalyticsRange range) {
  final start = range.start;
  final end = range.end;
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}.–${end.day}. ${_monthName(start.month)} ${start.year}';
  }
  return '${start.day}. ${_monthName(start.month)} ${start.year} – ${end.day}. ${_monthName(end.month)} ${end.year}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _inRange(DateTime? value, AnalyticsRange range) {
  if (value == null) return false;
  final day = _dateOnly(value);
  return !day.isBefore(range.start) && !day.isAfter(range.end);
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _dayLabel(DateTime date) {
  const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  return '${labels[date.weekday - 1]} ${date.day}.';
}

String _monthName(int month) => const [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
][month - 1];
