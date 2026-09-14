import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_layout.dart';
import '../../../../shared/widgets/study_card.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/dashboard_models.dart';
import 'dashboard_sections.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({required this.data, super.key});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final horizontalPadding = compact ? 18.0 : 28.0;

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
          const SizedBox(height: 26),
          Text(
            'Hallo Mia ❤️',
            style: compact
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Schoen, dass du da bist! Heute ist ein guter Tag, um an deinen Zielen zu arbeiten.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.mutedInk, height: 1.45),
          ),
          const SizedBox(height: 26),
          _ResponsiveGrid(
            minItemWidth: 190,
            spacing: 16,
            children: [for (final kpi in data.kpis) KpiCard(item: kpi)],
          ),
          const SizedBox(height: 18),
          _ResponsiveGrid(
            minItemWidth: context.isExpanded ? 280 : 260,
            spacing: 18,
            children: [
              TodayCard(items: data.schedule),
              TasksCard(tasks: data.tasks),
              ExamCard(exam: data.exam),
            ],
          ),
          const SizedBox(height: 18),
          _ResponsiveGrid(
            minItemWidth: context.isExpanded ? 260 : 240,
            spacing: 18,
            children: [
              const FocusTimerCard(),
              StudyHoursCard(hours: data.studyHours),
              NotesCard(notes: data.notes),
              DailyGoalCard(goal: data.dailyGoal),
            ],
          ),
          const SizedBox(height: 18),
          const StudyCard(
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.mauve),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kleine Schritte, grosse Ergebnisse. ❤️',
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
