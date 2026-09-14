import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_layout.dart';
import '../../../shared/models/navigation_item.dart';
import '../../../theme/app_colors.dart';
import 'dashboard_controller.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_navigation.dart';

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
    final data = ref.watch(dashboardDataProvider);

    if (context.isCompact) {
      return Scaffold(
        body: SafeArea(child: DashboardContent(data: data)),
        bottomNavigationBar: StudyBottomNavigation(
          items: _items.take(4).toList(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            context.isExpanded
                ? StudySidebar(items: _items)
                : StudyNavigationRail(items: _items.take(6).toList()),
            Expanded(child: DashboardContent(data: data)),
          ],
        ),
      ),
    );
  }
}
