import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../core/services/database_helper.dart';
import '../core/sync/account_data_service.dart';
import '../core/sync/firebase_auth_service.dart';
import '../core/sync/firebase_config.dart';
import '../core/sync/local_file_policy.dart';
import '../core/sync/cloud_sync_service.dart';
import '../core/sync/sync_store.dart';
import '../core/sync/sync_transport.dart';

class AccountProvider extends ChangeNotifier with WidgetsBindingObserver {
  AccountProvider({FirebaseAuthService? auth})
    : _client = auth ?? FirebaseAuthService.instance {
    _user = _client.user;
    switching = DatabaseHelper.instance.accountId != _user?.id;
    WidgetsBinding.instance.addObserver(this);
    _client.addListener(_onAuthChanged);
  }
  final FirebaseAuthService _client;
  AccountUser? _user;
  AccountUser? get user => _user;
  bool get configured =>
      FirebaseConfig.configured && _client.initializationError == null;
  void _onAuthChanged() =>
      unawaited(Future<void>(() => _transition(_client.user)));

  bool switching = false;
  bool working = false;
  bool importAvailable = false;
  String? errorKey;
  CloudSyncService? sync;
  Future<void> Function()? reloadData;
  Future<void>? _transitioning;
  Timer? _retry;
  bool _disposed = false;
  bool _started = false;

  Future<void> start(Future<void> Function() reload) async {
    if (_started) return;
    _started = true;
    reloadData = reload;
    if (DatabaseHelper.instance.accountId != _client.user?.id) {
      await _transition(_client.user);
    } else {
      await _startSync();
    }
    _retry = Timer.periodic(
      const Duration(seconds: 30),
      (_) => sync?.schedule(),
    );
  }

  Future<void> _startSync() async {
    if (_user == null || _disposed) return;
    final db = await DatabaseHelper.instance.database;
    sync = CloudSyncService(
      transport: SyncTransport(_client),
      files: LocalFilePolicy(db),
      store: SyncStore(db),
      onRemoteChanges: () async => reloadData?.call(),
    )..addListener(_notify);
    final decided =
        (await db.query('sync_control')).first['import_decided'] == 1;
    importAvailable = !decided && await AccountDataService.hasGuestData();
    _notify();
    sync?.schedule();
  }

  Future<void> _stopSync() async {
    final old = sync;
    await old?.pause();
    old?.removeListener(_notify);
    old?.dispose();
    sync = null;
  }

  Future<void> _transition(AccountUser? next) async {
    final previous = _transitioning;
    final completer = Completer<void>();
    _transitioning = completer.future;
    await previous;
    try {
      if (_disposed ||
          (next?.id == _user?.id &&
              DatabaseHelper.instance.accountId == next?.id)) {
        return;
      }
      switching = true;
      _notify();
      await _stopSync();
      await DatabaseHelper.instance.switchAccount(next?.id);
      _user = next;
      importAvailable = false;
      await reloadData?.call();
      await _startSync();
      errorKey = null;
    } catch (_) {
      errorKey = 'accountSwitchFailed';
    } finally {
      switching = false;
      _notify();
      completer.complete();
    }
  }

  Future<void> authenticate(
    String email,
    String password, {
    required bool register,
  }) async {
    if (!configured || working) return;
    working = true;
    errorKey = null;
    _notify();
    try {
      await _client.authenticate(email, password, register: register);
      await _transition(_client.user);
    } catch (error) {
      errorKey = error is FirebaseAccountException
          ? error.messageKey
          : 'accountSignInFailed';
    } finally {
      working = false;
      _notify();
    }
  }

  Future<bool> resetPassword(String email) async {
    if (working) return false;
    working = true;
    errorKey = null;
    _notify();
    try {
      await _client.resetPassword(email);
      return true;
    } catch (error) {
      errorKey = error is FirebaseAccountException
          ? error.messageKey
          : 'accountSignInFailed';
      return false;
    } finally {
      working = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    if (working) return;
    working = true;
    errorKey = null;
    _notify();
    try {
      // Local sign-out remains available while offline.
      await _client.signOut();
      await _transition(null);
    } catch (_) {
      errorKey = 'accountSignOutFailed';
    } finally {
      working = false;
      _notify();
    }
  }

  Future<void> decideImport({
    required bool import,
    required Map<String, dynamic> guestPreferences,
  }) async {
    if (working || sync == null) return;
    working = true;
    errorKey = null;
    _notify();
    try {
      if (import) {
        await sync!.syncNow();
        if (sync!.errorKey != null || sync!.conflicts.isNotEmpty) {
          errorKey = 'syncBeforeImport';
          return;
        }
        await sync!.pause();
        await AccountDataService.importGuest(guestPreferences);
        await reloadData?.call();
        await _stopSync();
        await _startSync();
      }
      final db = await DatabaseHelper.instance.database;
      await db.update('sync_control', {'import_decided': 1});
      importAvailable = false;
      sync?.schedule();
    } catch (_) {
      errorKey = 'accountImportFailed';
      // Recreate a paused coordinator after an interrupted import.
      await _stopSync();
      await _startSync();
    } finally {
      working = false;
      _notify();
    }
  }

  Future<void> clearDeviceCache() async {
    if (working || _user == null) return;
    working = true;
    switching = true;
    _notify();
    try {
      await _stopSync();
      final db = await DatabaseHelper.instance.database;
      // Preserve the journal, conflicts, and local files when clearing a cache
      // would otherwise destroy changes that have never reached the server.
      if ((await SyncStore(db).pending()).isNotEmpty ||
          (await SyncStore(db).conflicts()).isNotEmpty) {
        errorKey = 'syncBeforeClear';
        await _startSync();
        return;
      }
      final activePath = await DatabaseHelper.instance.activePath;
      await DatabaseHelper.instance.close();
      await deleteDatabase(activePath);
      await DatabaseHelper.instance.database;
      await reloadData?.call();
      await _startSync();
    } catch (_) {
      errorKey = 'syncRetryError';
    } finally {
      switching = false;
      working = false;
      _notify();
    }
  }

  Future<void> deleteAccount(String password) async {
    if (working || _user == null) return;
    working = true;
    _notify();
    try {
      // Reauthenticate before deleting data. No server or paid Cloud Function.
      await _client.authenticate(_user!.email, password, register: false);
      await _stopSync();
      await SyncTransport(_client).deleteCloudData();
      final oldPath = await DatabaseHelper.instance.activePath;
      await _client.deleteUser();
      await _transition(null);
      await deleteDatabase(oldPath);
      errorKey = null;
    } catch (error) {
      errorKey = error is FirebaseAccountException
          ? error.messageKey
          : 'accountDeleteFailed';
      if (sync == null) await _startSync();
    } finally {
      working = false;
      _notify();
    }
  }

  void localChanged() => sync?.schedule();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync?.schedule();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _client.removeListener(_onAuthChanged);
    _retry?.cancel();
    final oldSync = sync;
    oldSync?.removeListener(_notify);
    unawaited(
      (oldSync?.pause() ?? Future<void>.value()).then(
        (_) => oldSync?.dispose(),
      ),
    );
    super.dispose();
  }
}
