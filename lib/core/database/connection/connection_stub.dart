import 'package:drift/drift.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    throw UnsupportedError(
      'Drift persistence is not configured for this platform.',
    );
  });
}
