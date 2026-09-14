enum SyncStatus { idle, offlineOnly, syncing, synced, failed }

abstract interface class SyncService {
  Stream<SyncStatus> watchStatus();
  Future<void> syncNow();
}

class SyncPlan {
  const SyncPlan._();

  static const readsAreLocalFirst = true;
  static const remoteBackend = 'Supabase';
  static const futureLocalStore = 'Drift SQLite';
}
