import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/core/sync/sync_coordinator.dart';

void main() {
  test('flush runs sync immediately and waits for completion', () async {
    var runs = 0;
    final coordinator = SyncCoordinator(
      runner: () async {
        runs++;
      },
    );

    await coordinator.flush();

    expect(runs, 1);
  });

  test(
    'sync requests while running are coalesced into one follow-up run',
    () async {
      var runs = 0;
      var activeRuns = 0;
      var maxActiveRuns = 0;
      final firstRun = Completer<void>();
      final coordinator = SyncCoordinator(
        runner: () async {
          runs++;
          activeRuns++;
          maxActiveRuns = activeRuns > maxActiveRuns
              ? activeRuns
              : maxActiveRuns;
          if (runs == 1) {
            await firstRun.future;
          }
          activeRuns--;
        },
      );

      coordinator.requestSync(reason: 'first');
      await Future<void>.delayed(Duration.zero);
      coordinator.requestSync(reason: 'second');
      coordinator.requestSync(reason: 'third');

      expect(runs, 1);
      expect(maxActiveRuns, 1);

      firstRun.complete();
      await coordinator.flush();

      expect(runs, 2);
      expect(maxActiveRuns, 1);
    },
  );

  test(
    'debounced requests only run once after the debounce duration',
    () async {
      var runs = 0;
      final coordinator = SyncCoordinator(
        debounceDuration: const Duration(milliseconds: 20),
        runner: () async {
          runs++;
        },
      );

      coordinator.requestSync(debounced: true, reason: 'note');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      coordinator.requestSync(debounced: true, reason: 'note');
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(runs, 0);

      await coordinator.flush();

      expect(runs, 1);
    },
  );
}
