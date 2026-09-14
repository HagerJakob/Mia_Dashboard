import 'package:flutter/material.dart';

import '../domain/dashboard_models.dart';

class DashboardMockRepository {
  const DashboardMockRepository();

  DashboardData loadDashboard() {
    return const DashboardData(
      kpis: [
        KpiItem('Lernstreak', '14 Tage', Icons.local_fire_department_rounded),
        KpiItem('Lernzeit diese Woche', '10,5 h', Icons.schedule_rounded),
        KpiItem('Aufgaben erledigt', '5 / 8', Icons.check_circle_rounded),
        KpiItem('Naechste Pruefung', 'noch 39 Tage', Icons.school_rounded),
      ],
      schedule: [
        TimedItem('09:00', 'Mathematik'),
        TimedItem('12:30', 'Mittagessen'),
        TimedItem('14:00', 'Lernen'),
        TimedItem('17:00', 'Sport'),
        TimedItem('20:00', 'Notizen'),
      ],
      tasks: [
        TaskItem('Mathe Mitschrift nachbearbeiten', true),
        TaskItem('Statistik Uebungsblatt 3', false),
        TaskItem('Englisch Vokabeln', false),
        TaskItem('BWL Zusammenfassung lesen', true),
        TaskItem('Zimmer aufraeumen', false),
      ],
      exam: ExamOverview(
        subject: 'Mathematik',
        dateLabel: '23. Oktober',
        remainingLabel: 'Noch 39 Tage',
        progress: 0.72,
        chapters: [
          ChapterProgress('Grundlagen', true),
          ChapterProgress('Ableitungen', true),
          ChapterProgress('Integrale', true),
          ChapterProgress('Anwendungen', false),
          ChapterProgress('Alte Klausuren', false),
        ],
      ),
      studyHours: [
        StudyHour('Mo', 1.5),
        StudyHour('Di', 2.0),
        StudyHour('Mi', 1.0),
        StudyHour('Do', 2.5),
        StudyHour('Fr', 1.5),
        StudyHour('Sa', 1.0),
        StudyHour('So', 1.0),
      ],
      notes: [
        'Integralregeln wiederholen',
        'Englisch: Unit 6 markieren',
        'BWL Beispiele fuer Zusammenfassung',
      ],
      dailyGoal: DailyGoal('3 von 4 Lernbloecken geschafft', 0.75),
    );
  }
}
