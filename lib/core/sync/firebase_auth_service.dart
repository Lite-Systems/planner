import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_config.dart';

class AccountUser {
  const AccountUser({required this.id, required this.email});
  final String id;
  final String email;
}

/// Firebase's public REST API works on Windows as well as mobile/macOS, without
/// relying on the FlutterFire Windows SDK's development-only support.
class FirebaseAuthService extends ChangeNotifier {
  FirebaseAuthService({
    this.storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  });
  final FlutterSecureStorage storage;
  static final instance = FirebaseAuthService();
  Map<String, dynamic>? _session;
  Future<String>? _refreshing;
  int _generation = 0;
  String? initializationError;
  AccountUser? get user => _session == null
      ? null
      : AccountUser(
          id: _session!['localId'] as String,
          email: _session!['email'] as String,
        );
  String get _storageKey =>
      'planner.firebase.${FirebaseConfig.projectId}.session';

  Future<void> initialize() async {
    if (!FirebaseConfig.configured) return;
    try {
      final value = await storage.read(key: _storageKey);
      if (value != null) {
        final data = Map<String, dynamic>.from(jsonDecode(value) as Map);
        if (data['localId'] is String &&
            data['email'] is String &&
            data['idToken'] is String &&
            data['refreshToken'] is String &&
            data['expiresAt'] is int) {
          _session = data;
        }
      }
    } catch (_) {
      initializationError = 'accountSetupFailed';
    }
  }

  Uri _authUri(String method) => Uri.parse(
    FirebaseConfig.authEmulator.isEmpty
        ? 'https://identitytoolkit.googleapis.com/v1/accounts:$method?key=${FirebaseConfig.apiKey}'
        : 'http://${FirebaseConfig.authEmulator}/identitytoolkit.googleapis.com/v1/accounts:$method?key=${FirebaseConfig.apiKey}',
  );

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> body, {
    bool form = false,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = form
          ? ContentType('application', 'x-www-form-urlencoded')
          : ContentType.json;
      request.write(
        form
            ? Uri(
                queryParameters: body.map((k, v) => MapEntry(k, v.toString())),
              ).query
            : jsonEncode(body),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 25));
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (response.statusCode >= 400) {
        final error = data['error'];
        throw FirebaseAccountException(
          error is Map
              ? (error['message']?.toString() ?? 'AUTH_ERROR')
              : 'AUTH_ERROR',
        );
      }
      return data;
    } on SocketException {
      throw const FirebaseAccountException('NETWORK_ERROR');
    } on TimeoutException {
      throw const FirebaseAccountException('NETWORK_ERROR');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> authenticate(
    String email,
    String password, {
    required bool register,
  }) async {
    if (!FirebaseConfig.configured) {
      throw const FirebaseAccountException('NOT_CONFIGURED');
    }
    final response = await _post(
      _authUri(register ? 'signUp' : 'signInWithPassword'),
      {'email': email.trim(), 'password': password, 'returnSecureToken': true},
    );
    await _save({
      'localId': response['localId'],
      'email': response['email'] ?? email.trim(),
      'idToken': response['idToken'],
      'refreshToken': response['refreshToken'],
      'expiresAt':
          DateTime.now().millisecondsSinceEpoch +
          int.parse(response['expiresIn'].toString()) * 1000,
    });
    _generation++;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _post(_authUri('sendOobCode'), {
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }

  Future<String> accessToken() async {
    if (_session == null) throw const FirebaseAccountException('SIGNED_OUT');
    if ((_session!['expiresAt'] as int) >
        DateTime.now().millisecondsSinceEpoch + 60000) {
      return _session!['idToken'] as String;
    }
    if (_refreshing != null) return _refreshing!;
    final future = _refresh();
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<String> _refresh() async {
    final generation = _generation;
    final previous = Map<String, dynamic>.from(_session!);
    final uri = Uri.parse(
      FirebaseConfig.authEmulator.isEmpty
          ? 'https://securetoken.googleapis.com/v1/token?key=${FirebaseConfig.apiKey}'
          : 'http://${FirebaseConfig.authEmulator}/securetoken.googleapis.com/v1/token?key=${FirebaseConfig.apiKey}',
    );
    final response = await _post(uri, {
      'grant_type': 'refresh_token',
      'refresh_token': previous['refreshToken'],
    }, form: true);
    if (_generation != generation || _session == null) {
      throw const FirebaseAccountException('SIGNED_OUT');
    }
    await _save({
      ...previous,
      'idToken': response['id_token'],
      'refreshToken': response['refresh_token'],
      'expiresAt':
          DateTime.now().millisecondsSinceEpoch +
          int.parse(response['expires_in'].toString()) * 1000,
    });
    return response['id_token'] as String;
  }

  Future<void> _save(Map<String, dynamic> session) async {
    await storage.write(key: _storageKey, value: jsonEncode(session));
    _session = session;
  }

  Future<void> signOut() async {
    _generation++;
    await storage.delete(key: _storageKey);
    _session = null;
    notifyListeners();
  }

  Future<void> deleteUser() async {
    await _post(_authUri('delete'), {'idToken': await accessToken()});
    await signOut();
  }
}

class FirebaseAccountException implements Exception {
  const FirebaseAccountException(this.code);
  final String code;
  String get messageKey {
    final code = this.code.split(' : ').first;
    return switch (code) {
      'EMAIL_EXISTS' => 'accountEmailExists',
      'INVALID_EMAIL' || 'MISSING_EMAIL' => 'accountInvalidEmail',
      'INVALID_LOGIN_CREDENTIALS' ||
      'EMAIL_NOT_FOUND' ||
      'INVALID_PASSWORD' => 'accountInvalidCredentials',
      'WEAK_PASSWORD' => 'accountWeakPassword',
      'TOO_MANY_ATTEMPTS_TRY_LATER' => 'accountTooManyAttempts',
      'OPERATION_NOT_ALLOWED' ||
      'CONFIGURATION_NOT_FOUND' ||
      'API_KEY_INVALID' => 'accountProviderDisabled',
      'NETWORK_ERROR' => 'accountNetworkError',
      'TOKEN_EXPIRED' ||
      'INVALID_ID_TOKEN' ||
      'USER_DISABLED' ||
      'USER_NOT_FOUND' ||
      'SIGNED_OUT' => 'syncSignInAgain',
      'CREDENTIAL_TOO_OLD_LOGIN_AGAIN' => 'accountRecentLoginRequired',
      _ => 'accountSignInFailed',
    };
  }
}
