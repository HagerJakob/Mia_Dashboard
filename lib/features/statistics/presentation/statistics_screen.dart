import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/study_card.dart';
import '../../../theme/app_colors.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../statistics/data/analytics_service.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  final AnalyticsService _analytics = const AnalyticsService();
  late AnalyticsRange _range;
  String? _subjectId;
  String? _examId;

  @override
  void initState() {
    super.initState();
    _range = _analytics.weekRange(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyBuddyControllerProvider);
    final report = _analytics.buildReport(
      state,
      _range,
      subjectId: _subjectId,
      examId: _examId,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 90),
          children: [
            _Header(
              range: _range,
              state: state,
              subjectId: _subjectId,
              examId: _examId,
              onPeriod: _setPeriod,
              onPrevious: () => setState(() {
                _range = _analytics.shiftRange(_range, -1);
              }),
              onNext: () => setState(() {
                _range = _analytics.shiftRange(_range, 1);
              }),
              onCustom: _pickCustomRange,
              onSubject: (value) => setState(() => _subjectId = value),
              onExam: (value) => setState(() => _examId = value),
            ),
            const SizedBox(height: 18),
            if (!report.hasStudyData &&
                report.taskStats.completed == 0 &&
                report.examStats.total == 0)
              const _EmptyAnalytics()
            else ...[
              _SummaryGrid(report: report),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  final children = [
                    _StudyTimeChart(report: report),
                    _SubjectChart(report: report),
                  ];
                  if (!wide) {
                    return Column(
                      children: [
                        children[0],
                        const SizedBox(height: 18),
                        children[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: children[0]),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: children[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _Heatmap(report: report),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  final left = Column(
                    children: [
                      _FocusStats(report: report),
                      const SizedBox(height: 18),
                      _TaskStats(report: report),
                    ],
                  );
                  final right = Column(
                    children: [
                      _ExamStats(report: report),
                      const SizedBox(height: 18),
                      _Insights(report: report),
                    ],
                  );
                  if (!wide) {
                    return Column(
                      children: [left, const SizedBox(height: 18), right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 18),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setPeriod(AnalyticsPeriod period) {
    final now = DateTime.now();
    setState(() {
      _range = switch (period) {
        AnalyticsPeriod.week => _analytics.weekRange(now),
        AnalyticsPeriod.month => _analytics.monthRange(now),
        AnalyticsPeriod.semester => _analytics.semesterRange(now),
        AnalyticsPeriod.year => _analytics.yearRange(now),
        AnalyticsPeriod.custom => _range,
      };
    });
  }

  Future<void> _pickCustomRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _range.start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: _range.end.isBefore(start) ? start : _range.end,
      firstDate: start,
      lastDate: DateTime(2035),
    );
    if (end == null) return;
    setState(() {
      _range = AnalyticsRange(
        period: AnalyticsPeriod.custom,
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(end.year, end.month, end.day),
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.range,
    required this.state,
    required this.subjectId,
    required this.examId,
    required this.onPeriod,
    required this.onPrevious,
    required this.onNext,
    required this.onCustom,
    required this.onSubject,
    required this.onExam,
  });

  final AnalyticsRange range;
  final StudyBuddyState state;
  final String? subjectId;
  final String? examId;
  final ValueChanged<AnalyticsPeriod> onPeriod;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCustom;
  final ValueChanged<String?> onSubject;
  final ValueChanged<String?> onExam;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statistiken', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<AnalyticsPeriod>(
              segments: const [
                ButtonSegment(
                  value: AnalyticsPeriod.week,
                  label: Text('Woche'),
                ),
                ButtonSegment(
                  value: AnalyticsPeriod.month,
                  label: Text('Monat'),
                ),
                ButtonSegment(
                  value: AnalyticsPeriod.semester,
                  label: Text('Semester'),
                ),
                ButtonSegment(value: AnalyticsPeriod.year, label: Text('Jahr')),
                ButtonSegment(
                  value: AnalyticsPeriod.custom,
                  label: Text('Benutzerdefiniert'),
                ),
              ],
              selected: {range.period},
              onSelectionChanged: (value) {
                if (value.single == AnalyticsPeriod.custom) {
                  onCustom();
                } else {
                  onPeriod(value.single);
                }
              },
            ),
            IconButton(
              tooltip: 'Vorheriger Zeitraum',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(formatDateRange(range)),
            IconButton(
              tooltip: 'Nächster Zeitraum',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            _FilterDropdown(
              label: 'Fach',
              value: subjectId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Alle Fächer')),
                for (final subject in state.subjects)
                  DropdownMenuItem(
                    value: subject.id,
                    child: Text(subject.name),
                  ),
              ],
              onChanged: onSubject,
            ),
            _FilterDropdown(
              label: 'Prüfung',
              value: examId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Alle Prüfungen'),
                ),
                for (final exam in state.exams)
                  DropdownMenuItem(value: exam.id, child: Text(exam.title)),
              ],
              onChanged: onExam,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final diff = report.differenceToPrevious;
    final compare = report.previousStudySeconds == 0
        ? (report.studySeconds > 0
              ? '+ ${formatDuration(report.studySeconds)} zum Vorzeitraum'
              : 'Noch kein Vergleich')
        : '${diff >= 0 ? '+' : '-'} ${formatDuration(diff.abs())} zum Vorzeitraum';
    final cards = [
      _KpiCard(
        title: 'Lernzeit',
        value: formatDuration(report.studySeconds),
        caption: compare,
        icon: Icons.timer_outlined,
      ),
      _KpiCard(
        title: 'Sessions',
        value: '${report.sessionCount}',
        caption: 'Ø ${formatDuration(report.averageSessionSeconds)}',
        icon: Icons.bolt_outlined,
      ),
      _KpiCard(
        title: 'Aufgaben',
        value: '${report.taskStats.completed}',
        caption:
            'erledigt · ${(report.taskStats.completionRate * 100).round()} %',
        icon: Icons.check_circle_outline_rounded,
      ),
      _KpiCard(
        title: 'Lernstreak',
        value: '${report.streakStats.currentDays} Tage',
        caption: 'längster: ${report.streakStats.longestDays} Tage',
        icon: Icons.local_fire_department_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.mauve),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StudyTimeChart extends StatelessWidget {
  const _StudyTimeChart({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = report.dailyStudy.fold<int>(
      0,
      (max, bucket) => bucket.seconds > max ? bucket.seconds : max,
    );
    final strongest = report.dailyStudy.fold<AnalyticsBucket?>(
      null,
      (best, item) => best == null || item.seconds > best.seconds ? item : best,
    );
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lernzeit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (maxSeconds == 0)
            const _InlineEmpty('Noch keine Lernzeit in diesem Zeitraum.')
          else
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bucket in report.dailyStudy)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${bucket.label}: ${formatDuration(bucket.seconds)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: maxSeconds == 0
                                        ? 0
                                        : (bucket.seconds / maxSeconds).clamp(
                                            0.04,
                                            1,
                                          ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.mauve.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const SizedBox(width: 22),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bucket.label.split(' ').first,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _MetricText('Gesamt', formatDuration(report.studySeconds)),
              _MetricText(
                'Tagesdurchschnitt',
                formatDuration(
                  report.dailyStudy.isEmpty
                      ? 0
                      : report.studySeconds ~/ report.dailyStudy.length,
                ),
              ),
              if (strongest != null && strongest.seconds > 0)
                _MetricText(
                  'Aktivster Tag',
                  '${strongest.label} · ${formatDuration(strongest.seconds)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectChart extends StatelessWidget {
  const _SubjectChart({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lernzeit nach Fach',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (report.subjectStudy.isEmpty)
            const _InlineEmpty('Noch keine Fächer in Lernzeiten erfasst.')
          else
            for (final subject in report.subjectStudy.take(8))
              _ProgressRow(
                label: subject.name,
                value: formatDuration(subject.seconds),
                color: subject.color,
                fraction: report.studySeconds == 0
                    ? 0
                    : subject.seconds / report.studySeconds,
              ),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lern-Heatmap', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Intensität: 0 min, 1–30, 31–60, 61–120, 120+ Minuten.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in report.heatmapDays)
                Tooltip(
                  message:
                      '${day.date.day}.${day.date.month}.${day.date.year}\n${formatDuration(day.seconds)} · ${day.sessionCount} Sessions',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _heatColor(day.level),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(
                        child: Text(
                          '${day.date.day}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusStats extends StatelessWidget {
  const _FocusStats({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Focus Sessions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _MetricText('Sessions', '${report.sessionCount}'),
          _MetricText('Gesamt', formatDuration(report.studySeconds)),
          _MetricText(
            'Durchschnitt',
            formatDuration(report.averageSessionSeconds),
          ),
          _MetricText(
            'Längste Session',
            formatDuration(report.longestSessionSeconds),
          ),
          _MetricText(
            'Kürzeste sinnvolle Session',
            report.shortestMeaningfulSessionSeconds == 0
                ? 'Noch keine'
                : formatDuration(report.shortestMeaningfulSessionSeconds),
          ),
          _MetricText('Pomodoros', '${report.pomodoroCount}'),
        ],
      ),
    );
  }
}

class _TaskStats extends StatelessWidget {
  const _TaskStats({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final stats = report.taskStats;
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aufgaben', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _MetricText('Erstellt', '${stats.created}'),
          _MetricText('Erledigt', '${stats.completed}'),
          _MetricText('Offen', '${stats.open}'),
          _MetricText('Überfällig', '${stats.overdue}'),
          _ProgressRow(
            label: 'Completion Rate',
            value: '${(stats.completionRate * 100).round()} %',
            color: AppColors.sage,
            fraction: stats.completionRate,
          ),
        ],
      ),
    );
  }
}

class _ExamStats extends StatelessWidget {
  const _ExamStats({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prüfungen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          _MetricText('Im Zeitraum', '${report.examStats.total}'),
          _MetricText('Abgeschlossen', '${report.examStats.completed}'),
          _MetricText('Ergebnis offen', '${report.examStats.resultsPending}'),
          if (report.examStats.compatibleGradeAverage != null)
            _MetricText(
              'Notendurchschnitt',
              report.examStats.compatibleGradeAverage!.toStringAsFixed(2),
            ),
          const SizedBox(height: 12),
          if (report.examStudy.isEmpty)
            const _InlineEmpty('Noch keine prüfungsbezogene Lernzeit.')
          else
            for (final exam in report.examStudy.take(5))
              _ProgressRow(
                label: exam.exam.title,
                value: formatDuration(exam.seconds),
                color: AppColors.lavender,
                fraction: report.studySeconds == 0
                    ? 0
                    : exam.seconds / report.studySeconds,
              ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insights', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (report.insights.isEmpty)
            const _InlineEmpty(
              'Für Insights sind noch zu wenig Daten vorhanden.',
            )
          else
            for (final insight in report.insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: AppColors.mauve,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(insight)),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          Text(
            'Wann lernst du?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final bucket in report.timeOfDayStudy)
            _ProgressRow(
              label: bucket.label,
              value: formatDuration(bucket.seconds),
              color: AppColors.mauve,
              fraction: report.studySeconds == 0
                  ? 0
                  : bucket.seconds / report.studySeconds,
            ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
    required this.fraction,
  });

  final String label;
  final String value;
  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final safeFraction = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 10),
              Text(value, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: safeFraction,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Icon(
              Icons.insights_rounded,
              size: 42,
              color: AppColors.mauve,
            ),
            const SizedBox(height: 14),
            Text(
              'Noch keine Lernstatistiken.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Starte eine Focus Session, erledige Aufgaben oder trage Prüfungen ein, damit StudyBuddy echte Auswertungen zeigen kann.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Color _heatColor(int level) {
  return switch (level) {
    0 => AppColors.surface,
    1 => AppColors.blush.withValues(alpha: 0.65),
    2 => AppColors.rose.withValues(alpha: 0.32),
    3 => AppColors.mauve.withValues(alpha: 0.38),
    _ => AppColors.mauve.withValues(alpha: 0.62),
  };
}
