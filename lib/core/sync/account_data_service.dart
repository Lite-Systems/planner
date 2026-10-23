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
        if ((await tx.query('sync_conflicts', limit: 1)).isNotEmpty) {
          throw StateError(
            'Resolve existing conflicts before importing another backup',
          );
        }
        final proposed = <Map<String, dynamic>>[];
        final reviewGroups = <String>{};
        final parentIds = <String, Set<Object?>>{};
        for (final parent in ['projects', 'tasks', 'project_members']) {
          parentIds[parent] = {
            ...(await tx.query(parent, columns: ['id'])).map((r) => r['id']),
            ...?snapshots[parent]?.map((r) => r['id']),
          };
        }
        for (final entry in snapshots.entries) {
          final entity = entry.key;
          final schema = await tx.rawQuery('PRAGMA table_info($entity)');
          final columns = schema.map((r) => r['name']).toSet();
          for (final original in entry.value) {
            // Legacy backups can omit newer columns; the current schema supplies
            // defaults for new rows and preserves newer fields on existing rows.
            final data = Map<String, Object?>.fromEntries(
              original.entries.where((e) => columns.contains(e.key)),
            );
            if (entity == 'tasks' && data['status'] == 'todo') {
              data['status'] = 'toDo';
            }
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
            final merged = <String, dynamic>{
              if (existing.isNotEmpty) ...existing.first,
              ...data,
            };
            for (final column in schema) {
              if (column['notnull'] == 1 &&
                  column['dflt_value'] == null &&
                  merged[column['name']] == null) {
                throw const FormatException(
                  'Backup is missing required record fields',
                );
              }
            }
            if (existing.isNotEmpty &&
                SyncStore.jsonEqual(existing.first, merged)) {
              continue;
            }
            final state = await tx.query(
              'sync_state',
              where: 'entity=? AND record_id=?',
              whereArgs: [entity, id],
            );
            final pending = await tx.query(
              'sync_outbox',
              where: 'entity=? AND record_id=?',
              whereArgs: [entity, id],
            );
            final parents = switch (entity) {
              'tasks' || 'project_members' => {'projects': merged['projectId']},
              'task_assignees' => {
                'tasks': merged['taskId'],
                'project_members': merged['memberId'],
              },
              _ => <String, Object?>{},
            };
            for (final parent in parents.entries) {
              if (!parentIds[parent.key]!.contains(parent.value)) {
                throw const FormatException(
                  'Backup contains records with missing parents',
                );
              }
            }
            var group = await SyncStore.groupKey(tx, entity, merged);
            if (['task_assignees', 'incomes', 'expenses'].contains(entity)) {
              final parent = snapshots['tasks']
                  ?.where((r) => r['id'] == merged['taskId'])
                  .firstOrNull;
              if (parent != null) group = 'project:${parent['projectId']}';
            }
            if (existing.isNotEmpty ||
                (state.isNotEmpty && state.first['deleted'] == 1) ||
                (pending.isNotEmpty && pending.first['deleted'] == 1)) {
              reviewGroups.add(group);
            }
            proposed.add({
              'source': 'backup',
              'entity': entity,
              'record_id': id,
              'group_key': group,
              'version': state.isEmpty ? 0 : state.first['version'],
              'deleted': false,
              'payload': merged,
            });
          }
        }
        for (final proposal in proposed) {
          final group = proposal['group_key'];
          if (reviewGroups.contains(group)) {
            // Stage the entire changed group, including new child records,
            // so rejecting a deleted parent cannot leave orphan children.
            await tx.insert('sync_conflicts', {
              'entity': proposal['entity'],
              'record_id': proposal['record_id'],
              'group_key': group,
              'remote': jsonEncode(proposal),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            await SyncStore.putRow(
              tx,
              proposal['entity'] as String,
              Map<String, dynamic>.from(proposal['payload'] as Map),
              deleted: false,
            );
          }
        }
      });
    } finally {
      await source.close();
    }
  }
}
