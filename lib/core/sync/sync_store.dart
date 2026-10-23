import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// The journal lives in the same SQLite transaction as the business edit.
/// Remote versions and portable payloads never replace local model fields.
class SyncStore {
  SyncStore(this.db);
  final Database db;

  static const tables = [
    'payment_methods',
    'income_categories',
    'expense_categories',
    'projects',
    'project_members',
    'tasks',
    'task_assignees',
    'incomes',
    'expenses',
    'sticky_notes',
    'account_settings',
  ];

  static Future<void> install(Database db, {required bool enabled}) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS account_settings '
      '(id TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_control '
      '(id INTEGER PRIMARY KEY CHECK(id=1), enabled INTEGER NOT NULL DEFAULT 0, '
      'suppressed INTEGER NOT NULL DEFAULT 0, cursor INTEGER NOT NULL DEFAULT 0, '
      'import_decided INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute('INSERT OR IGNORE INTO sync_control(id) VALUES(1)');
    await db.update('sync_control', {
      'enabled': enabled ? 1 : 0,
      'suppressed': 0,
    });
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_state '
      '(entity TEXT NOT NULL, record_id TEXT NOT NULL, version INTEGER NOT NULL, '
      'payload TEXT, deleted INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY(entity, record_id))',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_outbox '
      '(entity TEXT NOT NULL, record_id TEXT NOT NULL, group_key TEXT NOT NULL, '
      'base_version INTEGER NOT NULL, mutation_id TEXT NOT NULL, payload TEXT NOT NULL, '
      'deleted INTEGER NOT NULL, PRIMARY KEY(entity, record_id))',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_conflicts '
      '(entity TEXT NOT NULL, record_id TEXT NOT NULL, group_key TEXT NOT NULL, '
      'remote TEXT NOT NULL, PRIMARY KEY(entity, record_id))',
    );
    for (final table in tables) {
      final columns = (await db.rawQuery(
        'PRAGMA table_info($table)',
      )).map((r) => r['name']! as String).toList();
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final row = event == 'DELETE' ? 'OLD' : 'NEW';
        final id = table == 'task_assignees'
            ? "$row.taskId || ':' || $row.memberId"
            : '$row.id';
        final json = columns.map((c) => "'$c', $row.\"$c\"").join(', ');
        final linkedTask = event == 'UPDATE'
            ? 'COALESCE(NEW.taskId,OLD.taskId)'
            : '$row.taskId';
        final group = switch (table) {
          'projects' => "'project:' || $row.id",
          'tasks' || 'project_members' => "'project:' || $row.projectId",
          'task_assignees' =>
            "COALESCE((SELECT 'project:' || projectId FROM tasks WHERE id=$row.taskId), 'task:' || $row.taskId)",
          'incomes' || 'expenses' =>
            "COALESCE((SELECT 'project:' || projectId FROM tasks WHERE id=$linkedTask), '$table:' || $row.id)",
          _ => "'$table:' || $row.id",
        };
        await db.execute(
          '''CREATE TRIGGER IF NOT EXISTS sync_${table}_${event.toLowerCase()}
AFTER $event ON $table
WHEN (SELECT enabled=1 AND suppressed=0 FROM sync_control WHERE id=1)
BEGIN
 INSERT INTO sync_outbox(entity,record_id,group_key,base_version,mutation_id,payload,deleted)
 VALUES('$table',$id,$group,
 COALESCE((SELECT version FROM sync_state WHERE entity='$table' AND record_id=$id),0),
 lower(hex(randomblob(16))), json_object($json), ${event == 'DELETE' ? 1 : 0})
 ON CONFLICT(entity,record_id) DO UPDATE SET
 group_key=excluded.group_key, mutation_id=excluded.mutation_id,
 payload=excluded.payload, deleted=excluded.deleted;
END''',
        );
      }
    }
  }

  Future<List<Map<String, Object?>>> pending() => db.query('sync_outbox');
  Future<List<Map<String, Object?>>> conflicts() => db.query('sync_conflicts');
  Future<bool> hasImportConflicts() async => (await conflicts()).any(
    (row) =>
        (jsonDecode(row['remote']! as String) as Map)['source'] == 'backup',
  );

  static Future<String> groupKey(
    DatabaseExecutor db,
    String entity,
    Map<String, dynamic> row,
  ) async {
    if (entity == 'projects') return 'project:${row['id']}';
    if (entity == 'tasks' || entity == 'project_members') {
      return 'project:${row['projectId']}';
    }
    if (entity == 'task_assignees' ||
        entity == 'incomes' ||
        entity == 'expenses') {
      final tasks = await db.query(
        'tasks',
        columns: ['projectId'],
        where: 'id=?',
        whereArgs: [row['taskId']],
      );
      if (tasks.isNotEmpty) return 'project:${tasks.first['projectId']}';
      if (entity == 'task_assignees') return 'task:${row['taskId']}';
    }
    return '$entity:${row['id']}';
  }

  Future<int> get cursor async =>
      (await db.query('sync_control')).first['cursor']! as int;

  static Map<String, dynamic> payload(Map<String, Object?> row) =>
      Map<String, dynamic>.from(jsonDecode(row['payload']! as String) as Map);

  static Future<void> remember(
    DatabaseExecutor tx,
    Map<String, dynamic> remote,
  ) => tx.insert('sync_state', {
    'entity': remote['entity'],
    'record_id': remote['record_id'],
    'version': remote['version'],
    'payload': jsonEncode(remote['payload']),
    'deleted': remote['deleted'] == true ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> putRow(
    DatabaseExecutor tx,
    String entity,
    Map<String, dynamic> data, {
    required bool deleted,
  }) async {
    if (!tables.contains(entity)) {
      throw FormatException('Unknown entity: $entity');
    }
    final where = entity == 'task_assignees'
        ? 'taskId=? AND memberId=?'
        : 'id=?';
    final args = entity == 'task_assignees'
        ? [data['taskId'], data['memberId']]
        : [data['id']];
    if (deleted) {
      await tx.delete(entity, where: where, whereArgs: args);
    } else {
      // UPDATE rather than REPLACE: replacing a parent may delete its children.
      final count = await tx.update(
        entity,
        data,
        where: where,
        whereArgs: args,
      );
      if (count == 0) await tx.insert(entity, data);
    }
  }

  Future<void> acknowledge(
    List<Map<String, dynamic>> remotes,
    List<Map<String, Object?>> sent,
  ) async {
    await db.transaction((tx) async {
      for (var i = 0; i < remotes.length; i++) {
        final remote = remotes[i];
        final row = sent[i];
        await remember(tx, remote);
        // An edit made during upload stays queued against the acknowledged version.
        await tx.delete(
          'sync_outbox',
          where: 'entity=? AND record_id=? AND mutation_id=?',
          whereArgs: [row['entity'], row['record_id'], row['mutation_id']],
        );
        await tx.update(
          'sync_outbox',
          {'base_version': remote['version']},
          where: 'entity=? AND record_id=?',
          whereArgs: [row['entity'], row['record_id']],
        );
      }
    });
  }

  Future<void> saveConflicts(
    List<Map<String, dynamic>> remotes,
    String group,
  ) async {
    await db.transaction((tx) async {
      await tx.delete(
        'sync_conflicts',
        where: 'group_key=?',
        whereArgs: [group],
      );
      for (final remote in remotes) {
        await tx.insert('sync_conflicts', {
          'entity': remote['entity'],
          'record_id': remote['record_id'],
          'group_key': group,
          'remote': jsonEncode(remote),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> applyPull(
    List<Map<String, dynamic>> remotes,
    int nextCursor,
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
    localize,
  ) async {
    // Network downloads happen before opening a SQLite transaction.
    final localized = <Map<String, dynamic>>[];
    for (final remote in remotes) {
      localized.add(
        remote['deleted'] == true
            ? Map<String, dynamic>.from(remote['payload'] as Map)
            : await localize(
                remote['entity'] as String,
                Map<String, dynamic>.from(remote['payload'] as Map),
              ),
      );
    }
    await db.transaction((tx) async {
      await tx.update('sync_control', {'suppressed': 1});
      for (var i = 0; i < remotes.length; i++) {
        final remote = remotes[i];
        final key = [remote['entity'], remote['record_id']];
        final known = await tx.query(
          'sync_state',
          where: 'entity=? AND record_id=?',
          whereArgs: key,
        );
        if (known.isNotEmpty &&
            (known.first['version']! as int) >= (remote['version'] as int)) {
          continue;
        }
        final ownPending = await tx.query(
          'sync_outbox',
          where: 'entity=? AND record_id=?',
          whereArgs: key,
        );
        final groupPending = await tx.query(
          'sync_outbox',
          where: 'group_key=?',
          whereArgs: [remote['group_key']],
        );
        final pending = ownPending.isNotEmpty ? ownPending : groupPending;
        if (pending.isNotEmpty) {
          final row = pending.first;
          // Identical first-use seeds on two devices aren't an edit conflict.
          if (ownPending.isNotEmpty &&
              (row['base_version'] == 0 ||
                  row['mutation_id'] == remote['mutation_id']) &&
              row['deleted'] == 0 &&
              remote['deleted'] != true &&
              jsonEqual(payload(row), localized[i])) {
            await tx.delete(
              'sync_outbox',
              where: 'entity=? AND record_id=?',
              whereArgs: key,
            );
          } else {
            await tx.insert('sync_conflicts', {
              'entity': key[0],
              'record_id': key[1],
              'group_key': row['group_key'],
              'remote': jsonEncode(remote),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            continue;
          }
        }
        await putRow(
          tx,
          remote['entity'] as String,
          localized[i],
          deleted: remote['deleted'] == true,
        );
        await remember(tx, remote);
      }
      await tx.update('sync_control', {'cursor': nextCursor, 'suppressed': 0});
    });
  }

  Future<void> resolve(
    String group, {
    required bool keepLocal,
    required Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
    localize,
  }) async {
    final conflicts = await db.query(
      'sync_conflicts',
      where: 'group_key=?',
      whereArgs: [group],
    );
    final remotes = conflicts
        .map(
          (r) => Map<String, dynamic>.from(
            jsonDecode(r['remote']! as String) as Map,
          ),
        )
        .toList();
    if (remotes.every((r) => r['source'] == 'backup')) {
      remotes.sort(
        (a, b) => tables
            .indexOf(a['entity'] as String)
            .compareTo(tables.indexOf(b['entity'] as String)),
      );
    }
    final localized = <Map<String, dynamic>>[];
    for (final remote in remotes) {
      localized.add(
        keepLocal || remote['deleted'] == true
            ? Map<String, dynamic>.from(remote['payload'] as Map)
            : await localize(
                remote['entity'] as String,
                Map<String, dynamic>.from(remote['payload'] as Map),
              ),
      );
    }
    await db.transaction((tx) async {
      await tx.update('sync_control', {'suppressed': 1});
      for (var i = 0; i < remotes.length; i++) {
        final remote = remotes[i];
        final key = [remote['entity'], remote['record_id']];
        if (remote['source'] == 'backup') {
          // A backup is a proposed local edit, never an acknowledged cloud
          // version. Keep the existing row until the user chooses to import it.
          if (!keepLocal) {
            await tx.update('sync_control', {'suppressed': 0});
            await putRow(
              tx,
              remote['entity'] as String,
              Map<String, dynamic>.from(remote['payload'] as Map),
              deleted: false,
            );
            await tx.update('sync_control', {'suppressed': 1});
          }
          continue;
        }
        if (keepLocal) {
          final pending = await tx.query(
            'sync_outbox',
            where: 'entity=? AND record_id=?',
            whereArgs: key,
          );
          if (pending.isEmpty) {
            final entity = remote['entity'] as String;
            final data = Map<String, dynamic>.from(remote['payload'] as Map);
            final rows = await tx.query(
              entity,
              where: entity == 'task_assignees'
                  ? 'taskId=? AND memberId=?'
                  : 'id=?',
              whereArgs: entity == 'task_assignees'
                  ? [data['taskId'], data['memberId']]
                  : [data['id']],
            );
            await tx.insert('sync_outbox', {
              'entity': entity,
              'record_id': remote['record_id'],
              'group_key': group,
              'base_version': remote['version'],
              'mutation_id':
                  '${DateTime.now().microsecondsSinceEpoch}-${remote['record_id']}',
              'payload': jsonEncode(rows.isEmpty ? data : rows.first),
              'deleted': rows.isEmpty ? 1 : 0,
            });
          } else {
            await tx.update(
              'sync_outbox',
              {'base_version': remote['version']},
              where: 'entity=? AND record_id=?',
              whereArgs: key,
            );
          }
        } else {
          await putRow(
            tx,
            remote['entity'] as String,
            localized[i],
            deleted: remote['deleted'] == true,
          );
          await tx.delete(
            'sync_outbox',
            where: 'entity=? AND record_id=?',
            whereArgs: key,
          );
        }
        await remember(tx, remote);
      }
      await tx.delete(
        'sync_conflicts',
        where: 'group_key=?',
        whereArgs: [group],
      );
      await tx.update('sync_control', {'suppressed': 0});
    });
  }

  static bool jsonEqual(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && jsonEqual(a[k], b[k]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => jsonEqual(a[i], b[i]));
    }
    return a == b;
  }
}
