import 'dart:convert';

import 'package:flutter/material.dart';

class StudyBuddyState {
  const StudyBuddyState({
    this.selectedIndex = 0,
    this.schedule = const [],
    this.tasks = const [],
    this.notes = const [],
    this.noteFolders = const [],
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
  final List<NoteFolder> noteFolders;
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
    List<NoteFolder>? noteFolders,
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
      noteFolders: noteFolders ?? this.noteFolders,
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

enum TaskStatus { open, inProgress, completed, paused }

enum TaskPriority { none, low, normal, high, urgent }

enum ExamStatus {
  planned,
  preparing,
  today,
  written,
  resultPending,
  passed,
  failed,
  cancelled,
}

enum ExamType {
  written,
  oral,
  practical,
  presentation,
  assignment,
  portfolio,
  colloquium,
  test,
  courseExam,
  moduleExam,
  schoolPractice,
  other,
}

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
    this.dueAt,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final int sortOrder;
  final DateTime? dueAt;

  TaskSubtask copyWith({bool? isCompleted}) => TaskSubtask(
    id: id,
    title: title,
    isCompleted: isCompleted ?? this.isCompleted,
    sortOrder: sortOrder,
    dueAt: dueAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted,
    'sort_order': sortOrder,
    if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
  };

  factory TaskSubtask.fromJson(Map<String, dynamic> data) => TaskSubtask(
    id: data['id'] as String? ?? '',
    title: data['title'] as String? ?? '',
    isCompleted: data['is_completed'] as bool? ?? false,
    sortOrder: data['sort_order'] as int? ?? 0,
    dueAt: data['due_at'] is String
        ? DateTime.tryParse(data['due_at'] as String)
        : null,
  );
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.open,
    this.priority = TaskPriority.normal,
    this.startAt,
    this.dueAt,
    this.completedAt,
    this.subjectId,
    this.category = 'Sonstiges',
    this.estimatedMinutes,
    this.tags = const [],
    this.subtasks = const [],
    this.recurrenceRule,
    this.recurrenceEnd,
    this.recurrenceCount,
    this.reminders = const [],
    this.linkedScheduleId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? startAt;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String? subjectId;
  final String category;
  final int? estimatedMinutes;
  final List<String> tags;
  final List<TaskSubtask> subtasks;
  final String? recurrenceRule;
  final DateTime? recurrenceEnd;
  final int? recurrenceCount;
  final List<int> reminders;
  final String? linkedScheduleId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get done => status == TaskStatus.completed;
  double get progress =>
      subtasks.isEmpty ? (done ? 1 : 0) : completedSubtasks / subtasks.length;
  int get completedSubtasks =>
      subtasks.where((subtask) => subtask.isCompleted).length;
  bool get isOverdue =>
      dueAt != null && !done && dueAt!.isBefore(DateTime.now());

  TaskItem copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? startAt,
    DateTime? dueAt,
    Object? completedAt = _unset,
    Object? subjectId = _unset,
    String? category,
    Object? estimatedMinutes = _unset,
    List<String>? tags,
    List<TaskSubtask>? subtasks,
    Object? recurrenceRule = _unset,
    Object? recurrenceEnd = _unset,
    Object? recurrenceCount = _unset,
    List<int>? reminders,
    Object? linkedScheduleId = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaskItem(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    startAt: startAt ?? this.startAt,
    dueAt: dueAt ?? this.dueAt,
    completedAt: completedAt == _unset
        ? this.completedAt
        : completedAt as DateTime?,
    subjectId: subjectId == _unset ? this.subjectId : subjectId as String?,
    category: category ?? this.category,
    estimatedMinutes: estimatedMinutes == _unset
        ? this.estimatedMinutes
        : estimatedMinutes as int?,
    tags: tags ?? this.tags,
    subtasks: subtasks ?? this.subtasks,
    recurrenceRule: recurrenceRule == _unset
        ? this.recurrenceRule
        : recurrenceRule as String?,
    recurrenceEnd: recurrenceEnd == _unset
        ? this.recurrenceEnd
        : recurrenceEnd as DateTime?,
    recurrenceCount: recurrenceCount == _unset
        ? this.recurrenceCount
        : recurrenceCount as int?,
    reminders: reminders ?? this.reminders,
    linkedScheduleId: linkedScheduleId == _unset
        ? this.linkedScheduleId
        : linkedScheduleId as String?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'description': description,
    'status': status.name,
    'done': done,
    'priority': priority.name,
    if (startAt != null) 'start_at': startAt!.toIso8601String(),
    if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    if (subjectId != null) 'subject_id': subjectId,
    'category': category,
    if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
    'tags': tags,
    'subtasks': [for (final subtask in subtasks) subtask.toJson()],
    if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
    if (recurrenceEnd != null)
      'recurrence_end': recurrenceEnd!.toIso8601String(),
    if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
    'reminders': reminders,
    if (linkedScheduleId != null) 'linked_schedule_id': linkedScheduleId,
  };

  String encode() => jsonEncode(toJson());

  factory TaskItem.fromJson(
    String id,
    Map<String, dynamic> data, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final done = data['done'] as bool? ?? false;
    return TaskItem(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: TaskStatus.values.byName(
        data['status'] as String? ?? (done ? 'completed' : 'open'),
      ),
      priority: TaskPriority.values.byName(
        data['priority'] as String? ?? 'normal',
      ),
      startAt: _date(data['start_at']),
      dueAt: _date(data['due_at']),
      completedAt: _date(data['completed_at']),
      subjectId: data['subject_id'] as String?,
      category: data['category'] as String? ?? 'Sonstiges',
      estimatedMinutes: data['estimated_minutes'] as int?,
      tags: [for (final tag in data['tags'] as List? ?? const []) '$tag'],
      subtasks: [
        for (final subtask in data['subtasks'] as List? ?? const [])
          if (subtask is Map<String, dynamic>) TaskSubtask.fromJson(subtask),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      recurrenceRule: data['recurrence_rule'] as String?,
      recurrenceEnd: _date(data['recurrence_end']),
      recurrenceCount: data['recurrence_count'] as int?,
      reminders: [
        for (final reminder in data['reminders'] as List? ?? const [])
          if (reminder is int) reminder,
      ],
      linkedScheduleId: data['linked_schedule_id'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory TaskItem.decode(
    String id,
    String json, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaskItem.fromJson(
    id,
    jsonDecode(json) as Map<String, dynamic>,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  return values.where((item) => item.name == value).firstOrNull ?? fallback;
}

String _examDateLabel(DateTime? value) {
  if (value == null) return '';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

const _unset = Object();

enum NoteType { quick, long, checklist }

class NotePage {
  const NotePage({
    required this.id,
    required this.content,
    this.title = '',
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotePage copyWith({
    String? title,
    String? content,
    int? sortOrder,
    DateTime? updatedAt,
  }) => NotePage(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'sort_order': sortOrder,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  factory NotePage.fromJson(Map<String, dynamic> data) => NotePage(
    id: data['id'] as String? ?? '',
    title: data['title'] as String? ?? '',
    content: data['content'] as String? ?? '',
    sortOrder: data['sort_order'] as int? ?? 0,
    createdAt: _date(data['created_at']),
    updatedAt: _date(data['updated_at']),
  );
}

class NoteFolder {
  const NoteFolder({
    required this.id,
    required this.name,
    this.parentFolderId,
    this.subjectId,
    this.sortOrder = 0,
    this.colorValue = 0xFFB56D8C,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? parentFolderId;
  final String? subjectId;
  final int sortOrder;
  final int colorValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NoteFolder copyWith({
    String? name,
    Object? parentFolderId = _unset,
    Object? subjectId = _unset,
    int? sortOrder,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteFolder(
    id: id,
    name: name ?? this.name,
    parentFolderId: parentFolderId == _unset
        ? this.parentFolderId
        : parentFolderId as String?,
    subjectId: subjectId == _unset ? this.subjectId : subjectId as String?,
    sortOrder: sortOrder ?? this.sortOrder,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    if (parentFolderId != null) 'parent_folder_id': parentFolderId,
    if (subjectId != null) 'subject_id': subjectId,
    'sort_order': sortOrder,
    'color_value': colorValue,
  };

  String encode() => jsonEncode(toJson());

  factory NoteFolder.fromJson(
    String id,
    Map<String, dynamic> data, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteFolder(
    id: id,
    name: data['name'] as String? ?? '',
    parentFolderId: data['parent_folder_id'] as String?,
    subjectId: data['subject_id'] as String?,
    sortOrder: data['sort_order'] as int? ?? 0,
    colorValue: data['color_value'] as int? ?? 0xFFB56D8C,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory NoteFolder.decode(
    String id,
    String json, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteFolder.fromJson(
    id,
    jsonDecode(json) as Map<String, dynamic>,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    this.body = '',
    this.type = NoteType.quick,
    this.folderId,
    this.subjectId,
    this.tags = const [],
    this.isFavorite = false,
    this.isPinned = false,
    this.pages = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final NoteType type;
  final String? folderId;
  final String? subjectId;
  final List<String> tags;
  final bool isFavorite;
  final bool isPinned;
  final List<NotePage> pages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get preview {
    final text = type == NoteType.long && pages.isNotEmpty
        ? pages.map((page) => page.content).join(' ')
        : body;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  NoteItem copyWith({
    String? title,
    String? body,
    NoteType? type,
    Object? folderId = _unset,
    Object? subjectId = _unset,
    List<String>? tags,
    bool? isFavorite,
    bool? isPinned,
    List<NotePage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteItem(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    type: type ?? this.type,
    folderId: folderId == _unset ? this.folderId : folderId as String?,
    subjectId: subjectId == _unset ? this.subjectId : subjectId as String?,
    tags: tags ?? this.tags,
    isFavorite: isFavorite ?? this.isFavorite,
    isPinned: isPinned ?? this.isPinned,
    pages: pages ?? this.pages,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'body': body,
    'note_type': type.name,
    if (folderId != null) 'folder_id': folderId,
    if (subjectId != null) 'subject_id': subjectId,
    'tags': tags,
    'is_favorite': isFavorite,
    'is_pinned': isPinned,
    'pages': [for (final page in pages) page.toJson()],
  };

  String encode() => jsonEncode(toJson());

  factory NoteItem.fromJson(
    String id,
    Map<String, dynamic> data, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteItem(
    id: id,
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    type: _enumByName(NoteType.values, data['note_type'], NoteType.quick),
    folderId: data['folder_id'] as String?,
    subjectId: data['subject_id'] as String?,
    tags: [for (final tag in data['tags'] as List? ?? const []) '$tag'],
    isFavorite: data['is_favorite'] as bool? ?? false,
    isPinned: data['is_pinned'] as bool? ?? false,
    pages: [
      for (final page in data['pages'] as List? ?? const [])
        if (page is Map<String, dynamic>) NotePage.fromJson(page),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory NoteItem.decode(
    String id,
    String json, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteItem.fromJson(
    id,
    jsonDecode(json) as Map<String, dynamic>,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
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
    String? title,
    this.subjectId,
    this.examType = ExamType.written,
    this.startAt,
    this.endAt,
    this.location = '',
    this.room = '',
    this.onlineUrl = '',
    this.examiner = '',
    this.description = '',
    this.status = ExamStatus.planned,
    this.priority = TaskPriority.normal,
    this.preparationStartAt,
    this.notes = '',
    this.result = '',
    this.grade,
    this.pointsAchieved,
    this.pointsMaximum,
    this.passed,
    this.progress = 0,
    this.chapters = const [],
    this.reminders = const [],
    this.createdAt,
    this.updatedAt,
  }) : title = title ?? subject;

  final String id;
  final String title;
  final String subject;
  final String dateLabel;
  final String? subjectId;
  final ExamType examType;
  final DateTime? startAt;
  final DateTime? endAt;
  final String location;
  final String room;
  final String onlineUrl;
  final String examiner;
  final String description;
  final ExamStatus status;
  final TaskPriority priority;
  final DateTime? preparationStartAt;
  final String notes;
  final String result;
  final double? grade;
  final double? pointsAchieved;
  final double? pointsMaximum;
  final bool? passed;
  final double progress;
  final List<ChapterProgress> chapters;
  final List<int> reminders;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get computedProgress {
    if (chapters.isEmpty) return progress.clamp(0, 1);
    return chapters.where((chapter) => chapter.done).length / chapters.length;
  }

  bool get isCompleted =>
      status == ExamStatus.passed ||
      status == ExamStatus.failed ||
      status == ExamStatus.cancelled;

  int? get daysUntil {
    final date = startAt;
    if (date == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  ExamStatus get effectiveStatus {
    if (isCompleted || status == ExamStatus.resultPending) return status;
    final days = daysUntil;
    if (days == null) return status;
    if (days == 0) return ExamStatus.today;
    if (days < 0) return ExamStatus.written;
    if (preparationStartAt != null &&
        !DateTime.now().isBefore(preparationStartAt!)) {
      return ExamStatus.preparing;
    }
    if (computedProgress > 0) return ExamStatus.preparing;
    return status;
  }

  ExamOverview copyWith({
    String? id,
    String? title,
    String? subject,
    String? dateLabel,
    Object? subjectId = _unset,
    ExamType? examType,
    Object? startAt = _unset,
    Object? endAt = _unset,
    String? location,
    String? room,
    String? onlineUrl,
    String? examiner,
    String? description,
    ExamStatus? status,
    TaskPriority? priority,
    Object? preparationStartAt = _unset,
    String? notes,
    String? result,
    Object? grade = _unset,
    Object? pointsAchieved = _unset,
    Object? pointsMaximum = _unset,
    Object? passed = _unset,
    double? progress,
    List<ChapterProgress>? chapters,
    List<int>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExamOverview(
    id: id ?? this.id,
    title: title ?? this.title,
    subject: subject ?? this.subject,
    dateLabel: dateLabel ?? this.dateLabel,
    subjectId: subjectId == _unset ? this.subjectId : subjectId as String?,
    examType: examType ?? this.examType,
    startAt: startAt == _unset ? this.startAt : startAt as DateTime?,
    endAt: endAt == _unset ? this.endAt : endAt as DateTime?,
    location: location ?? this.location,
    room: room ?? this.room,
    onlineUrl: onlineUrl ?? this.onlineUrl,
    examiner: examiner ?? this.examiner,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    preparationStartAt: preparationStartAt == _unset
        ? this.preparationStartAt
        : preparationStartAt as DateTime?,
    notes: notes ?? this.notes,
    result: result ?? this.result,
    grade: grade == _unset ? this.grade : (grade as num?)?.toDouble(),
    pointsAchieved: pointsAchieved == _unset
        ? this.pointsAchieved
        : (pointsAchieved as num?)?.toDouble(),
    pointsMaximum: pointsMaximum == _unset
        ? this.pointsMaximum
        : (pointsMaximum as num?)?.toDouble(),
    passed: passed == _unset ? this.passed : passed as bool?,
    progress: progress ?? this.progress,
    chapters: chapters ?? this.chapters,
    reminders: reminders ?? this.reminders,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'subject': subject,
    'date_label': dateLabel,
    if (subjectId != null) 'subject_id': subjectId,
    'exam_type': examType.name,
    if (startAt != null) 'start_at': startAt!.toIso8601String(),
    if (endAt != null) 'end_at': endAt!.toIso8601String(),
    'location': location,
    'room': room,
    'online_url': onlineUrl,
    'examiner': examiner,
    'description': description,
    'status': status.name,
    'priority': priority.name,
    if (preparationStartAt != null)
      'preparation_start_at': preparationStartAt!.toIso8601String(),
    'topics': [for (final chapter in chapters) chapter.toJson()],
    'notes': notes,
    'reminders': reminders,
    'progress': progress,
    'result': result,
    if (grade != null) 'grade': grade,
    if (pointsAchieved != null) 'points_achieved': pointsAchieved,
    if (pointsMaximum != null) 'points_maximum': pointsMaximum,
    if (passed != null) 'passed': passed,
  };

  String encode() => jsonEncode(toJson());

  factory ExamOverview.fromJson(
    String id,
    Map<String, dynamic> data, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final startAt = _date(data['start_at']);
    final subject =
        data['subject'] as String? ?? data['title'] as String? ?? '';
    return ExamOverview(
      id: id,
      title: data['title'] as String? ?? subject,
      subject: subject,
      dateLabel: data['date_label'] as String? ?? _examDateLabel(startAt),
      subjectId: data['subject_id'] as String?,
      examType: _enumByName(
        ExamType.values,
        data['exam_type'],
        ExamType.written,
      ),
      startAt: startAt,
      endAt: _date(data['end_at']),
      location: data['location'] as String? ?? '',
      room: data['room'] as String? ?? '',
      onlineUrl: data['online_url'] as String? ?? '',
      examiner: data['examiner'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: _enumByName(
        ExamStatus.values,
        data['status'],
        ExamStatus.planned,
      ),
      priority: _enumByName(
        TaskPriority.values,
        data['priority'],
        TaskPriority.normal,
      ),
      preparationStartAt: _date(data['preparation_start_at']),
      chapters: [
        for (final topic in data['topics'] as List? ?? const [])
          if (topic is Map<String, dynamic>) ChapterProgress.fromJson(topic),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      notes: data['notes'] as String? ?? '',
      reminders: [
        for (final reminder in data['reminders'] as List? ?? const [])
          if (reminder is int) reminder,
      ],
      progress: ((data['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      result: data['result'] as String? ?? '',
      grade: (data['grade'] as num?)?.toDouble(),
      pointsAchieved: (data['points_achieved'] as num?)?.toDouble(),
      pointsMaximum: (data['points_maximum'] as num?)?.toDouble(),
      passed: data['passed'] as bool?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ExamOverview.decode(
    String id,
    String json, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExamOverview.fromJson(
    id,
    jsonDecode(json) as Map<String, dynamic>,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class ChapterProgress {
  const ChapterProgress(
    this.title,
    this.done, {
    String? id,
    this.sortOrder = 0,
    this.confidence = 'unknown',
  }) : id = id ?? title;

  final String id;
  final String title;
  final bool done;
  final int sortOrder;
  final String confidence;

  ChapterProgress copyWith({bool? done, String? confidence}) => ChapterProgress(
    title,
    done ?? this.done,
    id: id,
    sortOrder: sortOrder,
    confidence: confidence ?? this.confidence,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'is_completed': done,
    'sort_order': sortOrder,
    'confidence': confidence,
  };

  factory ChapterProgress.fromJson(Map<String, dynamic> data) =>
      ChapterProgress(
        data['title'] as String? ?? '',
        data['is_completed'] as bool? ?? data['done'] as bool? ?? false,
        id: data['id'] as String?,
        sortOrder: data['sort_order'] as int? ?? 0,
        confidence: data['confidence'] as String? ?? 'unknown',
      );
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
