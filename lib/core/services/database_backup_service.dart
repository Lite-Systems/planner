import 'dart:io';

import '../sync/account_data_service.dart';
import '../sync/sync_store.dart';

import 'package:file_picker/file_picker.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

class DatabaseBackupService {
  static String backupFileName(DateTime now) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss', 'en').format(now);
    return 'smart_planner_backup_$timestamp.db';
  }

  static Future<File> copyDatabaseTo(
    File source,
    Directory destDir,
    DateTime now,
  ) async {
    if (!await source.exists()) {
      throw Exception('Database file not found');
    }
    await destDir.create(recursive: true);
    final backupPath = join(destDir.path, backupFileName(now));
    final backup = await source.copy(backupPath);
    for (final suffix in ['-wal', '-shm']) {
      final extra = File('${source.path}$suffix');
      if (await extra.exists()) {
        await extra.copy('$backupPath$suffix');
      }
    }
    return backup;
  }

  static Future<File> createBackupFile({
    bool localSnapshot = false,
    Directory? directory,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return exportSnapshot(
      db,
      directory ?? await getTemporaryDirectory(),
      localSnapshot: localSnapshot,
    );
  }

  /// Reads all model rows in one transaction. Tokens, queues, conflict decisions,
  /// cloud versions, triggers, and ownership never enter a portable backup.
  static Future<File> exportSnapshot(
    Database db,
    Directory directory, {
    bool localSnapshot = false,
  }) async {
    final schemas = <String, String>{};
    final rows = <String, List<Map<String, Object?>>>{};
    final indexes = <String>[];
    var version = 24;
    await db.transaction((tx) async {
      version =
          Sqflite.firstIntValue(await tx.rawQuery('PRAGMA user_version')) ?? 24;
      for (final table in SyncStore.tables) {
        final definition = await tx.query(
          'sqlite_master',
          columns: ['sql'],
          where: "type='table' AND name=?",
          whereArgs: [table],
        );
        if (definition.isEmpty) continue;
        schemas[table] = definition.first['sql']! as String;
        rows[table] = await tx.query(table);
        indexes.addAll(
          (await tx.query(
            'sqlite_master',
            columns: ['sql'],
            where: "type='index' AND tbl_name=? AND sql IS NOT NULL",
            whereArgs: [table],
          )).map((r) => r['sql']! as String),
        );
      }
    });
    await directory.create(recursive: true);
    final folder = await directory.createTemp('planner_backup_');
    final name = backupFileName(
      DateTime.now(),
    ).replaceFirst('backup_', localSnapshot ? 'local_backup_' : 'backup_');
    final file = File(join(folder.path, name));
    final backup = await openDatabase(file.path, singleInstance: false);
    try {
      await backup.transaction((tx) async {
        for (final schema in schemas.values) {
          await tx.execute(schema);
        }
        for (final entry in rows.entries) {
          for (final row in entry.value) {
            await tx.insert(entry.key, row);
          }
        }
        for (final sql in indexes) {
          await tx.execute(sql);
        }
        await tx.execute('PRAGMA user_version = $version');
      });
    } finally {
      await backup.close();
    }
    return file;
  }

  /// Creates a backup of the current database and shares it.
  static Future<void> createAndShareBackup({File? backup}) async {
    backup ??= await createBackupFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backup.path, mimeType: 'application/x-sqlite3')],
        text: 'Smart Planner Database Backup',
      ),
    );
  }

  /// Saves a backup via the system picker (Drive, Files, USB, Downloads).
  static Future<bool> saveBackupToStorage({File? backup}) async {
    backup ??= await createBackupFile();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save database backup',
      fileName: basename(backup.path),
      bytes: await backup.readAsBytes(),
      mimeType: 'application/octet-stream',
    );
    return uri != null;
  }

  static Future<bool> pickAndRestoreBackup() async {
    final sourcePath = await pickBackupPath();
    if (sourcePath == null) return false;
    await restoreBackup(sourcePath);
    return true;
  }

  static Future<String?> pickBackupPath() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Import database');
    if (file == null) return null;
    return materializePickedFile(file);
  }

  /// Copies a picker result to a real file SQLite can open.
  /// Cloud / SAF picks often have no local [PlatformFile.path].
  static Future<String> materializePickedFile(PlatformFile file) async {
    final path = file.path;
    if (path != null && await File(path).exists()) {
      return path;
    }
    final tempDir = await getTemporaryDirectory();
    final name = file.name.trim().isEmpty ? 'import.db' : basename(file.name);
    final dest = File(join(tempDir.path, name));
    await dest.writeAsBytes(await file.readAsBytes(), flush: true);
    return dest.path;
  }

  static Future<void> restoreBackup(
    String sourcePath, {
    Directory? backupDirectory,
  }) async {
    await validateBackupFile(sourcePath);
    // Durable safety copies survive app restarts and temporary-file cleanup.
    final directory =
        backupDirectory ??
        Directory(
          join(
            (await getApplicationSupportDirectory()).path,
            'before_database_import',
          ),
        );
    await createBackupFile(directory: directory);
    await AccountDataService.mergeDatabase(sourcePath);
  }

  /// Overwrites [targetPath] and deletes leftover SQLite WAL/SHM files.
  static Future<void> replaceDatabaseFile(
    String sourcePath,
    String targetPath,
  ) async {
    for (final suffix in ['', '-wal', '-shm']) {
      final leftover = File('$targetPath$suffix');
      if (await leftover.exists()) {
        await leftover.delete();
      }
    }
    await File(targetPath).parent.create(recursive: true);
    await File(sourcePath).copy(targetPath);
  }

  static Future<void> validateBackupFile(String sourcePath) async {
    Database? testDb;
    try {
      if (!await File(sourcePath).exists()) {
        throw const FormatException('Missing backup');
      }
      testDb = await openDatabase(
        sourcePath,
        readOnly: true,
        singleInstance: false,
      );
      final integrity = await testDb.rawQuery('PRAGMA quick_check');
      if (integrity.length != 1 || integrity.first.values.single != 'ok') {
        throw const FormatException('Damaged backup');
      }
      if (await testDb.getVersion() > 24) {
        throw Exception(
          'This Smart Planner backup requires a newer app version',
        );
      }
      final tables = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      if (!names.contains('projects') || !names.contains('tasks')) {
        throw Exception('Selected file is not a Smart Planner database');
      }
      for (final table in ['projects', 'tasks']) {
        final columns = (await testDb.rawQuery(
          'PRAGMA table_info($table)',
        )).map((r) => r['name']).toSet();
        if (!columns.containsAll([
          'id',
          'name',
          if (table == 'tasks') 'projectId',
        ])) {
          throw Exception('Selected file is not a Smart Planner database');
        }
      }
    } catch (e) {
      if (e.toString().contains('Smart Planner')) rethrow;
      throw Exception('Selected file is not a valid SQLite database');
    } finally {
      await testDb?.close();
    }
  }
}
