abstract interface class LocalDatabase {
  Future<void> open();
  Future<void> close();
}

class DriftDatabaseConfig {
  const DriftDatabaseConfig._();

  static const fileName = 'study_buddy.sqlite';
}
