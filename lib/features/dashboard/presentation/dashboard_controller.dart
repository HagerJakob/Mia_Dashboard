import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_buddy_repository.dart';
import '../domain/dashboard_models.dart';

final studyBuddyRepositoryProvider = Provider<StudyBuddyRepository>((ref) {
  return const InMemoryStudyBuddyRepository();
});

final studyBuddyControllerProvider =
    NotifierProvider<StudyBuddyController, StudyBuddyState>(
      StudyBuddyController.new,
    );

class StudyBuddyController extends Notifier<StudyBuddyState> {
  Timer? _timer;

  @override
  StudyBuddyState build() {
    ref.onDispose(() => _timer?.cancel());
    return ref.read(studyBuddyRepositoryProvider).loadInitialState();
  }

  void selectDestination(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void addScheduleItem(String time, String title) {
    state = state.copyWith(
      schedule: [
        ...state.schedule,
        TimedItem(id: _id(), time: time, title: title),
      ],
    );
  }

  void addTask(String title) {
    state = state.copyWith(
      tasks: [
        ...state.tasks,
        TaskItem(id: _id(), title: title),
      ],
    );
  }

  void toggleTask(String id) {
    state = state.copyWith(
      tasks: [
        for (final task in state.tasks)
          if (task.id == id) task.copyWith(done: !task.done) else task,
      ],
    );
  }

  void addNote(String title, String body) {
    state = state.copyWith(
      notes: [
        ...state.notes,
        NoteItem(id: _id(), title: title, body: body),
      ],
    );
  }

  void addSubject(String name) {
    state = state.copyWith(
      subjects: [
        ...state.subjects,
        SubjectItem(id: _id(), name: name),
      ],
    );
  }

  void addExam(String subject, String dateLabel) {
    state = state.copyWith(
      exams: [
        ...state.exams,
        ExamOverview(id: _id(), subject: subject, dateLabel: dateLabel),
      ],
    );
  }

  void addReminder(String title, String dateLabel) {
    state = state.copyWith(
      reminders: [
        ...state.reminders,
        ReminderItem(id: _id(), title: title, dateLabel: dateLabel),
      ],
    );
  }

  void toggleTimer() {
    final shouldRun = !state.timerRunning;
    state = state.copyWith(timerRunning: shouldRun);
    _timer?.cancel();

    if (!shouldRun) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.focusSeconds <= 1) {
        _timer?.cancel();
        state = state.copyWith(focusSeconds: 0, timerRunning: false);
        return;
      }
      state = state.copyWith(focusSeconds: state.focusSeconds - 1);
    });
  }

  void resetTimer() {
    _timer?.cancel();
    state = state.copyWith(focusSeconds: 25 * 60, timerRunning: false);
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
