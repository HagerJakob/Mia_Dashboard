import 'package:flutter/material.dart';

class DashboardData {
  const DashboardData({
    required this.kpis,
    required this.schedule,
    required this.tasks,
    required this.exam,
    required this.studyHours,
    required this.notes,
    required this.dailyGoal,
  });

  final List<KpiItem> kpis;
  final List<TimedItem> schedule;
  final List<TaskItem> tasks;
  final ExamOverview exam;
  final List<StudyHour> studyHours;
  final List<String> notes;
  final DailyGoal dailyGoal;
}

class KpiItem {
  const KpiItem(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class TimedItem {
  const TimedItem(this.time, this.title);

  final String time;
  final String title;
}

class TaskItem {
  const TaskItem(this.title, this.done);

  final String title;
  final bool done;
}

class ExamOverview {
  const ExamOverview({
    required this.subject,
    required this.dateLabel,
    required this.remainingLabel,
    required this.progress,
    required this.chapters,
  });

  final String subject;
  final String dateLabel;
  final String remainingLabel;
  final double progress;
  final List<ChapterProgress> chapters;
}

class ChapterProgress {
  const ChapterProgress(this.title, this.done);

  final String title;
  final bool done;
}

class StudyHour {
  const StudyHour(this.day, this.hours);

  final String day;
  final double hours;
}

class DailyGoal {
  const DailyGoal(this.label, this.progress);

  final String label;
  final double progress;
}
