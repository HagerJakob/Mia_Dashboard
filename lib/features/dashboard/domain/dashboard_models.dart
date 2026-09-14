import 'package:flutter/material.dart';

class StudyBuddyState {
  const StudyBuddyState({
    this.selectedIndex = 0,
    this.schedule = const [],
    this.tasks = const [],
    this.notes = const [],
    this.subjects = const [],
    this.exams = const [],
    this.reminders = const [],
    this.focusSeconds = 25 * 60,
    this.timerRunning = false,
  });

  final int selectedIndex;
  final List<TimedItem> schedule;
  final List<TaskItem> tasks;
  final List<NoteItem> notes;
  final List<SubjectItem> subjects;
  final List<ExamOverview> exams;
  final List<ReminderItem> reminders;
  final int focusSeconds;
  final bool timerRunning;

  StudyBuddyState copyWith({
    int? selectedIndex,
    List<TimedItem>? schedule,
    List<TaskItem>? tasks,
    List<NoteItem>? notes,
    List<SubjectItem>? subjects,
    List<ExamOverview>? exams,
    List<ReminderItem>? reminders,
    int? focusSeconds,
    bool? timerRunning,
  }) {
    return StudyBuddyState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      schedule: schedule ?? this.schedule,
      tasks: tasks ?? this.tasks,
      notes: notes ?? this.notes,
      subjects: subjects ?? this.subjects,
      exams: exams ?? this.exams,
      reminders: reminders ?? this.reminders,
      focusSeconds: focusSeconds ?? this.focusSeconds,
      timerRunning: timerRunning ?? this.timerRunning,
    );
  }
}

class KpiItem {
  const KpiItem(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class TimedItem {
  const TimedItem({required this.id, required this.time, required this.title});

  final String id;
  final String time;
  final String title;
}

class TaskItem {
  const TaskItem({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  TaskItem copyWith({bool? done}) {
    return TaskItem(id: id, title: title, done: done ?? this.done);
  }
}

class NoteItem {
  const NoteItem({required this.id, required this.title, this.body = ''});

  final String id;
  final String title;
  final String body;
}

class SubjectItem {
  const SubjectItem({
    required this.id,
    required this.name,
    this.color = const Color(0xFFB56D8C),
  });

  final String id;
  final String name;
  final Color color;
}

class ExamOverview {
  const ExamOverview({
    required this.id,
    required this.subject,
    required this.dateLabel,
    this.progress = 0,
    this.chapters = const [],
  });

  final String id;
  final String subject;
  final String dateLabel;
  final double progress;
  final List<ChapterProgress> chapters;
}

class ChapterProgress {
  const ChapterProgress(this.title, this.done);

  final String title;
  final bool done;
}

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.dateLabel,
  });

  final String id;
  final String title;
  final String dateLabel;
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
