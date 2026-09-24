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
    Future<void>.microtask(_loadPersistedState).catchError((Object _) {});
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
    await syncNow();
  }

  Future<void> syncNow() async {
    final repository = ref.read(studyBuddyRepositoryProvider);
    await repository.syncNow();
    final fresh = await repository.loadInitialState();
    state = fresh.copyWith(
      selectedIndex: state.selectedIndex,
      focusSeconds: state.focusSeconds,
      timerRunning: state.timerRunning,
    );
  }

  Future<void> _save(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // The local write remains queued for the next successful sync.
    }
  }

  void selectDestination(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void addScheduleItem(String time, String title) {
    final item = TimedItem(id: _id(), time: time, title: title);
    state = state.copyWith(schedule: [...state.schedule, item]);
    unawaited(
      _save(ref.read(studyBuddyRepositoryProvider).addScheduleItem(item)),
    );
  }

  void addTask(String title) {
    final task = TaskItem(id: _id(), title: title);
    unawaited(saveTask(task));
  }

  Future<void> saveTask(TaskItem task) async {
    final exists = state.tasks.any((item) => item.id == task.id);
    state = state.copyWith(
      tasks: [
        for (final item in state.tasks)
          if (item.id == task.id) task else item,
        if (!exists) task,
      ],
    );
    final repo = ref.read(studyBuddyRepositoryProvider);
    await _save(exists ? repo.updateTask(task) : repo.addTask(task));
  }

  void toggleTask(String id) {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) return;
    final now = DateTime.now();
    final updatedTask = task.done
        ? task.copyWith(status: TaskStatus.open, completedAt: null)
        : task.copyWith(status: TaskStatus.completed, completedAt: now);
    unawaited(saveTask(updatedTask));
  }

  Future<void> deleteTask(String id) async {
    state = state.copyWith(
      tasks: [
        for (final task in state.tasks)
          if (task.id != id) task,
      ],
    );
    await _save(ref.read(studyBuddyRepositoryProvider).deleteTask(id));
  }

  void addNote(String title, String body) {
    final note = NoteItem(id: _id(), title: title, body: body);
    unawaited(saveNote(note));
  }

  Future<void> saveNote(NoteItem note) async {
    final exists = state.notes.any((item) => item.id == note.id);
    state = state.copyWith(
      notes: [
        for (final item in state.notes)
          if (item.id == note.id) note else item,
        if (!exists) note,
      ],
    );
    final repo = ref.read(studyBuddyRepositoryProvider);
    await _save(exists ? repo.updateNote(note) : repo.addNote(note));
  }

  Future<void> deleteNote(String id) async {
    state = state.copyWith(
      notes: [
        for (final note in state.notes)
          if (note.id != id) note,
      ],
    );
    await _save(ref.read(studyBuddyRepositoryProvider).deleteNote(id));
  }

  Future<NoteFolder?> saveNoteFolder(NoteFolder folder) async {
    if (_createsFolderCycle(folder)) return null;
    final exists = state.noteFolders.any((item) => item.id == folder.id);
    state = state.copyWith(
      noteFolders: [
        for (final item in state.noteFolders)
          if (item.id == folder.id) folder else item,
        if (!exists) folder,
      ],
    );
    final repo = ref.read(studyBuddyRepositoryProvider);
    await _save(
      exists ? repo.updateNoteFolder(folder) : repo.addNoteFolder(folder),
    );
    return folder;
  }

  Future<void> deleteNoteFolder(String id) async {
    final folderIds = _folderWithDescendants(id);
    final affectedNotes = state.notes.where(
      (note) => note.folderId != null && folderIds.contains(note.folderId),
    );
    final movedNotes = [
      for (final note in state.notes)
        if (note.folderId != null && folderIds.contains(note.folderId))
          note.copyWith(folderId: null, updatedAt: DateTime.now())
        else
          note,
    ];
    state = state.copyWith(
      notes: movedNotes,
      noteFolders: [
        for (final folder in state.noteFolders)
          if (!folderIds.contains(folder.id)) folder,
      ],
    );
    final repo = ref.read(studyBuddyRepositoryProvider);
    for (final note in affectedNotes) {
      await _save(
        repo.updateNote(
          note.copyWith(folderId: null, updatedAt: DateTime.now()),
        ),
      );
    }
    for (final folderId in folderIds) {
      await _save(repo.deleteNoteFolder(folderId));
    }
  }

  Set<String> _folderWithDescendants(String id) {
    final result = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in state.noteFolders) {
        if (folder.parentFolderId != null &&
            result.contains(folder.parentFolderId) &&
            result.add(folder.id)) {
          changed = true;
        }
      }
    }
    return result;
  }

  bool _createsFolderCycle(NoteFolder folder) {
    final parentId = folder.parentFolderId;
    if (parentId == null) return false;
    if (parentId == folder.id) return true;
    var current = state.noteFolders
        .where((item) => item.id == parentId)
        .firstOrNull;
    while (current != null) {
      if (current.parentFolderId == folder.id) return true;
      current = state.noteFolders
          .where((item) => item.id == current?.parentFolderId)
          .firstOrNull;
    }
    return false;
  }

  void addSubject(String name) {
    final subject = SubjectItem(id: _id(), name: name);
    unawaited(addSubjectItem(subject));
  }

  Future<SubjectItem> addSubjectItem(SubjectItem subject) async {
    state = state.copyWith(subjects: [...state.subjects, subject]);
    await _save(ref.read(studyBuddyRepositoryProvider).addSubject(subject));
    return subject;
  }

  Future<void> updateSubjectItem(SubjectItem subject) async {
    state = state.copyWith(
      subjects: [
        for (final item in state.subjects)
          if (item.id == subject.id) subject else item,
      ],
    );
    await _save(ref.read(studyBuddyRepositoryProvider).updateSubject(subject));
  }

  Future<void> deleteSubjectItem(String id) async {
    state = state.copyWith(
      subjects: [
        for (final subject in state.subjects)
          if (subject.id != id) subject,
      ],
    );
    await _save(ref.read(studyBuddyRepositoryProvider).deleteSubject(id));
  }

  void addExam(String subject, String dateLabel) {
    final exam = ExamOverview(
      id: _id(),
      title: subject,
      subject: subject,
      dateLabel: dateLabel,
    );
    unawaited(saveExam(exam));
  }

  Future<void> saveExam(ExamOverview exam) async {
    final exists = state.exams.any((item) => item.id == exam.id);
    state = state.copyWith(
      exams: [
        for (final item in state.exams)
          if (item.id == exam.id) exam else item,
        if (!exists) exam,
      ],
    );
    final repo = ref.read(studyBuddyRepositoryProvider);
    await _save(exists ? repo.updateExam(exam) : repo.addExam(exam));
  }

  Future<void> deleteExam(String id) async {
    state = state.copyWith(
      exams: [
        for (final exam in state.exams)
          if (exam.id != id) exam,
      ],
    );
    await _save(ref.read(studyBuddyRepositoryProvider).deleteExam(id));
  }

  Future<void> saveStudySession(StudySession session) async {
    final exists = state.studySessions.any((item) => item.id == session.id);
    state = state.copyWith(
      studySessions: [
        for (final item in state.studySessions)
          if (item.id == session.id) session else item,
        if (!exists) session,
      ],
    );
    final repo = ref.read(studyBuddyRepositoryProvider);
    await _save(
      exists ? repo.updateStudySession(session) : repo.addStudySession(session),
    );
  }

  Future<void> deleteStudySession(String id) async {
    state = state.copyWith(
      studySessions: [
        for (final item in state.studySessions)
          if (item.id != id) item,
      ],
    );
    await _save(ref.read(studyBuddyRepositoryProvider).deleteStudySession(id));
  }

  void addReminder(String title, String dateLabel) {
    final reminder = ReminderItem(
      id: _id(),
      title: title,
      dateLabel: dateLabel,
    );
    state = state.copyWith(reminders: [...state.reminders, reminder]);
    unawaited(
      _save(ref.read(studyBuddyRepositoryProvider).addReminder(reminder)),
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

  String newId() => _id();
}
