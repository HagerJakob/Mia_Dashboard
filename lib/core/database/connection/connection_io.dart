import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local_database.dart';

QueryExecutor openConnection() {
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    return NativeDatabase.memory();
  }

  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, DriftDatabaseConfig.fileName));
    return NativeDatabase.createInBackground(file);
  });
}
