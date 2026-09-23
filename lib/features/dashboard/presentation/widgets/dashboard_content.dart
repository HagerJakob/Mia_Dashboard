import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/responsive_layout.dart';
import '../../../../shared/widgets/study_card.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/dashboard_models.dart';
import '../dashboard_controller.dart';
import 'add_entry_sheet.dart';
import 'dashboard_sections.dart';

class DashboardContent extends ConsumerWidget {
  const DashboardContent({
    required this.state,
    this.focusOnly = false,
    super.key,
  });

  final StudyBuddyState state;
  final bool focusOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = context.isCompact;
    final controller = ref.read(studyBuddyControllerProvider.notifier);
    final horizontalPadding = compact ? 18.0 : 28.0;

    if (focusOnly) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: FocusTimerCard(
          seconds: state.focusSeconds,
          isRunning: state.timerRunning,
          onToggle: controller.toggleTimer,
          onReset: controller.resetTimer,
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 18 : 24,
        horizontalPadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardTopBar(),
          const SizedBox(height: 24),
          Text(
            'Hallo Mia',
            style: compact
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Schön, dass du da bist. Dein neues Studium startet hier ganz frisch.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.mutedInk, height: 1.45),
          ),
          const SizedBox(height: 24),
          _ResponsiveGrid(
            minItemWidth: 190,
            spacing: 16,
            children: [
              KpiCard(
                item: KpiItem(
                  'Lernstreak',
                  '0 Tage',
                  Icons.local_fire_department_rounded,
                ),
              ),
              KpiCard(
                item: KpiItem(
                  'Lernzeit diese Woche',
                  '0 h',
                  Icons.schedule_rounded,
                ),
              ),
              KpiCard(
                item: KpiItem(
                  'Aufgaben erledigt',
                  '${state.tasks.where((task) => task.done).length} / ${state.tasks.length}',
                  Icons.check_circle_rounded,
                ),
              ),
              KpiCard(
                item: KpiItem(
                  'Nächste Prüfung',
                  state.exams.isEmpty
                      ? 'noch offen'
                      : state.exams.first.dateLabel,
                  Icons.school_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResponsiveGrid(
            minItemWidth: context.isExpanded ? 280 : 260,
            spacing: 18,
            children: [
              TodayCard(
                items: state.schedule,
                onAdd: () => showScheduleSheet(context, controller),
              ),
              TasksCard(
                tasks: state.tasks,
                onAdd: () => showTaskSheet(context, controller),
                onToggle: controller.toggleTask,
              ),
              ExamCard(
                exams: state.exams,
                onAdd: () => showExamSheet(context, controller),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResponsiveGrid(
            minItemWidth: context.isExpanded ? 260 : 240,
            spacing: 18,
            children: [
              FocusTimerCard(
                seconds: state.focusSeconds,
                isRunning: state.timerRunning,
                onToggle: controller.toggleTimer,
                onReset: controller.resetTimer,
              ),
              StudyHoursCard(hours: const []),
              NotesCard(
                notes: state.notes,
                onAdd: () => showNoteSheet(context, controller),
              ),
              DailyGoalCard(
                activeTasks: state.tasks.where((task) => task.done).length,
                totalTasks: state.tasks.length,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const StudyCard(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.mauve),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kleine Schritte, große Ergebnisse.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.minItemWidth,
    required this.spacing,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth).floor().clamp(
          1,
          children.length,
        );
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth.toDouble(), child: child),
          ],
        );
      },
    );
  }
}
