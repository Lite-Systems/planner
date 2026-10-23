import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/providers/account_provider.dart';
import 'package:planner/screens/account/account_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final (width, lang) in [(390.0, 'ar'), (1280.0, 'en')]) {
    testWidgets(
      'Account screen offers sign-in and registration at $width/$lang',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final account = AccountProvider();
        addTearDown(account.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: account,
            child: EasyLocalization(
              supportedLocales: const [Locale('en'), Locale('ar')],
              startLocale: Locale(lang),
              path: 'assets/translations',
              assetLoader: _Translations(),
              child: Builder(
                builder: (context) => CupertinoApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: const AppLayoutHost(child: AccountScreen()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final translations =
            jsonDecode(
                  File('assets/translations/$lang.json').readAsStringSync(),
                )
                as Map;
        expect(
          find.text(translations['accountSignIn'] as String),
          findsNWidgets(2),
        );
        expect(
          find.text(translations['accountGuestInfo'] as String),
          findsOneWidget,
        );
        await tester.tap(find.text(translations['accountRegister'] as String));
        await tester.pumpAndSettle();
        expect(
          find.text(translations['accountConfirmPassword'] as String),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Translations extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      Map<String, dynamic>.from(
        jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
            as Map,
      );
}
