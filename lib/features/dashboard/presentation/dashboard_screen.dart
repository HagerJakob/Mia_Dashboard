import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_layout.dart';
import '../../../shared/models/navigation_item.dart';
import '../../../theme/app_colors.dart';
import '../../auth/presentation/account_screen.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../exams/presentation/exams_screen.dart';
import '../../notes/presentation/notes_screen.dart';
import '../../subjects/presentation/subjects_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
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
    StudyNavigationItem(label: 'Fächer', icon: Icons.auto_stories_rounded),
    StudyNavigationItem(label: 'Prüfungen', icon: Icons.school_rounded),
    StudyNavigationItem(label: 'Timer', icon: Icons.timer_rounded),
    StudyNavigationItem(label: 'Statistiken', icon: Icons.bar_chart_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyBuddyControllerProvider);
    final controller = ref.read(studyBuddyControllerProvider.notifier);
    final selectedIndex = state.selectedIndex;
    void openAccount() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));

    if (context.isCompact) {
      const mobileIndexes = [0, 1, 2, 3, 4];
      final mobileItems = [
        _items[0],
        _items[1],
        _items[2],
        _items[3],
        _items[4],
      ];
      final mobileIndex = mobileIndexes.contains(selectedIndex)
          ? mobileIndexes.indexOf(selectedIndex)
          : 0;

      return Scaffold(
        appBar: AppBar(
          title: const Text('StudyBuddy'),
          actions: [
            IconButton(
              tooltip: 'Konto',
              onPressed: openAccount,
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: _SelectedDestination(
            state: state.copyWith(selectedIndex: mobileIndex),
          ),
        ),
        bottomNavigationBar: StudyBottomNavigation(
          items: mobileItems,
          selectedIndex: mobileIndex,
          onSelected: (index) =>
              controller.selectDestination(mobileIndexes[index]),
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
                    onSettings: openAccount,
                  )
                : StudyNavigationRail(
                    items: _items.take(6).toList(),
                    selectedIndex: selectedIndex,
                    onSelected: controller.selectDestination,
                    onSettings: openAccount,
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
      1 => const CalendarScreen(),
      2 => const TasksScreen(),
      3 => const NotesScreen(),
      4 => const SubjectsScreen(),
      5 => const ExamsScreen(),
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
