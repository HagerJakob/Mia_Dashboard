import 'package:flutter/material.dart';

import '../../../../shared/widgets/study_card.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/dashboard_models.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Suchen',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.lilac,
          child: Text('M', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({required this.item, super.key});

  final KpiItem item;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.blush,
            child: Icon(item.icon, color: AppColors.mauve),
          ),
          const SizedBox(height: 18),
          Text(item.value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.mutedInk),
          ),
        ],
      ),
    );
  }
}

class TodayCard extends StatelessWidget {
  const TodayCard({required this.items, super.key});

  final List<TimedItem> items;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: _TitledSection(
        title: 'Heute',
        icon: Icons.wb_sunny_rounded,
        children: [
          for (final item in items)
            _LabeledRow(
              leading: item.time,
              title: item.title,
              icon: Icons.circle,
            ),
        ],
      ),
    );
  }
}

class TasksCard extends StatelessWidget {
  const TasksCard({required this.tasks, super.key});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: _TitledSection(
        title: 'Meine Aufgaben',
        icon: Icons.checklist_rounded,
        children: [
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    task.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: task.done ? AppColors.sage : AppColors.rose,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        color: task.done ? AppColors.mutedInk : AppColors.ink,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
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

class ExamCard extends StatelessWidget {
  const ExamCard({required this.exam, super.key});

  final ExamOverview exam;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Naechste Pruefung',
            icon: Icons.school_rounded,
          ),
          const SizedBox(height: 16),
          Text(exam.subject, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${exam.dateLabel} · ${exam.remainingLabel}',
            style: const TextStyle(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: exam.progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.lilac,
            color: AppColors.mauve,
          ),
          const SizedBox(height: 8),
          Text('Fortschritt ${(exam.progress * 100).round()} %'),
          const SizedBox(height: 16),
          for (final chapter in exam.chapters)
            _LabeledRow(
              leading: chapter.done ? 'erledigt' : 'offen',
              title: chapter.title,
              icon: chapter.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              iconColor: chapter.done ? AppColors.sage : AppColors.rose,
            ),
        ],
      ),
    );
  }
}

class FocusTimerCard extends StatelessWidget {
  const FocusTimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Focus Timer', icon: Icons.timer_rounded),
          const SizedBox(height: 20),
          Center(
            child: Container(
              height: 132,
              width: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blush,
                border: Border.all(color: AppColors.rose, width: 6),
              ),
              child: Text(
                '25:00',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class StudyHoursCard extends StatelessWidget {
  const StudyHoursCard({required this.hours, super.key});

  final List<StudyHour> hours;

  @override
  Widget build(BuildContext context) {
    final maxHours = hours
        .map((item) => item.hours)
        .reduce((a, b) => a > b ? a : b);

    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Lernzeit diese Woche',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in hours)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: item.hours / maxHours,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.lavender,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(item.day, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
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

class NotesCard extends StatelessWidget {
  const NotesCard({required this.notes, super.key});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: _TitledSection(
        title: 'Letzte Notizen',
        icon: Icons.edit_note_rounded,
        children: [
          for (final note in notes)
            _LabeledRow(
              leading: 'Notiz',
              title: note,
              icon: Icons.notes_rounded,
            ),
        ],
      ),
    );
  }
}

class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({required this.goal, super.key});

  final DailyGoal goal;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Tagesziel', icon: Icons.flag_rounded),
          const SizedBox(height: 18),
          Text(goal.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.mint,
            color: AppColors.sage,
          ),
          const SizedBox(height: 10),
          Text('${(goal.progress * 100).round()} % geschafft'),
        ],
      ),
    );
  }
}

class _TitledSection extends StatelessWidget {
  const _TitledSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, icon: icon),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mauve),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.leading,
    required this.title,
    required this.icon,
    this.iconColor = AppColors.mauve,
  });

  final String leading;
  final String title;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              leading,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
          ),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }
}
