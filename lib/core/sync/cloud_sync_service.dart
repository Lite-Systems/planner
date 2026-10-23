import 'dart:async';

import 'package:flutter/foundation.dart';

import 'firebase_auth_service.dart';

import 'local_file_policy.dart';
import 'sync_store.dart';
import 'sync_transport.dart';

class CloudSyncService extends ChangeNotifier {
  CloudSyncService({
    required this.transport,
    required this.files,
    required this.store,
    required this.onRemoteChanges,
  });
  final SyncTransport transport;
  final LocalFilePolicy files;
  final SyncStore store;
  final Future<void> Function() onRemoteChanges;
  bool busy = false;
  bool _paused = false;
  bool _disposed = false;
  String? errorKey;
  int pendingCount = 0;
  DateTime? lastSynced;
  List<Map<String, Object?>> conflicts = [];
  Timer? _debounce;
  Future<void>? _running;
  Future<void>? _resolving;

  void schedule() {
    if (_paused || _disposed || busy) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), syncNow);
  }

  Future<void> refreshStatus() async {
    pendingCount = (await store.pending()).length;
    conflicts = await store.conflicts();
    _notify();
  }

  Future<void> syncNow() {
    if (_paused || _disposed) return Future.value();
    if (_running != null) return _running!;
    _debounce?.cancel();
    final completer = Completer<void>();
    _running = completer.future;
    unawaited(
      _run().whenComplete(() {
        _running = null;
        completer.complete();
      }),
    );
    return completer.future;
  }

  Future<void> _run() async {
    busy = true;
    errorKey = null;
    _notify();
    try {
      // Finish reviewing a backup before exchanging any of its related rows.
      // This also lets offline import decisions retain their cloud base versions.
      if (await store.hasImportConflicts()) return;
      // Pull first: a newly installed device must not overwrite cloud records
      // with its automatically seeded defaults.
      await _pull();
      if (_paused) return;
      final pending = await store.pending();
      final blocked = (await store.conflicts())
          .map((r) => r['group_key'])
          .toSet();
      final groups = <String, List<Map<String, Object?>>>{};
      for (final row in pending) {
        final group = row['group_key']! as String;
        if (!blocked.contains(group)) {
          groups.putIfAbsent(group, () => []).add(row);
        }
      }
      for (final entry in groups.entries) {
        if (_paused) break;
        try {
          final changes = <Map<String, dynamic>>[];
          for (final row in entry.value) {
            changes.add({
              'entity': row['entity'],
              'record_id': row['record_id'],
              'base_version': row['base_version'],
              'mutation_id': row['mutation_id'],
              'deleted': row['deleted'] == 1,
              'payload': row['deleted'] == 1
                  ? _deletedPayload(row)
                  : await files.portable(
                      row['entity']! as String,
                      SyncStore.payload(row),
                    ),
            });
          }
          if (_paused) break;
          final response = await transport.push(entry.key, changes);
          final records = List<Map<String, dynamic>>.from(
            response['records'] as List,
          );
          if (response['status'] == 'conflict') {
            await store.saveConflicts(records, entry.key);
          } else if (response['status'] == 'ok' &&
              records.length == entry.value.length) {
            await store.acknowledge(records, entry.value);
          } else {
            throw const FormatException('Invalid sync response');
          }
        } catch (error) {
          errorKey = _messageFor(error);
          // One failed project must not block unrelated queued changes.
        }
      }
      if (!_paused) {
        if (groups.isNotEmpty) {
          await _pull();
        }
        if (errorKey == null) lastSynced = DateTime.now();
      }
    } catch (error) {
      errorKey = _messageFor(error);
    } finally {
      busy = false;
      if (!_disposed) await refreshStatus();
    }
  }

  Map<String, dynamic> _deletedPayload(Map<String, Object?> row) {
    final data = SyncStore.payload(row);
    if (row['entity'] == 'projects') data['imagePath'] = null;
    if (row['entity'] == 'tasks') data['attachments'] = '[]';
    return data;
  }

  Future<void> _pull() async {
    var hasMore = true;
    var changed = false;
    while (hasMore && !_paused) {
      final cursor = await store.cursor;
      final response = await transport.pull(cursor);
      final records = List<Map<String, dynamic>>.from(
        response['records'] as List,
      );
      final next = response['cursor'] as int;
      if (next < cursor || (response['has_more'] == true && next <= cursor)) {
        throw const FormatException('Invalid sync cursor');
      }
      await store.applyPull(records, next, files.localize);
      changed = changed || records.isNotEmpty;
      hasMore = response['has_more'] == true;
    }
    if (changed && !_paused) await onRemoteChanges();
  }

  Future<void> resolve(String group, {required bool keepLocal}) async {
    if (busy || _paused) return;
    final completion = Completer<void>();
    _resolving = completion.future;
    busy = true;
    errorKey = null;
    _notify();
    try {
      await store.resolve(
        group,
        keepLocal: keepLocal,
        localize: files.localize,
      );
      await onRemoteChanges();
    } catch (error) {
      errorKey = _messageFor(error);
    } finally {
      busy = false;
      await refreshStatus();
      _resolving = null;
      completion.complete();
    }
    if (errorKey == null && !_paused) await syncNow();
  }

  Future<void> pause() async {
    _paused = true;
    _debounce?.cancel();
    await _running;
    await _resolving;
  }

  static String _messageFor(Object error) {
    if (error is FirebaseAccountException) return error.messageKey;
    if (error is FirestoreSyncException) {
      if (error.code == 'ACCOUNT_DELETING') return 'accountDeletionPending';
      if (error.status == 401 || error.code == 'UNAUTHENTICATED') {
        return 'syncSignInAgain';
      }
      if (error.code == 'RESOURCE_EXHAUSTED' || error.status == 429) {
        return 'syncFreeLimit';
      }
      if (error.code == 'BATCH_TOO_LARGE') return 'syncBatchTooLarge';
      if (error.code == 'PERMISSION_DENIED') return 'syncPermissionDenied';
    }
    return 'syncRetryError';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _paused = true;
    _debounce?.cancel();
    super.dispose();
  }
}
