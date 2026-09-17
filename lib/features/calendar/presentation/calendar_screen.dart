import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../domain/calendar_models.dart';
import 'calendar_controller.dart';
import 'calendar_editor.dart';
import 'academic_period_editor.dart';
import 'calendar_views.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: compact
          ? FloatingActionButton(
              tooltip: 'Neuer Termin',
              onPressed: () => showCalendarEditor(
                context,
                ref,
                initialDate: state.selectedDate,
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 28,
                16,
                compact ? 16 : 28,
                12,
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Zurück',
                    onPressed: () => compact && state.view == CalendarView.week
                        ? controller.selectDate(
                            DateTime(
                              state.selectedDate.year,
                              state.selectedDate.month,
                              state.selectedDate.day - 3,
                            ),
                          )
                        : controller.move(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  OutlinedButton(
                    onPressed: controller.today,
                    child: const Text('Heute'),
                  ),
                  IconButton(
                    tooltip: 'Weiter',
                    onPressed: () => compact && state.view == CalendarView.week
                        ? controller.selectDate(
                            DateTime(
                              state.selectedDate.year,
                              state.selectedDate.month,
                              state.selectedDate.day + 3,
                            ),
                          )
                        : controller.move(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _jumpToMonth(context, controller, state.selectedDate),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      DateFormat(
                        'MMMM yyyy',
                        'de_AT',
                      ).format(state.selectedDate),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!compact) const SizedBox(width: 18),
                  SegmentedButton<CalendarView>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: CalendarView.month,
                        label: Text('Monat'),
                      ),
                      ButtonSegment(
                        value: CalendarView.week,
                        label: Text('Woche'),
                      ),
                      ButtonSegment(
                        value: CalendarView.day,
                        label: Text('Tag'),
                      ),
                      ButtonSegment(
                        value: CalendarView.agenda,
                        label: Text('Agenda'),
                      ),
                    ],
                    selected: {state.view},
                    onSelectionChanged: (value) =>
                        controller.setView(value.first),
                  ),
                  PopupMenuButton<CalendarSource>(
                    tooltip: 'Kalenderquellen',
                    icon: const Icon(Icons.layers_outlined),
                    itemBuilder: (_) => [
                      for (final (source, label) in [
                        (CalendarSource.user, 'Meine Termine'),
                        (CalendarSource.phSalzburg, 'PH Salzburg'),
                        (
                          CalendarSource.austrianHoliday,
                          'Österreichische Feiertage',
                        ),
                        (CalendarSource.academicPeriod, 'Hochschulferien'),
                        (
                          CalendarSource.salzburgSchoolHolidays,
                          'Salzburger Schulferien',
                        ),
                      ])
                        CheckedPopupMenuItem(
                          value: source,
                          checked: state.visibleSources.contains(source),
                          child: Text(label),
                        ),
                    ],
                    onSelected: (source) => controller.toggleSource(
                      source,
                      !state.visibleSources.contains(source),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hochschulzeitraum hinzufügen',
                    onPressed: () => showAcademicPeriodEditor(
                      context,
                      ref,
                      initialDate: state.selectedDate,
                    ),
                    icon: const Icon(Icons.school_outlined),
                  ),
                  if (!compact)
                    FilledButton.icon(
                      onPressed: () => showCalendarEditor(
                        context,
                        ref,
                        initialDate: state.selectedDate,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Neuer Termin'),
                    ),
                ],
              ),
            ),
            if (state.selectedDate.year == 2026 &&
                    state.selectedDate.month == 9 ||
                controller.timeline.label(state.selectedDate) != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 0, 12, 10),
                  child: Text(
                    state.selectedDate.year == 2026 &&
                            state.selectedDate.month == 9
                        ? 'Studienstart · PH Salzburg'
                        : controller.timeline.label(state.selectedDate)!,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.error!),
              ),
            Expanded(child: CalendarViews(state: state)),
          ],
        ),
      ),
    );
  }

  Future<void> _jumpToMonth(
    BuildContext context,
    CalendarController controller,
    DateTime selected,
  ) async {
    var month = selected.month;
    var year = selected.year;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Zu Monat springen'),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: month,
                  decoration: const InputDecoration(labelText: 'Monat'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          DateFormat.MMMM('de_AT').format(DateTime(2026, m)),
                        ),
                      ),
                  ],
                  onChanged: (value) => update(() => month = value!),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(labelText: 'Jahr'),
                  items: [
                    for (var y = 2020; y <= 2045; y++)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (value) => update(() => year = value!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, DateTime(year, month, 1)),
              child: const Text('Springen'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) controller.selectDate(picked);
  }
}
