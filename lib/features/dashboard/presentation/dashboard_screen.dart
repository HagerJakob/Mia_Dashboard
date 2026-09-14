import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_layout.dart';
import '../../../shared/models/navigation_item.dart';
import '../../../theme/app_colors.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';
import 'widgets/add_entry_sheet.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_navigation.dart';
import 'widgets/empty_feature_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _items = [
    StudyNavigationItem(label: 'Dashboard', icon: Icons.grid_view_rounded),
    StudyNavigationItem(label: 'Kalender', icon: Icons.calendar_month_rounded),
    StudyNavigationItem(label: 'Aufgaben', icon: Icons.checklist_rounded),
    StudyNavigationItem(label: 'Notizen', icon: Icons.edit_note_rounded),
    StudyNavigationItem(label: 'Faecher', icon: Icons.auto_stories_rounded),
    StudyNavigationItem(label: 'Pruefungen', icon: Icons.school_rounded),
    StudyNavigationItem(label: 'Timer', icon: Icons.timer_rounded),
    StudyNavigationItem(label: 'Statistiken', icon: Icons.bar_chart_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyBuddyControllerProvider);
    final controller = ref.read(studyBuddyControllerProvider.notifier);
    final selectedIndex = state.selectedIndex;

    if (context.isCompact) {
      final mobileItems = _items.take(4).toList();
      final mobileIndex = selectedIndex.clamp(0, mobileItems.length - 1);

      return Scaffold(
        body: SafeArea(
          child: _SelectedDestination(
            state: state.copyWith(selectedIndex: mobileIndex),
          ),
        ),
        bottomNavigationBar: StudyBottomNavigation(
          items: mobileItems,
          selectedIndex: mobileIndex,
          onSelected: controller.selectDestination,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            context.isExpanded
                ? StudySidebar(
                    items: _items,
                    selectedIndex: selectedIndex,
                    onSelected: controller.selectDestination,
                  )
                : StudyNavigationRail(
                    items: _items.take(6).toList(),
                    selectedIndex: selectedIndex,
                    onSelected: controller.selectDestination,
                  ),
            Expanded(child: _SelectedDestination(state: state)),
          ],
        ),
      ),
    );
  }
}

class _SelectedDestination extends ConsumerWidget {
  const _SelectedDestination({required this.state});

  final StudyBuddyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studyBuddyControllerProvider.notifier);

    return switch (state.selectedIndex) {
      0 => DashboardContent(state: state),
      1 => EmptyFeatureScreen(
        title: 'Kalender',
        message: 'Dein Stundenplan und deine Termine starten leer.',
        icon: Icons.calendar_month_rounded,
        actionLabel: 'Termin eintragen',
        children: [
          for (final item in state.schedule)
            ListTile(
              leading: Text(item.time),
              title: Text(item.title),
              contentPadding: EdgeInsets.zero,
            ),
        ],
        onAction: () => showScheduleSheet(context, controller),
      ),
      2 => EmptyFeatureScreen(
        title: 'Aufgaben',
        message: 'Noch keine Aufgaben. Mia kann hier alles selbst anlegen.',
        icon: Icons.checklist_rounded,
        actionLabel: 'Aufgabe erstellen',
        children: [
          for (final task in state.tasks)
            CheckboxListTile(
              value: task.done,
              onChanged: (_) => controller.toggleTask(task.id),
              title: Text(task.title),
              contentPadding: EdgeInsets.zero,
            ),
        ],
        onAction: () => showTaskSheet(context, controller),
      ),
      3 => EmptyFeatureScreen(
        title: 'Notizen',
        message: 'Noch keine Notizen. Alles kann frisch aufgebaut werden.',
        icon: Icons.edit_note_rounded,
        actionLabel: 'Notiz schreiben',
        children: [
          for (final note in state.notes)
            ListTile(
              leading: const Icon(Icons.notes_rounded),
              title: Text(note.title),
              subtitle: note.body.isEmpty ? null : Text(note.body),
              contentPadding: EdgeInsets.zero,
            ),
        ],
        onAction: () => showNoteSheet(context, controller),
      ),
      4 => EmptyFeatureScreen(
        title: 'Faecher',
        message: 'Lege zuerst die Faecher fuer das neue Studium an.',
        icon: Icons.auto_stories_rounded,
        actionLabel: 'Fach anlegen',
        children: [
          for (final subject in state.subjects)
            ListTile(
              leading: CircleAvatar(backgroundColor: subject.color),
              title: Text(subject.name),
              contentPadding: EdgeInsets.zero,
            ),
        ],
        onAction: () => showSubjectSheet(context, controller),
      ),
      5 => EmptyFeatureScreen(
        title: 'Pruefungen',
        message: 'Pruefungen und Deadlines werden hier gesammelt.',
        icon: Icons.school_rounded,
        actionLabel: 'Pruefung eintragen',
        children: [
          for (final exam in state.exams)
            ListTile(
              leading: const Icon(Icons.school_rounded),
              title: Text(exam.subject),
              subtitle: Text(exam.dateLabel),
              contentPadding: EdgeInsets.zero,
            ),
        ],
        onAction: () => showExamSheet(context, controller),
      ),
      6 => DashboardContent(state: state, focusOnly: true),
      _ => EmptyFeatureScreen(
        title: 'Statistiken',
        message: 'Statistiken erscheinen, sobald Lernzeiten vorhanden sind.',
        icon: Icons.bar_chart_rounded,
        actionLabel: 'Erinnerung anlegen',
        children: [
          for (final reminder in state.reminders)
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: Text(reminder.title),
              subtitle: Text(reminder.dateLabel),
              contentPadding: EdgeInsets.zero,
            ),
        ],
        onAction: () => showReminderSheet(context, controller),
      ),
    };
  }
}
