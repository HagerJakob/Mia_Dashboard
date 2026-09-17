import 'dart:convert';

import 'package:flutter/material.dart';

enum CalendarView { month, week, day, agenda }

enum CalendarSource {
  user,
  austrianHoliday,
  phSalzburg,
  academicPeriod,
  salzburgSchoolHolidays,
}

enum EventPriority { low, normal, important, veryImportant }

enum AcademicPeriodType {
  semester,
  lecturePeriod,
  semesterBreak,
  christmasBreak,
  easterBreak,
  summerBreak,
  lectureFree,
  enrollmentPeriod,
  examPeriod,
  phEvent,
  custom,
}

enum RecurrenceScope { one, following, all }

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.category = 'Termin',
    this.subjectId,
    this.description = '',
    this.location = '',
    this.onlineUrl = '',
    this.allDay = false,
    this.colorValue = 0xFFB56D8C,
    this.priority = EventPriority.normal,
    this.recurrenceRule,
    this.reminders = const [],
    this.practice = const {},
    this.metadata = const {},
    this.seriesId,
    this.occurrenceAt,
    this.cancelled = false,
    this.source = CalendarSource.user,
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String category;
  final String? subjectId;
  final String description;
  final String location;
  final String onlineUrl;
  final bool allDay;
  final int colorValue;
  final EventPriority priority;
  final String? recurrenceRule;
  final List<int> reminders;
  final Map<String, String> practice;
  final Map<String, String> metadata;
  final String? seriesId;
  final DateTime? occurrenceAt;
  final bool cancelled;
  final CalendarSource source;

  Color get color => Color(colorValue);
  Duration get duration => endAt.difference(startAt);

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? category,
    Object? subjectId = _unset,
    String? description,
    String? location,
    String? onlineUrl,
    bool? allDay,
    int? colorValue,
    EventPriority? priority,
    Object? recurrenceRule = _unset,
    List<int>? reminders,
    Map<String, String>? practice,
    Map<String, String>? metadata,
    Object? seriesId = _unset,
    Object? occurrenceAt = _unset,
    bool? cancelled,
    CalendarSource? source,
  }) => CalendarEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    category: category ?? this.category,
    subjectId: identical(subjectId, _unset)
        ? this.subjectId
        : subjectId as String?,
    description: description ?? this.description,
    location: location ?? this.location,
    onlineUrl: onlineUrl ?? this.onlineUrl,
    allDay: allDay ?? this.allDay,
    colorValue: colorValue ?? this.colorValue,
    priority: priority ?? this.priority,
    recurrenceRule: identical(recurrenceRule, _unset)
        ? this.recurrenceRule
        : recurrenceRule as String?,
    reminders: reminders ?? this.reminders,
    practice: practice ?? this.practice,
    metadata: metadata ?? this.metadata,
    seriesId: identical(seriesId, _unset) ? this.seriesId : seriesId as String?,
    occurrenceAt: identical(occurrenceAt, _unset)
        ? this.occurrenceAt
        : occurrenceAt as DateTime?,
    cancelled: cancelled ?? this.cancelled,
    source: source ?? this.source,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'start_at': startAt.toIso8601String(),
    'end_at': endAt.toIso8601String(),
    'category': category,
    'subject_id': subjectId,
    'description': description,
    'location': location,
    'online_url': onlineUrl,
    'all_day': allDay,
    'color_value': colorValue,
    'priority': priority.name,
    'recurrence_rule': recurrenceRule,
    'reminders': reminders,
    'practice': practice,
    'metadata': metadata,
    'series_id': seriesId,
    'occurrence_at': occurrenceAt?.toIso8601String(),
    'cancelled': cancelled,
    'source': source.name,
  };

  String encode() => jsonEncode(toJson());

  factory CalendarEvent.decode(String id, String json) =>
      CalendarEvent.fromJson(id, jsonDecode(json) as Map<String, dynamic>);

  factory CalendarEvent.fromJson(String id, Map<String, dynamic> data) =>
      CalendarEvent(
        id: id,
        title: data['title'] as String,
        startAt: DateTime.parse(data['start_at'] as String),
        endAt: DateTime.parse(data['end_at'] as String),
        category: data['category'] as String? ?? 'Termin',
        subjectId: data['subject_id'] as String?,
        description: data['description'] as String? ?? '',
        location: data['location'] as String? ?? '',
        onlineUrl: data['online_url'] as String? ?? '',
        allDay: data['all_day'] as bool? ?? false,
        colorValue: data['color_value'] as int? ?? 0xFFB56D8C,
        priority: EventPriority.values.byName(
          data['priority'] as String? ?? 'normal',
        ),
        recurrenceRule: data['recurrence_rule'] as String?,
        reminders: (data['reminders'] as List<dynamic>? ?? []).cast<int>(),
        practice: (data['practice'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        metadata: (data['metadata'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        seriesId: data['series_id'] as String?,
        occurrenceAt: data['occurrence_at'] == null
            ? null
            : DateTime.parse(data['occurrence_at'] as String),
        cancelled: data['cancelled'] as bool? ?? false,
        source: CalendarSource.values.byName(
          data['source'] as String? ?? 'user',
        ),
      );
}

const _unset = Object();

class CalendarCategory {
  const CalendarCategory(this.id, this.name, this.colorValue);
  final String id;
  final String name;
  final int colorValue;
  Color get color => Color(colorValue);
}

class CalendarOccurrence {
  const CalendarOccurrence(
    this.event,
    this.startAt,
    this.endAt, {
    this.originalStart,
  });
  final CalendarEvent event;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime? originalStart;
  bool get isRecurring => originalStart != null;
}

class AcademicPeriod {
  const AcademicPeriod({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.institution,
    required this.studyProgram,
    this.description = '',
    this.source = '',
    this.sourceUrl,
    this.confirmed = false,
    this.lastVerifiedAt,
  });
  final String id, title, description, institution, studyProgram, source;
  final DateTime startDate, endDate;
  final AcademicPeriodType type;
  final String? sourceUrl;
  final bool confirmed;
  final DateTime? lastVerifiedAt;
}
