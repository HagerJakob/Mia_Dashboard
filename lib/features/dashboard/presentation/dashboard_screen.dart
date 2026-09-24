import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_layout.dart';
import '../../../shared/design_system/study_assets.dart';
import '../../../shared/design_system/study_svg_asset.dart';
import '../../../shared/models/navigation_item.dart';
import '../../../theme/app_colors.dart';
import '../../auth/presentation/account_screen.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../exams/presentation/exams_screen.dart';
import '../../notes/presentation/notes_screen.dart';
import '../../statistics/presentation/statistics_screen.dart';
import '../../subjects/presentation/subjects_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../timer/presentation/timer_screen.dart';
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
      const mobileIndexes = [0, 1, 2, 6, -1];
      final mobileItems = [
        const StudyNavigationItem(label: 'Home', icon: Icons.grid_view_rounded),
        _items[1],
        _items[2],
        const StudyNavigationItem(label: 'Lernen', icon: Icons.timer_rounded),
        const StudyNavigationItem(
          label: 'Mehr',
          icon: Icons.more_horiz_rounded,
        ),
      ];
      final mobileIndex = mobileIndexes.contains(selectedIndex)
          ? mobileIndexes.indexOf(selectedIndex)
          : 4;
      final secondaryDestination =
          selectedIndex != -1 && !mobileIndexes.contains(selectedIndex);

      return Scaffold(
        appBar: AppBar(
          leading: secondaryDestination
              ? IconButton(
                  tooltip: 'Zurück zu Mehr',
                  onPressed: () => controller.selectDestination(-1),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudySvgAsset(
                asset: StudyAssets.appIcon,
                width: 30,
                height: 30,
                semanticLabel: 'StudyBuddy Logo',
              ),
              SizedBox(width: 10),
              Text('StudyBuddy'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Konto',
              onPressed: openAccount,
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: selectedIndex == -1
              ? _MoreDestination(
                  selectedIndex: selectedIndex,
                  onSelected: controller.selectDestination,
                  onSettings: openAccount,
                )
              : _SelectedDestination(state: state),
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
                    items: _items,
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
      6 => const TimerScreen(),
      7 => const StatisticsScreen(),
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

class _MoreDestination extends StatelessWidget {
  const _MoreDestination({
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final groups = [
      (
        'Studium',
        [
          (3, 'Notizen', Icons.edit_note_rounded),
          (4, 'Fächer', Icons.auto_stories_rounded),
          (5, 'Prüfungen', Icons.school_rounded),
        ],
      ),
      ('Auswertung', [(7, 'Statistiken', Icons.bar_chart_rounded)]),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
      children: [
        Text('Mehr', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Alle StudyBuddy-Bereiche bleiben auch am Smartphone erreichbar.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.mutedInk),
        ),
        const SizedBox(height: 20),
        for (final group in groups) ...[
          Text(group.$1, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final item in group.$2)
            Card(
              child: ListTile(
                selected: selectedIndex == item.$1,
                leading: Icon(item.$3, color: AppColors.mauve),
                title: Text(item.$2),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onSelected(item.$1),
              ),
            ),
          const SizedBox(height: 18),
        ],
        Text('App', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_rounded, color: AppColors.mauve),
            title: const Text('Einstellungen'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSettings,
          ),
        ),
      ],
    );
  }
}
