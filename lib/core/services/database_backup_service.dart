import 'dart:io';
import '../sync/account_data_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

class DatabaseBackupService {
  static String get _dbName => DatabaseHelper.dbFileName;

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

  static Future<File> createBackupFile() async {
    final db = await DatabaseHelper.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');

    final source = File(
      db.path.isNotEmpty ? db.path : join(await getDatabasesPath(), _dbName),
    );
    final tempDir = await getTemporaryDirectory();
    return copyDatabaseTo(source, tempDir, DateTime.now());
  }

  /// Creates a backup of the current database and shares it.
  static Future<void> createAndShareBackup() async {
    final backup = await createBackupFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backup.path, mimeType: 'application/x-sqlite3')],
        text: 'Smart Planner Database Backup',
      ),
    );
  }

  /// Saves a backup via the system picker (Drive, Files, USB, Downloads).
  static Future<bool> saveBackupToStorage() async {
    final backup = await createBackupFile();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save database backup',
      fileName: basename(backup.path),
      bytes: await backup.readAsBytes(),
      mimeType: 'application/octet-stream',
    );
    return uri != null;
  }

  static Future<bool> pickAndRestoreBackup() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Import database');
    if (file == null) return false;
    final sourcePath = await materializePickedFile(file);
    await restoreBackup(sourcePath);
    return true;
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

  static Future<void> restoreBackup(String sourcePath) async {
    await validateBackupFile(sourcePath);

    if (DatabaseHelper.instance.accountId != null) {
      // Keep cloud versions/tombstones. Importing a backup is a merge; it must
      // never rewind a download cursor or transplant ownership metadata.
      await createBackupFile();
      await AccountDataService.mergeDatabase(sourcePath);
      return;
    }
    final targetPath = await DatabaseHelper.instance.activePath;
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source backup file not found');
    }

    await DatabaseHelper.instance.close();
    await replaceDatabaseFile(sourcePath, targetPath);
    await DatabaseHelper.instance.database;
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
      testDb = await openDatabase(sourcePath, readOnly: true);
      final tables = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      if (!names.contains('projects') || !names.contains('tasks')) {
        throw Exception('Selected file is not a Smart Planner database');
      }
    } catch (e) {
      if (e.toString().contains('Smart Planner')) rethrow;
      throw Exception('Selected file is not a valid SQLite database');
    } finally {
      await testDb?.close();
    }
  }
}
