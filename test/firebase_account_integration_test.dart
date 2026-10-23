import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planner/core/services/database_backup_service.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:planner/core/sync/cloud_sync_service.dart';
import 'package:planner/core/sync/firebase_auth_service.dart';
import 'package:planner/core/sync/firebase_config.dart';
import 'package:planner/core/sync/local_file_policy.dart';
import 'package:planner/core/sync/local_workspace.dart';
import 'package:planner/core/sync/sync_store.dart';
import 'package:planner/core/sync/sync_transport.dart';
import 'package:planner/models/project.dart';
import 'package:planner/providers/account_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip =
      FirebaseConfig.authEmulator.isEmpty ||
          FirebaseConfig.firestoreEmulator.isEmpty
      ? 'Run with Firebase Auth and Firestore emulators; never uses the live project.'
      : false;
  late FirebaseAuthService auth;
  late Directory root;
  final helper = DatabaseHelper.instance;
  setUp(() async {
    HttpOverrides.global = null;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('en');
    auth = FirebaseAuthService();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    root = await Directory.systemTemp.createTemp('planner_firebase_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    await helper.close();
    await databaseFactory.setDatabasesPath(root.path);
    await helper.switchAccount(null);
  });
  tearDown(() async {
    await helper.switchAccount(null);
    await helper.close();
    auth.dispose();
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  String email() =>
      'planner-${DateTime.now().microsecondsSinceEpoch}@example.com';
  CloudSyncService service(Database db, FirebaseAuthService account) =>
      CloudSyncService(
        transport: SyncTransport(account),
        files: LocalFilePolicy(db),
        store: SyncStore(db),
        onRemoteChanges: () async {},
      );

  test(
    'backup import reaches another device; logout edits reconnect and deletion remains separate',
    () async {
      await helper.insertProject(
        Project(id: 'imported', name: 'Backup project', description: ''),
      );
      final backup = await DatabaseBackupService.createBackupFile(
        directory: root,
      );
      await helper.switchAccount('second_device');
      final secondPath = await helper.activePath;
      final address = email();
      await auth.authenticate(address, 'Password123!', register: true);
      await LocalWorkspace.restore(auth.user!.id);
      final account = AccountProvider(auth: auth);
      final secondAuth = FirebaseAuthService();
      await secondAuth.authenticate(address, 'Password123!', register: false);
      final secondDb = await openDatabase(secondPath, singleInstance: false);
      final secondSync = service(secondDb, secondAuth);
      try {
        await account.start(() async {});
        await account.importDatabase(backup.path);
        await account.sync!.syncNow();
        expect(account.sync!.errorKey, isNull);
        await secondSync.syncNow();
        expect(secondSync.errorKey, isNull);
        expect(
          (await secondDb.query('projects')).single['name'],
          'Backup project',
        );
        final owner = auth.user!.id;
        await account.signOut();
        expect(account.workspaceId, owner);
        expect(account.sync, isNull);
        await helper.updateProject(
          Project(
            id: 'imported',
            name: 'Edited while signed out',
            description: '',
          ),
        );
        await helper.close();
        await LocalWorkspace.restore(null);
        expect(helper.accountId, owner);
        await account.authenticate(address, 'Password123!', register: false);
        await account.sync!.syncNow();
        expect(account.sync!.errorKey, isNull);
        await secondSync.syncNow();
        expect(
          (await secondDb.query('projects')).single['name'],
          'Edited while signed out',
        );
        await account.importDatabase(backup.path);
        await account.sync!.syncNow();
        expect(account.conflicts, hasLength(1));
        expect(
          (await helper.getProjects()).single.name,
          'Edited while signed out',
        );
        await secondSync.syncNow();
        expect(
          (await secondDb.query('projects')).single['name'],
          'Edited while signed out',
        );
        await account.resolveConflict('project:imported', keepLocal: false);
        expect(account.conflicts, isEmpty);
        expect(account.sync!.errorKey, isNull);
        await secondSync.syncNow();
        expect(
          (await secondDb.query('projects')).single['name'],
          'Backup project',
        );
        await account.deleteAccount('Password123!');
        expect(account.errorKey, isNull);
        expect(account.user, isNull);
        expect(account.workspaceId, isNull);
        await LocalWorkspace.restore(null);
        expect(helper.accountId, isNull);
        expect((await helper.getProjects()).single.name, 'Backup project');
      } finally {
        await account.sync?.pause();
        account.dispose();
        await secondSync.pause();
        secondSync.dispose();
        await secondDb.close();
        secondAuth.dispose();
      }
    },
    skip: skip,
  );

  test(
    'Firebase registration, session restore, sign-in, password reset, and refresh work',
    () async {
      final address = email();
      await auth.authenticate(address, 'Password123!', register: true);
      final id = auth.user!.id;
      expect(auth.user!.email, address);
      final restored = FirebaseAuthService();
      await restored.initialize();
      expect(restored.user!.id, id);
      await auth.signOut();
      expect(auth.user, isNull);
      await auth.authenticate(address, 'Password123!', register: false);
      expect(auth.user!.id, id);
      await expectLater(
        auth.authenticate(address, 'Incorrect!', register: false),
        throwsA(isA<FirebaseAccountException>()),
      );
      await auth.resetPassword(address);
      const storage = FlutterSecureStorage();
      final key = 'planner.firebase.${FirebaseConfig.projectId}.session';
      final session = Map<String, dynamic>.from(
        jsonDecode((await storage.read(key: key))!) as Map,
      );
      session['expiresAt'] = 0;
      await storage.write(key: key, value: jsonEncode(session));
      final expired = FirebaseAuthService();
      await expired.initialize();
      expect(await expired.accessToken(), isNotEmpty);
      restored.dispose();
      expired.dispose();
    },
    skip: skip,
  );

  test(
    'Two devices sync records, preserve local files, and resolve offline conflicts',
    () async {
      final address = email();
      await auth.authenticate(address, 'Password123!', register: true);
      final desktopAuth = FirebaseAuthService();
      await desktopAuth.authenticate(address, 'Password123!', register: false);
      await helper.switchAccount('phone');
      final phonePath = await helper.activePath;
      await helper.switchAccount('desktop');
      final desktop = await helper.database;
      final phone = await openDatabase(phonePath, singleInstance: false);
      final phoneSync = service(phone, auth);
      final desktopSync = service(desktop, desktopAuth);
      try {
        await phone.insert(
          'projects',
          Project(
            id: 'p',
            name: 'Phone project',
            description: '',
            imagePath: '/phone/photo.jpg',
          ).toMap(),
        );
        await phoneSync.syncNow();
        expect(phoneSync.errorKey, isNull);
        await desktopSync.syncNow();
        expect(desktopSync.errorKey, isNull);
        expect(
          (await desktop.query('projects')).single['name'],
          'Phone project',
        );
        expect((await desktop.query('projects')).single['imagePath'], isNull);
        expect(
          (await phone.query('projects')).single['imagePath'],
          '/phone/photo.jpg',
        );
        await phone.update(
          'projects',
          {'name': 'Phone edit'},
          where: 'id=?',
          whereArgs: ['p'],
        );
        await desktop.update(
          'projects',
          {'name': 'Desktop edit'},
          where: 'id=?',
          whereArgs: ['p'],
        );
        await phoneSync.syncNow();
        await desktopSync.syncNow();
        expect(desktopSync.conflicts, isNotEmpty);
        expect(
          (await desktop.query('projects')).single['name'],
          'Desktop edit',
        );
        final remotes = await desktopSync.transport.group(
          'project:p',
          await desktopSync.store.pending(),
        );
        await desktopSync.store.saveConflicts(remotes, 'project:p');
        await desktopSync.resolve('project:p', keepLocal: true);
        expect(desktopSync.errorKey, isNull);
        await phoneSync.syncNow();
        expect((await phone.query('projects')).single['name'], 'Desktop edit');
        expect(
          (await phone.query('projects')).single['imagePath'],
          '/phone/photo.jpg',
        );
        await desktop.delete('projects', where: 'id=?', whereArgs: ['p']);
        await desktopSync.syncNow();
        await phoneSync.syncNow();
        expect(await phone.query('projects'), isEmpty);
      } finally {
        await phoneSync.pause();
        await desktopSync.pause();
        phoneSync.dispose();
        desktopSync.dispose();
        desktopAuth.dispose();
        await phone.close();
      }
    },
    skip: skip,
  );

  test(
    'Rules reject another account and account deletion removes planner data',
    () async {
      final address = email();
      await auth.authenticate(address, 'Password123!', register: true);
      await helper.switchAccount('owner');
      final db = await helper.database;
      final sync = service(db, auth);
      try {
        await db.insert(
          'projects',
          Project(id: 'p', name: 'Private', description: '').toMap(),
        );
        await sync.syncNow();
        expect(sync.errorKey, isNull);
        final other = FirebaseAuthService();
        await other.authenticate(email(), 'Password123!', register: true);
        final http = HttpClient();
        try {
          final endpoint =
              'http://${FirebaseConfig.firestoreEmulator}/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents:batchGet';
          final request = await http.postUrl(Uri.parse(endpoint));
          request.headers.contentType = ContentType.json;
          request.headers.set(
            'Authorization',
            'Bearer ${await other.accessToken()}',
          );
          request.write(
            jsonEncode({
              'documents': [
                'projects/${FirebaseConfig.projectId}/databases/(default)/documents/plannerUsers/${auth.user!.id}',
              ],
            }),
          );
          final response = await request.close();
          await response.drain<void>();
          expect(response.statusCode, 403);
        } finally {
          http.close(force: true);
          other.dispose();
        }
        final transport = SyncTransport(auth);
        await transport.deleteCloudData();
        expect(await transport.group('project:p', []), isEmpty);
        await expectLater(
          transport.pull(0),
          throwsA(isA<FirestoreSyncException>()),
        );
        await auth.deleteUser();
        expect(auth.user, isNull);
        await expectLater(
          auth.authenticate(address, 'Password123!', register: false),
          throwsA(isA<FirebaseAccountException>()),
        );
      } finally {
        await sync.pause();
        sync.dispose();
      }
    },
    skip: skip,
  );
}
