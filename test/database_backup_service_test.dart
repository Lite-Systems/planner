import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planner/core/services/database_backup_service.dart';
import 'package:planner/core/services/database_helper.dart';

void main() {
  test('backup file name is timestamped .db', () async {
    await initializeDateFormatting('en');
    final name = DatabaseBackupService.backupFileName(
      DateTime(2026, 9, 7, 23, 26, 10),
    );
    expect(name, 'smart_planner_backup_20260907_232610.db');
    expect(name.endsWith('.db'), isTrue);
  });

  test('copyDatabaseTo creates a missing destination directory', () async {
    await initializeDateFormatting('en');
    final root = Directory.systemTemp.createTempSync('planner_backup_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final source = File('${root.path}/planner.db')..writeAsBytesSync([1, 2, 3]);
    final destDir = Directory('${root.path}/Caches/com.lite.smartplanner');
    expect(destDir.existsSync(), isFalse);

    final backup = await DatabaseBackupService.copyDatabaseTo(
      source,
      destDir,
      DateTime(2026, 9, 7, 23, 56, 8),
    );

    expect(destDir.existsSync(), isTrue);
    expect(backup.existsSync(), isTrue);
    expect(backup.readAsBytesSync(), [1, 2, 3]);
    expect(
      backup.path.endsWith('smart_planner_backup_20260907_235608.db'),
      isTrue,
    );
  });

  test('replaceDatabaseFile overwrites db and drops wal/shm', () async {
    final root = Directory.systemTemp.createTempSync('planner_restore_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final target = File('${root.path}/planner.db')..writeAsBytesSync([9, 9, 9]);
    File('${root.path}/planner.db-wal').writeAsBytesSync([1]);
    File('${root.path}/planner.db-shm').writeAsBytesSync([2]);
    final source = File('${root.path}/import.db')..writeAsBytesSync([4, 5, 6]);

    await DatabaseBackupService.replaceDatabaseFile(source.path, target.path);

    expect(target.readAsBytesSync(), [4, 5, 6]);
    expect(File('${root.path}/planner.db-wal').existsSync(), isFalse);
    expect(File('${root.path}/planner.db-shm').existsSync(), isFalse);
  });

  test('resolveDbPath copies legacy masrofy.db to planner.db', () async {
    final root = Directory.systemTemp.createTempSync('planner_migrate_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    File('${root.path}/masrofy.db').writeAsBytesSync([7, 8]);
    File('${root.path}/masrofy.db-wal').writeAsBytesSync([1]);

    final path = await DatabaseHelper.resolveDbPath(root.path);
    expect(path.endsWith('planner.db'), isTrue);
    expect(File(path).readAsBytesSync(), [7, 8]);
    expect(File('$path-wal').readAsBytesSync(), [1]);
  });
}
