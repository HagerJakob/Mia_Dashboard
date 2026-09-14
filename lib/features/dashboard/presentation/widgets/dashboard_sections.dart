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
  const TodayCard({required this.items, required this.onAdd, super.key});

  final List<TimedItem> items;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: _TitledSection(
        title: 'Heute',
        icon: Icons.wb_sunny_rounded,
        actionLabel: 'Termin',
        onAction: onAdd,
        emptyText: 'Heute ist noch nichts eingetragen.',
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
  const TasksCard({
    required this.tasks,
    required this.onAdd,
    required this.onToggle,
    super.key,
  });

  final List<TaskItem> tasks;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: _TitledSection(
        title: 'Meine Aufgaben',
        icon: Icons.checklist_rounded,
        actionLabel: 'Aufgabe',
        onAction: onAdd,
        emptyText: 'Noch keine Aufgaben fuer das Studium.',
        children: [
          for (final task in tasks)
            CheckboxListTile(
              value: task.done,
              onChanged: (_) => onToggle(task.id),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                task.title,
                style: TextStyle(
                  color: task.done ? AppColors.mutedInk : AppColors.ink,
                  decoration: task.done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class ExamCard extends StatelessWidget {
  const ExamCard({required this.exams, required this.onAdd, super.key});

  final List<ExamOverview> exams;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final exam = exams.firstOrNull;

    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Naechste Pruefung',
            icon: Icons.school_rounded,
            actionLabel: 'Pruefung',
            onAction: onAdd,
          ),
          const SizedBox(height: 16),
          if (exam == null)
            const _EmptyText('Noch keine Pruefung eingetragen.')
          else ...[
            Text(exam.subject, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              exam.dateLabel,
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
          ],
        ],
      ),
    );
  }
}

class FocusTimerCard extends StatelessWidget {
  const FocusTimerCard({
    required this.seconds,
    required this.isRunning,
    required this.onToggle,
    required this.onReset,
    super.key,
  });

  final int seconds;
  final bool isRunning;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');

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
                '$minutes:$remainingSeconds',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(isRunning ? 'Pause' : 'Start'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
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
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Lernzeit diese Woche',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 20),
          if (hours.isEmpty)
            const _EmptyText(
              'Lernzeiten erscheinen hier nach den ersten Sessions.',
            )
          else
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
                                  heightFactor: item.hours,
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
                            Text(
                              item.day,
                              style: const TextStyle(fontSize: 12),
                            ),
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
  const NotesCard({required this.notes, required this.onAdd, super.key});

  final List<NoteItem> notes;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: _TitledSection(
        title: 'Letzte Notizen',
        icon: Icons.edit_note_rounded,
        actionLabel: 'Notiz',
        onAction: onAdd,
        emptyText: 'Noch keine Notizen.',
        children: [
          for (final note in notes)
            _LabeledRow(
              leading: 'Notiz',
              title: note.title,
              icon: Icons.notes_rounded,
            ),
        ],
      ),
    );
  }
}

class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({
    required this.activeTasks,
    required this.totalTasks,
    super.key,
  });

  final int activeTasks;
  final int totalTasks;

  @override
  Widget build(BuildContext context) {
    final progress = totalTasks == 0 ? 0.0 : activeTasks / totalTasks;

    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Tagesziel', icon: Icons.flag_rounded),
          const SizedBox(height: 18),
          Text(
            totalTasks == 0
                ? 'Noch kein Tagesziel gesetzt'
                : '$activeTasks von $totalTasks Aufgaben geschafft',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.mint,
            color: AppColors.sage,
          ),
          const SizedBox(height: 10),
          Text('${(progress * 100).round()} % geschafft'),
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
    required this.emptyText,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String emptyText;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        const SizedBox(height: 16),
        if (children.isEmpty) _EmptyText(emptyText) else ...children,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mauve),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel!),
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
  });

  final String leading;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mauve),
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

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.mutedInk));
  }
}
