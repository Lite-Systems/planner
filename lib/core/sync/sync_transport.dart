import 'dart:convert';
import 'dart:io';

import 'firebase_auth_service.dart';
import 'firebase_config.dart';
import 'sync_store.dart';

/// Atomic commits use Firebase ID tokens and are authorized by firestore.rules.
/// Update-time preconditions serialize cloud versions without IAM-only RPCs.
class SyncTransport {
  SyncTransport(this.auth) : userId = auth.user!.id;
  final String userId;
  final FirebaseAuthService auth;
  String get _root =>
      'projects/${FirebaseConfig.projectId}/databases/(default)/documents';
  String get _owner => '$_root/plannerUsers/$userId';
  String _record(String entity, String id) =>
      '$_owner/records/${base64Url.encode(utf8.encode('$entity:$id')).replaceAll('=', '')}';

  Future<dynamic> _request(
    String method,
    String document, {
    Map<String, dynamic>? body,
  }) async {
    if (auth.user?.id != userId) {
      throw const FirebaseAccountException('SIGNED_OUT');
    }
    final token = await auth.accessToken();
    final base = FirebaseConfig.firestoreEmulator.isEmpty
        ? 'https://firestore.googleapis.com/v1'
        : 'http://${FirebaseConfig.firestoreEmulator}/v1';
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await http
          .openUrl(method, Uri.parse('$base/$document'))
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 25));
      final data = text.isEmpty ? null : jsonDecode(text);
      if (response.statusCode >= 400) {
        final error = data is Map ? data['error'] : null;
        throw FirestoreSyncException(
          response.statusCode,
          error is Map ? error['status']?.toString() ?? 'UNKNOWN' : 'UNKNOWN',
        );
      }
      return data;
    } finally {
      http.close(force: true);
    }
  }

  static Map<String, dynamic> _value(Object? value) => switch (value) {
    null => {'nullValue': null},
    bool v => {'booleanValue': v},
    int v => {'integerValue': '$v'},
    num v => {'doubleValue': v},
    String v => {'stringValue': v},
    Map v => {
      'mapValue': {
        'fields': v.map((k, v) => MapEntry(k.toString(), _value(v))),
      },
    },
    List v => {
      'arrayValue': {'values': v.map(_value).toList()},
    },
    _ => throw const FormatException('Unsupported Firestore value'),
  };
  static dynamic _decode(Map<String, dynamic> value) {
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('integerValue')) {
      return int.parse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    }
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('mapValue')) {
      return _fields(
        Map<String, dynamic>.from(
          (value['mapValue'] as Map)['fields'] as Map? ?? {},
        ),
      );
    }
    if (value.containsKey('arrayValue')) {
      return ((value['arrayValue'] as Map)['values'] as List? ?? [])
          .map((v) => _decode(Map<String, dynamic>.from(v as Map)))
          .toList();
    }
    throw const FormatException('Unsupported cloud field');
  }

  static Map<String, dynamic> _fields(Map<String, dynamic> fields) => fields
      .map((k, v) => MapEntry(k, _decode(Map<String, dynamic>.from(v as Map))));
  static Map<String, dynamic> _document(Map<String, dynamic> doc) =>
      _fields(Map<String, dynamic>.from(doc['fields'] as Map? ?? {}));
  static Map<String, dynamic> _write(
    String name,
    Map<String, dynamic> data, {
    Map<String, dynamic>? current,
  }) => {
    'update': {
      'name': name,
      'fields': data.map((k, v) => MapEntry(k, _value(v))),
    },
    'currentDocument': ?current,
  };

  Future<Map<String, Map<String, dynamic>>> _read(List<String> names) async {
    final response = await _request(
      'POST',
      '$_root:batchGet',
      body: {'documents': names},
    );
    final result = <String, Map<String, dynamic>>{};
    for (final entry in response as List) {
      if (entry is Map && entry['found'] is Map) {
        final doc = Map<String, dynamic>.from(entry['found'] as Map);
        result[doc['name'] as String] = doc;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> push(
    String group,
    List<Map<String, dynamic>> changes,
  ) async {
    if (changes.length > 400) {
      throw const FirestoreSyncException(400, 'BATCH_TOO_LARGE');
    }
    for (var attempt = 0; attempt < 4; attempt++) {
      String? observedHeadUpdateTime;
      var reachedCommit = false;
      try {
        final names = changes
            .map(
              (c) => _record(c['entity'] as String, c['record_id'] as String),
            )
            .toList();
        final docs = await _read([_owner, ...names]);
        final head = docs[_owner];
        observedHeadUpdateTime = head?['updateTime'] as String?;
        final headData = head == null ? <String, dynamic>{} : _document(head);
        if (headData['deleting'] == true) {
          throw const FirestoreSyncException(403, 'ACCOUNT_DELETING');
        }
        final current = <Map<String, dynamic>>[];
        var conflict = false;
        for (var i = 0; i < changes.length; i++) {
          final change = changes[i];
          final doc = docs[names[i]];
          final remote = doc == null
              ? {
                  'entity': change['entity'],
                  'record_id': change['record_id'],
                  'group_key': group,
                  'version': 0,
                  'deleted': true,
                  'payload': change['payload'],
                }
              : _document(doc);
          current.add(remote);
          if (remote['mutation_id'] != change['mutation_id'] &&
              remote['version'] != change['base_version']) {
            conflict = true;
          }
        }
        if (conflict) return {'status': 'conflict', 'records': current};
        var version = (headData['version'] as int?) ?? 0;
        final writes = <Map<String, dynamic>>[];
        final result = <Map<String, dynamic>>[];
        for (var i = 0; i < changes.length; i++) {
          final change = changes[i];
          final remote = current[i];
          if (remote['mutation_id'] == change['mutation_id'] ||
              (docs[names[i]] != null &&
                  remote['deleted'] == change['deleted'] &&
                  SyncStore.jsonEqual(remote['payload'], change['payload']))) {
            result.add(remote);
            continue;
          }
          final next = {...change, 'group_key': group, 'version': ++version};
          result.add(next);
          writes.add(
            _write(
              names[i],
              next,
              current: docs[names[i]] == null
                  ? {'exists': false}
                  : {'updateTime': docs[names[i]]!['updateTime']},
            ),
          );
        }
        if (writes.isEmpty) return {'status': 'ok', 'records': result};
        writes.add(
          _write(
            _owner,
            {'version': version, 'deleting': false},
            current: head == null
                ? {'exists': false}
                : {'updateTime': head['updateTime']},
          ),
        );
        reachedCommit = true;
        await _request('POST', '$_root:commit', body: {'writes': writes});
        return {'status': 'ok', 'records': result};
      } on FirestoreSyncException catch (e) {
        // Production may evaluate rules against the newer account version
        // before reporting a failed write precondition. Retry a 403 only when
        // the same user's head demonstrably changed during this commit.
        if (e.status == 403 && reachedCommit && attempt < 3) {
          final latest = (await _read([_owner]))[_owner];
          if (latest != null &&
              latest['updateTime'] != observedHeadUpdateTime) {
            if (_document(latest)['deleting'] == true) {
              throw const FirestoreSyncException(403, 'ACCOUNT_DELETING');
            }
            continue;
          }
        }
        // Another device can commit after batchGet and before commit. No write
        // is applied on a failed precondition; reread and recheck base versions.
        if ((e.status == 409 ||
                e.code == 'ABORTED' ||
                e.code == 'FAILED_PRECONDITION' ||
                e.code == 'ALREADY_EXISTS') &&
            attempt < 3) {
          continue;
        }
        rethrow;
      }
    }
    throw const FirestoreSyncException(409, 'ABORTED');
  }

  Future<Map<String, dynamic>> pull(int cursor) async {
    final docs = await _read([_owner]);
    final head = docs[_owner];
    if (head == null) {
      return {
        'records': <Map<String, dynamic>>[],
        'cursor': cursor,
        'has_more': false,
      };
    }
    final data = _document(head);
    if (data['deleting'] == true) {
      throw const FirestoreSyncException(403, 'ACCOUNT_DELETING');
    }
    if ((data['version'] as int) <= cursor) {
      return {
        'records': <Map<String, dynamic>>[],
        'cursor': cursor,
        'has_more': false,
      };
    }
    final response = await _request(
      'POST',
      '$_owner:runQuery',
      body: {
        'structuredQuery': {
          'from': [
            {'collectionId': 'records'},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'version'},
              'op': 'GREATER_THAN',
              'value': _value(cursor),
            },
          },
          'orderBy': [
            {
              'field': {'fieldPath': 'version'},
              'direction': 'ASCENDING',
            },
          ],
          'limit': 250,
        },
      },
    );
    final records = [
      for (final entry in response as List)
        if (entry is Map && entry['document'] is Map)
          _document(Map<String, dynamic>.from(entry['document'] as Map)),
    ];
    final next = records.isEmpty
        ? (data['version'] as int)
        : records.last['version'] as int;
    return {
      'records': records,
      'cursor': next,
      'has_more': records.length == 250,
    };
  }

  Future<List<Map<String, dynamic>>> group(
    String group,
    List<Map<String, Object?>> pending,
  ) async {
    final response = await _request(
      'POST',
      '$_owner:runQuery',
      body: {
        'structuredQuery': {
          'from': [
            {'collectionId': 'records'},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'group_key'},
              'op': 'EQUAL',
              'value': _value(group),
            },
          },
        },
      },
    );
    final records = [
      for (final entry in response as List)
        if (entry is Map && entry['document'] is Map)
          _document(Map<String, dynamic>.from(entry['document'] as Map)),
    ];
    for (final row in pending.where((r) => r['group_key'] == group)) {
      if (!records.any(
        (r) =>
            r['entity'] == row['entity'] && r['record_id'] == row['record_id'],
      )) {
        records.add({
          'entity': row['entity'],
          'record_id': row['record_id'],
          'group_key': group,
          'version': 0,
          'deleted': true,
          'payload': SyncStore.payload(row),
        });
      }
    }
    return records;
  }

  Future<void> deleteCloudData() async {
    final existing = await _read([_owner]);
    final head = existing[_owner];
    if (head == null || _document(head)['deleting'] != true) {
      await _request(
        'POST',
        '$_root:commit',
        body: {
          'writes': [
            _write(
              _owner,
              {
                'version': head == null ? 0 : _document(head)['version'],
                'deleting': true,
              },
              current: head == null
                  ? {'exists': false}
                  : {'updateTime': head['updateTime']},
            ),
          ],
        },
      );
    }
    while (true) {
      final response = await _request(
        'POST',
        '$_owner:runQuery',
        body: {
          'structuredQuery': {
            'from': [
              {'collectionId': 'records'},
            ],
            'limit': 400,
          },
        },
      );
      final documents = [
        for (final entry in response as List)
          if (entry is Map && entry['document'] is Map)
            entry['document'] as Map,
      ];
      if (documents.isEmpty) break;
      await _request(
        'POST',
        '$_root:commit',
        body: {
          'writes': [
            for (final doc in documents) {'delete': doc['name']},
          ],
        },
      );
    }
    // Keep a minimal deletion marker to block another device's unexpired JWT.
  }
}

class FirestoreSyncException implements Exception {
  const FirestoreSyncException(this.status, this.code);
  final int status;
  final String code;
}
