import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

class CurrencyService {
  static const String _apiUri = 'https://open.er-api.com/v6/latest/USD';

  /// Fetches the latest USD exchange rates for EGP and SAR.
  /// Returns a Map with the rates, or null if the request fails.
  static Future<Map<String, double>?> fetchLatestRates({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;

    try {
      // Bound the whole operation, not only DNS/TCP connection setup. A server
      // that stalls on headers or the response body must not leave refresh busy.
      return await _fetch(client).timeout(timeout);
    } catch (e) {
      log('CurrencyService refresh failed: ${e.runtimeType}');
    } finally {
      client.close(force: true);
    }
    return null;
  }

  static Future<Map<String, double>?> _fetch(HttpClient client) async {
    final request = await client.getUrl(Uri.parse(_apiUri));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      log('CurrencyService API error: HTTP status ${response.statusCode}');
      return null;
    }
    final data = jsonDecode(await response.transform(utf8.decoder).join());
    if (data is! Map ||
        data['result'] != 'success' ||
        data['base_code'] != 'USD' ||
        data['rates'] is! Map) {
      return null;
    }
    final rates = data['rates'] as Map;
    final egp = rates['EGP'];
    final sar = rates['SAR'];
    if (egp is! num ||
        sar is! num ||
        !egp.isFinite ||
        !sar.isFinite ||
        egp <= 0 ||
        sar <= 0) {
      return null;
    }
    return {'EGP': egp.toDouble(), 'SAR': sar.toDouble()};
  }
}
