import 'package:flutter_test/flutter_test.dart';
import 'package:study_buddy/core/sync/study_sync.dart';

void main() {
  test('local dirty rows are preferred over stale remote rows', () {
    final local = DateTime.utc(2026, 9, 25, 12, 0, 0);
    final remote = DateTime.utc(2026, 9, 25, 11, 0, 0);

    expect(
      StudySync.shouldSkipRemoteApply(
        localNeedsSync: true,
        localUpdatedAt: local,
        remoteUpdatedAt: remote,
      ),
      isTrue,
    );
  });

  test('remote newer rows apply when local is clean and older', () {
    final local = DateTime.utc(2026, 9, 25, 10, 0, 0);
    final remote = DateTime.utc(2026, 9, 25, 11, 0, 0);

    expect(
      StudySync.shouldSkipRemoteApply(
        localNeedsSync: false,
        localUpdatedAt: local,
        remoteUpdatedAt: remote,
      ),
      isFalse,
    );
  });

  test('rows are only synced to the owning account or unowned rows', () {
    expect(
      StudySync.shouldSyncLocalRow(
        rowOwnerId: null,
        currentUserId: 'user-1',
      ),
      isTrue,
    );
    expect(
      StudySync.shouldSyncLocalRow(
        rowOwnerId: 'user-1',
        currentUserId: 'user-1',
      ),
      isTrue,
    );
    expect(
      StudySync.shouldSyncLocalRow(
        rowOwnerId: 'user-2',
        currentUserId: 'user-1',
      ),
      isFalse,
    );
  });
}
