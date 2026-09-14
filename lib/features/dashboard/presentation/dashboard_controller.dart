import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_buddy_repository.dart';
import '../domain/dashboard_models.dart';

final studyBuddyRepositoryProvider = Provider<StudyBuddyRepository>((ref) {
  final repository = createStudyBuddyRepository();
  ref.onDispose(repository.dispose);
  return repository;
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
    Future<void>.microtask(_loadPersistedState);
    return const StudyBuddyState();
  }

  Future<void> _loadPersistedState() async {
    final repository = ref.read(studyBuddyRepositoryProvider);
    final persistedState = await repository.loadInitialState();
    state = persistedState.copyWith(
      selectedIndex: state.selectedIndex,
      focusSeconds: state.focusSeconds,
      timerRunning: state.timerRunning,
    );
  }

  void selectDestination(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void addScheduleItem(String time, String title) {
    final item = TimedItem(id: _id(), time: time, title: title);
    state = state.copyWith(schedule: [...state.schedule, item]);
    unawaited(ref.read(studyBuddyRepositoryProvider).addScheduleItem(item));
  }

  void addTask(String title) {
    final task = TaskItem(id: _id(), title: title);
    state = state.copyWith(tasks: [...state.tasks, task]);
    unawaited(ref.read(studyBuddyRepositoryProvider).addTask(task));
  }

  void toggleTask(String id) {
    TaskItem? updatedTask;
    state = state.copyWith(
      tasks: [
        for (final task in state.tasks)
          if (task.id == id)
            updatedTask = task.copyWith(done: !task.done)
          else
            task,
      ],
    );

    if (updatedTask != null) {
      unawaited(ref.read(studyBuddyRepositoryProvider).updateTask(updatedTask));
    }
  }

  void addNote(String title, String body) {
    final note = NoteItem(id: _id(), title: title, body: body);
    state = state.copyWith(notes: [...state.notes, note]);
    unawaited(ref.read(studyBuddyRepositoryProvider).addNote(note));
  }

  void addSubject(String name) {
    final subject = SubjectItem(id: _id(), name: name);
    state = state.copyWith(subjects: [...state.subjects, subject]);
    unawaited(ref.read(studyBuddyRepositoryProvider).addSubject(subject));
  }

  void addExam(String subject, String dateLabel) {
    final exam = ExamOverview(
      id: _id(),
      subject: subject,
      dateLabel: dateLabel,
    );
    state = state.copyWith(exams: [...state.exams, exam]);
    unawaited(ref.read(studyBuddyRepositoryProvider).addExam(exam));
  }

  void addReminder(String title, String dateLabel) {
    final reminder = ReminderItem(
      id: _id(),
      title: title,
      dateLabel: dateLabel,
    );
    state = state.copyWith(reminders: [...state.reminders, reminder]);
    unawaited(ref.read(studyBuddyRepositoryProvider).addReminder(reminder));
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
