import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_backup_service.dart';
import '../services/database_helper.dart';
import 'sync_store.dart';

class AccountDataService {
  static Future<String> get guestPath async =>
      DatabaseHelper.resolveDbPath(await getDatabasesPath());

  static Future<bool> hasGuestData() async {
    final file = File(await guestPath);
    if (!await file.exists()) return false;
    final db = await openDatabase(
      file.path,
      readOnly: true,
      singleInstance: false,
    );
    try {
      for (final table in ['projects', 'incomes', 'expenses', 'sticky_notes']) {
        final exists = await db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (exists.isNotEmpty &&
            (Sqflite.firstIntValue(
                      await db.rawQuery('SELECT COUNT(*) FROM $table'),
                    ) ??
                    0) >
                0) {
          return true;
        }
      }
      return false;
    } finally {
      await db.close();
    }
  }

  static Future<void> importGuest(Map<String, dynamic> preferences) async {
    final sourcePath = await guestPath;
    final backups = Directory(
      path.join(
        (await getApplicationSupportDirectory()).path,
        'before_account_import',
      ),
    );
    await DatabaseBackupService.copyDatabaseTo(
      File(sourcePath),
      backups,
      DateTime.now(),
    );
    await mergeDatabase(sourcePath);
    for (final entry in preferences.entries) {
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query(
        'account_settings',
        where: 'id=?',
        whereArgs: [entry.key],
      );
      if (existing.isEmpty) {
        await DatabaseHelper.instance.setAccountPreference(
          entry.key,
          entry.value as Object,
        );
      }
    }
  }

  /// Imports model rows only. A backup can never import another account's
  /// ownership, cursor, upload queue, conflict decisions, or session.
  static Future<void> mergeDatabase(String sourcePath) async {
    final target = await DatabaseHelper.instance.database;
    final source = await openDatabase(
      sourcePath,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final names = (await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      )).map((r) => r['name']).toSet();
      final snapshots = <String, List<Map<String, Object?>>>{};
      for (final table in SyncStore.tables) {
        if (names.contains(table)) snapshots[table] = await source.query(table);
      }
      await target.transaction((tx) async {
        for (final entry in snapshots.entries) {
          final entity = entry.key;
          for (final data in entry.value) {
            final id = entity == 'task_assignees'
                ? '${data['taskId']}:${data['memberId']}'
                : data['id']! as String;
            final where = entity == 'task_assignees'
                ? 'taskId=? AND memberId=?'
                : 'id=?';
            final args = entity == 'task_assignees'
                ? [data['taskId'], data['memberId']]
                : [id];
            final existing = await tx.query(
              entity,
              where: where,
              whereArgs: args,
            );
            if (existing.isNotEmpty &&
                SyncStore.jsonEqual(existing.first, data)) {
              continue;
            }
            final state = await tx.query(
              'sync_state',
              where: 'entity=? AND record_id=?',
              whereArgs: [entity, id],
            );
            await SyncStore.putRow(
              tx,
              entity,
              Map<String, dynamic>.from(data),
              deleted: false,
            );
            if (existing.isNotEmpty && state.isNotEmpty) {
              final pending = (await tx.query(
                'sync_outbox',
                where: 'entity=? AND record_id=?',
                whereArgs: [entity, id],
              )).first;
              await tx.insert('sync_conflicts', {
                'entity': entity,
                'record_id': id,
                'group_key': pending['group_key'],
                'remote': jsonEncode({
                  'entity': entity,
                  'record_id': id,
                  'group_key': pending['group_key'],
                  'version': state.first['version'],
                  'deleted': state.first['deleted'] == 1,
                  'payload': jsonDecode(state.first['payload']! as String),
                }),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      });
    } finally {
      await source.close();
    }
  }
}
