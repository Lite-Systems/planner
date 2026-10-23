import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/database_helper.dart';
import 'package:planner/core/sync/cloud_sync_service.dart';
import 'package:planner/core/sync/firebase_auth_service.dart';
import 'package:planner/core/sync/firebase_config.dart';
import 'package:planner/core/sync/local_file_policy.dart';
import 'package:planner/core/sync/sync_store.dart';
import 'package:planner/core/sync/sync_transport.dart';
import 'package:planner/models/project.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opt-in only: creates temporary accounts in the configured live project,
/// verifies the actual app services, then deletes those accounts and records.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('LIVE_FIREBASE_CHECK');
  test(
    'Live registration, sign-in, device sync, privacy, and deletion',
    () async {
      expect(FirebaseConfig.authEmulator, isEmpty);
      expect(FirebaseConfig.firestoreEmulator, isEmpty);
      HttpOverrides.global = null;
      FlutterSecureStorage.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('planner_live_check_');
      final owner = FirebaseAuthService();
      final desktopAuth = FirebaseAuthService();
      final other = FirebaseAuthService();
      final owners = [owner, other];
      final helper = DatabaseHelper.instance;
      Database? phone;
      CloudSyncService? phoneSync;
      CloudSyncService? desktopSync;
      addTearDown(() async {
        await phoneSync?.pause();
        await desktopSync?.pause();
        phoneSync?.dispose();
        desktopSync?.dispose();
        for (final account in owners) {
          if (account.user != null) {
            // These services contain only accounts created by this test.
            expect(account.user!.email, startsWith('planner-smoke-'));
            await SyncTransport(account).deleteCloudData();
            await account.deleteUser();
          }
        }
        await phone?.close();
        await helper.switchAccount(null);
        await helper.close();
        await root.delete(recursive: true);
        owner.dispose();
        other.dispose();
        desktopAuth.dispose();
      });
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final password =
          '${List.generate(24, (_) => Random.secure().nextInt(36).toRadixString(36)).join()}Aa!9';
      final address = 'planner-smoke-$nonce@example.com';
      await owner.authenticate(address, password, register: true);
      expect(owner.user!.email, address);
      await desktopAuth.authenticate(address, password, register: false);
      expect(desktopAuth.user!.id, owner.user!.id);
      final restored = FirebaseAuthService();
      await restored.initialize();
      expect(restored.user!.id, owner.user!.id);
      restored.dispose();

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      await helper.close();
      await databaseFactory.setDatabasesPath(root.path);
      await helper.switchAccount('phone');
      final phonePath = await helper.activePath;
      await helper.switchAccount('desktop');
      final desktop = await helper.database;
      phone = await openDatabase(phonePath, singleInstance: false);
      phoneSync = CloudSyncService(
        transport: SyncTransport(owner),
        files: LocalFilePolicy(phone),
        store: SyncStore(phone),
        onRemoteChanges: () async {},
      );
      desktopSync = CloudSyncService(
        transport: SyncTransport(desktopAuth),
        files: LocalFilePolicy(desktop),
        store: SyncStore(desktop),
        onRemoteChanges: () async {},
      );
      await phone.insert(
        'projects',
        Project(
          id: 'smoke',
          name: 'Phone saved project',
          description: '',
        ).toMap(),
      );
      await phoneSync.syncNow();
      expect(phoneSync.errorKey, isNull);
      expect(await phoneSync.store.pending(), isEmpty);
      await desktopSync.syncNow();
      expect(desktopSync.errorKey, isNull);
      expect(
        (await desktop.query('projects')).single['name'],
        'Phone saved project',
      );
      await desktop.update(
        'projects',
        {'name': 'Desktop edit'},
        where: 'id=?',
        whereArgs: ['smoke'],
      );
      await desktopSync.syncNow();
      expect(desktopSync.errorKey, isNull);
      await phoneSync.syncNow();
      expect((await phone.query('projects')).single['name'], 'Desktop edit');

      // Concurrent edits to independent projects must both survive a race on
      // the account's version head, using only normal Firebase user tokens.
      await phone.insert(
        'projects',
        Project(
          id: 'phone-add',
          name: 'Phone addition',
          description: '',
        ).toMap(),
      );
      await desktop.insert(
        'projects',
        Project(
          id: 'desktop-add',
          name: 'Desktop addition',
          description: '',
        ).toMap(),
      );
      await Future.wait([phoneSync.syncNow(), desktopSync.syncNow()]);
      expect(phoneSync.errorKey, isNull);
      expect(desktopSync.errorKey, isNull);
      await phoneSync.syncNow();
      await desktopSync.syncNow();
      expect((await phone.query('projects')).map((p) => p['id']).toSet(), {
        'smoke',
        'phone-add',
        'desktop-add',
      });
      expect((await desktop.query('projects')).map((p) => p['id']).toSet(), {
        'smoke',
        'phone-add',
        'desktop-add',
      });

      await other.authenticate(
        'planner-smoke-$nonce-other@example.com',
        password,
        register: true,
      );
      final http = HttpClient();
      try {
        final request = await http.postUrl(
          Uri.parse(
            'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents:batchGet',
          ),
        );
        request.headers.contentType = ContentType.json;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${await other.accessToken()}',
        );
        request.write(
          jsonEncode({
            'documents': [
              'projects/${FirebaseConfig.projectId}/databases/(default)/documents/plannerUsers/${owner.user!.id}',
            ],
          }),
        );
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, 403);
      } finally {
        http.close(force: true);
      }
      await desktop.delete('projects', where: 'id=?', whereArgs: ['smoke']);
      await desktopSync.syncNow();
      await phoneSync.syncNow();
      expect(
        await phone.query('projects', where: 'id=?', whereArgs: ['smoke']),
        isEmpty,
      );
    },
    skip: enabled
        ? false
        : 'Opt-in live check; run with --dart-define=LIVE_FIREBASE_CHECK=true.',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
