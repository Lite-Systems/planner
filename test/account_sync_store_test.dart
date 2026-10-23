import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:planner/core/sync/sync_store.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  late Directory root;
  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    root = await Directory.systemTemp.createTemp('planner_account_test_');
    await helper.close();
    await databaseFactory.setDatabasesPath(root.path);
    await helper.switchAccount(null);
  });
  tearDown(() async {
    await helper.switchAccount(null);
    await helper.close();
    await root.delete(recursive: true);
  });
  Project project(String name) => Project(id: 'p', name: name, description: '');
  Map<String, dynamic> remote({
    int version = 1,
    String name = 'Cloud',
    bool deleted = false,
  }) => {
    'entity': 'projects',
    'record_id': 'p',
    'group_key': 'project:p',
    'version': version,
    'deleted': deleted,
    'payload': project(name).toMap(),
  };
  Future<Map<String, dynamic>> localize(
    String entity,
    Map<String, dynamic> payload,
  ) async => payload;

  test(
    'Guest and two account databases remain isolated, including pending edits',
    () async {
      await helper.insertProject(project('Guest'));
      expect(await SyncStore(await helper.database).pending(), isEmpty);
      await helper.switchAccount('alice');
      expect(await helper.getProjects(), isEmpty);
      await helper.insertProject(project('Alice'));
      await helper.switchAccount('bob');
      expect(await helper.getProjects(), isEmpty);
      await helper.insertProject(project('Bob'));
      await helper.switchAccount('alice');
      expect((await helper.getProjects()).single.name, 'Alice');
      expect(await SyncStore(await helper.database).pending(), hasLength(1));
      await helper.switchAccount(null);
      expect((await helper.getProjects()).single.name, 'Guest');
    },
  );

  test('Mutation and durable journal roll back together', () async {
    await helper.switchAccount('alice');
    final db = await helper.database;
    await expectLater(
      db.transaction((tx) async {
        await tx.insert('projects', project('Must roll back').toMap());
        throw StateError('Interrupted save');
      }),
      throwsStateError,
    );
    expect(await helper.getProjects(), isEmpty);
    expect(await SyncStore(db).pending(), isEmpty);
  });

  test('Remote application does not echo back into the upload queue', () async {
    await helper.switchAccount('alice');
    final store = SyncStore(await helper.database);
    await store.applyPull([remote()], 1, localize);
    expect((await helper.getProjects()).single.name, 'Cloud');
    expect(await store.pending(), isEmpty);
    expect(await store.cursor, 1);
    await helper.updateProject(project('Local edit'));
    expect((await store.pending()).single['base_version'], 1);
    await helper.close();
    expect(
      (await SyncStore(await helper.database).pending()).single['base_version'],
      1,
    );
  });

  test('An edit made during upload survives its acknowledgement', () async {
    await helper.switchAccount('alice');
    final store = SyncStore(await helper.database);
    await helper.insertProject(project('First'));
    final sent = await store.pending();
    await helper.updateProject(project('Second'));
    await store.acknowledge([remote(name: 'First')], sent);
    final pending = (await store.pending()).single;
    expect(pending['base_version'], 1);
    expect(SyncStore.payload(pending)['name'], 'Second');
    expect(pending['mutation_id'], isNot(sent.single['mutation_id']));
  });

  test(
    'Conflicting edits preserve the local version until a choice is made',
    () async {
      await helper.switchAccount('alice');
      final store = SyncStore(await helper.database);
      await store.applyPull([remote()], 1, localize);
      await helper.updateProject(project('Offline'));
      await store.applyPull(
        [remote(version: 2, name: 'Other device')],
        2,
        localize,
      );
      expect((await helper.getProjects()).single.name, 'Offline');
      expect(await store.conflicts(), hasLength(1));
      await store.resolve('project:p', keepLocal: true, localize: localize);
      expect((await store.pending()).single['base_version'], 2);
      expect((await helper.getProjects()).single.name, 'Offline');
      expect(await store.conflicts(), isEmpty);
    },
  );

  test(
    'Choosing cloud applies edits and tombstones without queueing them',
    () async {
      await helper.switchAccount('alice');
      final store = SyncStore(await helper.database);
      await store.applyPull([remote()], 1, localize);
      await helper.updateProject(project('Offline'));
      await store.applyPull([remote(version: 2, deleted: true)], 2, localize);
      expect(await helper.getProjects(), hasLength(1));
      await store.resolve('project:p', keepLocal: false, localize: localize);
      expect(await helper.getProjects(), isEmpty);
      expect(await store.pending(), isEmpty);
    },
  );

  test(
    'Remote project deletion preserves locally edited child tasks for review',
    () async {
      await helper.switchAccount('alice');
      final store = SyncStore(await helper.database);
      await store.applyPull([remote()], 1, localize);
      await helper.insertTask(
        ProjectTask(
          id: 't',
          projectId: 'p',
          name: 'Offline task',
          details: '',
          attachments: [],
          startDate: DateTime(2026),
          cost: 10,
        ),
      );
      await store.applyPull([remote(version: 2, deleted: true)], 2, localize);
      expect(await helper.getProjects(), hasLength(1));
      expect(await helper.getTasks('p'), hasLength(1));
      expect(await store.conflicts(), hasLength(1));
    },
  );

  test(
    'Paid task, assignees, and generated income save atomically in one sync group',
    () async {
      await helper.switchAccount('alice');
      await helper.insertProject(project('Payments'));
      final task = ProjectTask(
        id: 't',
        projectId: 'p',
        name: 'Paid work',
        details: '',
        attachments: [],
        startDate: DateTime(2026),
        cost: 25,
        currency: 'USD',
        isPaid: true,
      );
      await helper.insertTask(task);
      expect((await helper.getIncomes()).single.id, 'task_income_t');
      expect((await helper.getIncomes()).single.currency, 'USD');
      await helper.updateTask(task.copyWith(name: 'Edited'));
      expect(await helper.getIncomes(), hasLength(1));
      final pending = await SyncStore(await helper.database).pending();
      expect(
        pending
            .where((r) => r['entity'] == 'tasks' || r['entity'] == 'incomes')
            .every((r) => r['group_key'] == 'project:p'),
        isTrue,
      );
      await helper.updateTask(task.copyWith(isPaid: false));
      expect(await helper.getIncomes(), isEmpty);
    },
  );

  test('Account reset refuses to delete an unsynced database', () async {
    await helper.switchAccount('alice');
    await helper.insertProject(project('Unsynced'));
    await expectLater(helper.resetDatabase(), throwsStateError);
    expect(await helper.getProjects(), hasLength(1));
  });

  test('Account IDs cannot escape their database folder', () async {
    await expectLater(helper.switchAccount('../guest'), throwsArgumentError);
  });
}
