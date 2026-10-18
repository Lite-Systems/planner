import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/utils/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the UI font resolves to the bundled regular Almarai face', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final family = manifest.cast<Map<String, dynamic>>().where(
      (entry) => entry['family'] == AppText.family,
    );
    expect(family, hasLength(1), reason: 'Avoid platform fallback fonts.');
    final faces = family.single['fonts'] as List<dynamic>;
    expect(faces, contains(containsPair('weight', 400)));
    await rootBundle.load('assets/fonts/Almarai-Regular.ttf');
  });
}
