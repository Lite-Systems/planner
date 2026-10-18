import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/currency_service.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('macOS sandbox allows outbound API requests in every build', () {
    for (final configuration in ['DebugProfile', 'Release']) {
      expect(
        File('macos/Runner/$configuration.entitlements').readAsStringSync(),
        matches(
          RegExp('<key>com.apple.security.network.client</key>\\s*<true\\s*/>'),
        ),
        reason:
            '$configuration blocks exchange-rate HTTPS without network.client',
      );
    }
  });

  test('valid USD response supplies both supported rates', () async {
    final client = _Client(
      body: jsonEncode({
        'result': 'success',
        'base_code': 'USD',
        'rates': {'EGP': 53.46, 'SAR': 3.75},
      }),
    );
    expect(await _fetch(client), {'EGP': 53.46, 'SAR': 3.75});
    expect(
      client.requested.toString(),
      'https://open.er-api.com/v6/latest/USD',
    );
    expect(client.closed, isTrue);
  });

  for (final body in [
    'not-json',
    '{"result":"error"}',
    '{"result":"success","base_code":"USD","rates":{"EGP":0,"SAR":3.75}}',
    '{"result":"success","base_code":"USD","rates":{"EGP":53}}',
    '{"result":"success","base_code":"EUR","rates":{"EGP":60,"SAR":4}}',
    '{"result":"success","base_code":"USD","rates":{"EGP":1e999,"SAR":3.75}}',
  ]) {
    test('invalid or wrong-base rates are rejected: $body', () async {
      expect(await _fetch(_Client(body: body)), isNull);
    });
  }

  test('HTTP rate limiting returns no replacement rates', () async {
    expect(await _fetch(_Client(status: 429)), isNull);
  });

  for (final stallBody in [false, true]) {
    test(
      'stalled ${stallBody ? 'body' : 'headers'} times out and closes the connection',
      () async {
        final client = _Client(stallHeaders: !stallBody, stallBody: stallBody);
        expect(
          await HttpOverrides.runZoned(
            () => CurrencyService.fetchLatestRates(
              timeout: const Duration(milliseconds: 30),
            ),
            createHttpClient: (_) => client,
          ).timeout(const Duration(seconds: 1)),
          isNull,
        );
        expect(client.closed, isTrue);
      },
    );
  }

  test(
    'offline refresh preserves saved rates and timestamp and releases busy state',
    () async {
      SharedPreferences.setMockInitialValues({
        'usdToEgp': 51.0,
        'usdToSar': 3.74,
        'lastRatesUpdate': '2026-10-17 10:00',
      });
      final settings = SettingsProvider();
      addTearDown(settings.dispose);
      await HttpOverrides.runZoned(
        settings.fetchAndSaveRates,
        createHttpClient: (_) => _Client(status: 503),
      );
      expect(settings.usdToEgp, 51);
      expect(settings.usdToSar, 3.74);
      expect(settings.lastRatesUpdate, '2026-10-17 10:00');
      expect(settings.ratesRefreshFailed, isTrue);
      expect(settings.isFetchingRates, isFalse);
      expect((await SharedPreferences.getInstance()).getDouble('usdToEgp'), 51);
    },
  );

  test(
    'success persists rates; concurrent and fresh automatic refreshes do not repeat requests',
    () async {
      final settings = SettingsProvider();
      addTearDown(settings.dispose);
      var connections = 0;
      await HttpOverrides.runZoned(
        () async {
          await Future.wait(
            List.generate(5, (_) => settings.fetchAndSaveRates()),
          );
          expect(connections, 1);
          expect(settings.ratesRefreshFailed, isFalse);
          expect(settings.isFetchingRates, isFalse);
          expect(settings.usdToEgp, 53.46);
          expect(settings.lastRatesUpdate, isNotEmpty);
          await settings.refreshRatesIfNeeded();
          expect(connections, 1);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getDouble('usdToEgp'), 53.46);
          expect(prefs.getString('lastRatesUpdate'), settings.lastRatesUpdate);
        },
        createHttpClient: (_) {
          connections++;
          return _Client(
            body:
                '{"result":"success","base_code":"USD","rates":{"EGP":53.46,"SAR":3.75}}',
          );
        },
      );
    },
  );

  test('stale rates refresh automatically after settings have loaded', () async {
    SharedPreferences.setMockInitialValues({
      'lastRatesUpdate': '2020-01-01 10:00',
    });
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    final client = _Client(
      body:
          '{"result":"success","base_code":"USD","rates":{"EGP":53.46,"SAR":3.75}}',
    );
    await HttpOverrides.runZoned(
      settings.refreshRatesIfNeeded,
      createHttpClient: (_) => client,
    );
    expect(client.requested, isNotNull);
    expect(settings.usdToEgp, 53.46);
  });
}

Future<Map<String, double>?> _fetch(_Client client) => HttpOverrides.runZoned(
  () => CurrencyService.fetchLatestRates(),
  createHttpClient: (_) => client,
);

class _Client extends Fake implements HttpClient {
  _Client({
    this.body = '',
    this.status = 200,
    this.stallHeaders = false,
    this.stallBody = false,
  });
  final String body;
  final int status;
  final bool stallHeaders;
  final bool stallBody;
  Uri? requested;
  bool closed = false;

  @override
  set connectionTimeout(Duration? value) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    return _Request(
      stallHeaders
          ? Completer<HttpClientResponse>().future
          : Future.value(_Response(body, status, stallBody)),
    );
  }

  @override
  void close({bool force = false}) => closed = true;
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final Future<HttpClientResponse> response;
  @override
  Future<HttpClientResponse> close() async => response;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body, this.statusCode, this.stallBody);
  final String body;
  final bool stallBody;
  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      (stallBody
              ? Stream<List<int>>.fromFuture(Completer<List<int>>().future)
              : Stream.value(utf8.encode(body)))
          .listen(
            onData,
            onError: onError,
            onDone: onDone,
            cancelOnError: cancelOnError,
          );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
