import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planner/core/services/database_backup_service.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:planner/core/sync/account_data_service.dart';
import 'package:planner/core/sync/firebase_auth_service.dart';
import 'package:planner/core/sync/firebase_config.dart';
import 'package:planner/core/sync/local_workspace.dart';
import 'package:planner/core/sync/sync_store.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/providers/account_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _LocalAuth extends FirebaseAuthService {
  @override
  Future<void> authenticate(
    String email,
    String password, {
    required bool register,
  }) async {
    await storage.write(
      key: 'planner.firebase.${FirebaseConfig.projectId}.session',
      value: jsonEncode({
        'localId': email.split('@').first,
        'email': email,
        'idToken': 'test-token',
        'refreshToken': 'test-refresh',
        'expiresAt': DateTime.now().millisecondsSinceEpoch + 3600000,
      }),
    );
    await initialize();
    notifyListeners();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('en'));
  final helper = DatabaseHelper.instance;
  late Directory root;
  late _LocalAuth auth;
  AccountProvider? account;
  Project project(String name, {String id = 'p'}) =>
      Project(id: id, name: name, description: '');
  Future<Map<String, dynamic>> localize(
    String entity,
    Map<String, dynamic> row,
  ) async => row;
  Future<void> signIn(String id) async {
    await account!.authenticate(
      '$id@example.com',
      'Password123',
      register: false,
    );
    await account!.sync!.pause(); // Unit tests never send Firebase requests.
  }

  Future<File> snapshot() =>
      DatabaseBackupService.createBackupFile(directory: root);

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    root = await Directory.systemTemp.createTemp('planner_workspace_');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
    await helper.close();
    await databaseFactory.setDatabasesPath(root.path);
    await helper.switchAccount(null);
    auth = _LocalAuth();
    account = AccountProvider(auth: auth);
    await account!.start(() async {});
  });
  tearDown(() async {
    await account?.sync?.pause();
    account?.dispose();
    auth.dispose();
    await helper.switchAccount(null);
    await helper.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await root.delete(recursive: true);
  });

  test(
    'logout clears credentials, keeps the active workspace and restores it after restart',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Keep me'));
      final path = await helper.activePath;
      await account!.signOut();
      expect(account!.user, isNull);
      expect(account!.sync, isNull);
      expect(account!.workingLocally, isTrue);
      expect(
        await auth.storage.read(
          key: 'planner.firebase.${FirebaseConfig.projectId}.session',
        ),
        isNull,
      );
      expect(await helper.activePath, path);
      expect((await helper.getProjects()).single.name, 'Keep me');
      await helper.updateProject(project('Edited after logout'));
      await helper.switchAccount(null);
      await LocalWorkspace.restore(null);
      expect(await helper.activePath, path);
      expect((await helper.getProjects()).single.name, 'Edited after logout');
      expect(await SyncStore(await helper.database).pending(), hasLength(1));
      await signIn('alice');
      expect((await helper.getProjects()).single.name, 'Edited after logout');
      expect(await SyncStore(await helper.database).pending(), hasLength(1));
    },
  );

  test(
    'another account never receives the signed-out workspace or its pending changes',
    () async {
      await helper.insertProject(project('Guest', id: 'guest'));
      await signIn('alice');
      await helper.insertProject(project('Alice'));
      await account!.signOut();
      await helper.updateProject(project('Alice offline'));
      await signIn('bob');
      expect(await helper.getProjects(), isEmpty);
      expect(await SyncStore(await helper.database).pending(), isEmpty);
      await account!.signOut();
      await signIn('alice');
      expect((await helper.getProjects()).single.name, 'Alice offline');
      await LocalWorkspace.select(
        null,
      ); // Account deletion's explicit workspace exit.
      await LocalWorkspace.restore(null);
      expect(helper.accountId, isNull);
      expect((await helper.getProjects()).single.name, 'Guest');
    },
  );

  test(
    'standalone exports preserve related data and settings but contain no sync internals',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Export'));
      await helper.insertTask(
        ProjectTask(
          id: 't',
          projectId: 'p',
          name: 'Task',
          details: '',
          attachments: [],
          startDate: DateTime(2026),
          cost: 10,
          isPaid: true,
        ),
      );
      await helper.setAccountPreference('currency', 'USD');
      final backup = await snapshot();
      final exported = await openDatabase(
        backup.path,
        readOnly: true,
        singleInstance: false,
      );
      try {
        final tables = (await exported.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        )).map((r) => r['name']);
        expect(tables, containsAll(SyncStore.tables));
        expect(tables.where((t) => t.toString().startsWith('sync_')), isEmpty);
        expect(await exported.query('projects'), hasLength(1));
        expect(await exported.query('tasks'), hasLength(1));
        expect(await exported.query('incomes'), hasLength(1));
        expect(
          (await exported.query('account_settings')).single['value'],
          '"USD"',
        );
        expect(
          await exported.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='trigger'",
          ),
          isEmpty,
        );
        expect(await exported.getVersion(), 24);
      } finally {
        await exported.close();
      }
      await account!.signOut();
      final local = await account!.exportDatabase(
        allowLocalSnapshot: () async =>
            fail('No cloud refresh is needed when logged out'),
      );
      expect(local!.path, contains('local_backup_'));
    },
  );

  test(
    'backup round trip merges without duplicating records, settings or paid-task income',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Round trip'));
      await helper.insertTask(
        ProjectTask(
          id: 't',
          projectId: 'p',
          name: 'Task',
          details: '',
          attachments: [],
          startDate: DateTime(2026),
          cost: 10,
          isPaid: true,
        ),
      );
      final backup = await snapshot();
      await signIn('bob');
      await account!.signOut();
      await account!.importDatabase(backup.path);
      await account!.importDatabase(backup.path);
      expect(await helper.getProjects(), hasLength(1));
      expect(await helper.getTasks('p'), hasLength(1));
      expect(await helper.getIncomes(), hasLength(1));
      expect(await SyncStore(await helper.database).conflicts(), isEmpty);
      expect(await SyncStore(await helper.database).pending(), isNotEmpty);
      expect(
        await Directory('${root.path}/before_database_import').exists(),
        isTrue,
      );
    },
  );

  test(
    'conflicting import preserves unsynced edits until an offline review choice',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Backup version'));
      final backup = await snapshot();
      await helper.updateProject(project('Current unsynced version'));
      await account!.signOut();
      await account!.importDatabase(backup.path);
      expect(
        (await helper.getProjects()).single.name,
        'Current unsynced version',
      );
      expect(account!.conflicts, hasLength(1));
      final details = await account!.conflictDetails('project:p');
      expect(details.single['source'], 'backup');
      expect((details.single['payload'] as Map)['name'], 'Backup version');
      await account!.resolveConflict('project:p', keepLocal: true);
      expect(
        (await helper.getProjects()).single.name,
        'Current unsynced version',
      );
      expect(
        SyncStore.payload(
          (await SyncStore(await helper.database).pending()).single,
        )['name'],
        'Current unsynced version',
      );
      await account!.importDatabase(backup.path);
      await account!.resolveConflict('project:p', keepLocal: false);
      expect((await helper.getProjects()).single.name, 'Backup version');
      expect(
        SyncStore.payload(
          (await SyncStore(await helper.database).pending()).single,
        )['name'],
        'Backup version',
      );
      expect(account!.conflicts, isEmpty);
    },
  );

  test(
    'import cannot silently resurrect tombstones or rewind cloud versions',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Old backup'));
      final backup = await snapshot();
      final db = await helper.database;
      await db.delete('sync_outbox');
      final store = SyncStore(db);
      await store.applyPull(
        [
          {
            'entity': 'projects',
            'record_id': 'p',
            'group_key': 'project:p',
            'version': 7,
            'deleted': true,
            'payload': project('Deleted').toMap(),
          },
        ],
        7,
        localize,
      );
      await AccountDataService.mergeDatabase(backup.path);
      expect(await helper.getProjects(), isEmpty);
      expect(await store.hasImportConflicts(), isTrue);
      expect(await store.cursor, 7);
      await store.resolve('project:p', keepLocal: false, localize: localize);
      expect((await helper.getProjects()).single.name, 'Old backup');
      expect((await store.pending()).single['base_version'], 7);
      expect(await store.cursor, 7);
    },
  );

  test(
    'legacy backups omit new columns and never transplant sync state',
    () async {
      final file = File('${root.path}/legacy.db');
      final old = await openDatabase(file.path);
      await old.execute(
        'CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT, description TEXT, status TEXT)',
      );
      await old.execute(
        'CREATE TABLE tasks (id TEXT PRIMARY KEY, projectId TEXT, name TEXT)',
      );
      await old.execute('CREATE TABLE sync_control (cursor INTEGER)');
      await old.insert('projects', {
        'id': 'old',
        'name': 'Legacy',
        'description': '',
        'status': 'active',
      });
      await old.insert('sync_control', {'cursor': 999});
      await old.close();
      await signIn('alice');
      await DatabaseBackupService.restoreBackup(
        file.path,
        backupDirectory: root,
      );
      expect((await helper.getProjects()).single.name, 'Legacy');
      expect(await SyncStore(await helper.database).cursor, 0);
      expect(await SyncStore(await helper.database).pending(), hasLength(1));
    },
  );

  test(
    'malformed imports leave the active data and sync journal untouched',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Safe'));
      final bad = File('${root.path}/bad.db');
      await bad.writeAsString('not a database');
      await expectLater(
        DatabaseBackupService.restoreBackup(bad.path, backupDirectory: root),
        throwsException,
      );
      expect((await helper.getProjects()).single.name, 'Safe');
      expect(await SyncStore(await helper.database).pending(), hasLength(1));
    },
  );

  test(
    'failed cloud refresh requires a local export choice and blocks concurrent account operations',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Local only'));
      account!.sync!.errorKey = 'syncRetryError';
      final answer = Completer<bool>();
      final asked = Completer<void>();
      final export = account!.exportDatabase(
        allowLocalSnapshot: () {
          asked.complete();
          return answer.future;
        },
      );
      await asked.future;
      await account!.signOut();
      await account!.authenticate('bob@example.com', '', register: false);
      expect(account!.user!.id, 'alice');
      await expectLater(account!.importDatabase('unused'), throwsStateError);
      answer.complete(false);
      expect(await export, isNull);
      expect(account!.working, isFalse);
      final accepted = await account!.exportDatabase(
        allowLocalSnapshot: () async => true,
      );
      await account!.sync!.pause();
      expect(accepted!.path, contains('local_backup_'));
    },
  );

  test(
    'rejecting a backup group cannot recreate children of a deleted project',
    () async {
      await signIn('alice');
      await helper.insertProject(project('Backup parent'));
      await helper.insertTask(
        ProjectTask(
          id: 't',
          projectId: 'p',
          name: 'Backup child',
          details: '',
          attachments: [],
          startDate: DateTime(2026),
          cost: 0,
        ),
      );
      final backup = await snapshot();
      await helper.deleteProject('p');
      await account!.signOut();
      await account!.importDatabase(backup.path);
      expect(await helper.getProjects(), isEmpty);
      expect(await helper.getTasks('p'), isEmpty);
      expect(account!.conflicts, hasLength(2));
      await account!.resolveConflict('project:p', keepLocal: true);
      expect(await helper.getTasks('p'), isEmpty);
      await account!.importDatabase(backup.path);
      await account!.resolveConflict('project:p', keepLocal: false);
      expect(await helper.getProjects(), hasLength(1));
      expect(await helper.getTasks('p'), hasLength(1));
    },
  );

  test(
    'invalid relationships roll back the whole import and release the operation lock',
    () async {
      await helper.insertProject(project('Safe'));
      final backup = await snapshot();
      final source = await openDatabase(backup.path, singleInstance: false);
      await source.insert(
        'tasks',
        ProjectTask(
          id: 't',
          projectId: 'missing-parent',
          name: 'Invalid',
          details: '',
          attachments: [],
          startDate: DateTime(2026),
          cost: 0,
        ).toMap(),
      );
      await source.close();
      await expectLater(
        account!.importDatabase(backup.path),
        throwsFormatException,
      );
      expect(account!.working, isFalse);
      expect(account!.switching, isFalse);
      expect((await helper.getProjects()).single.name, 'Safe');
      expect(await helper.getTasks('missing-parent'), isEmpty);
    },
  );
}
