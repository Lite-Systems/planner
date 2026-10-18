import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/services/macos_widget_service.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_thems.dart';
import 'package:planner/providers/expenses_provider.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:planner/providers/locale_provider.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/screens/settings/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('widget activation failures stay off and show a readable message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('smart_planner/macos_widget');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'prepare') {
        throw PlatformException(
          code: 'widget_app_group_unavailable',
          message:
              'Sign Runner and PlannerWidget with the same Apple team and App Groups capability.',
        );
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final settings = SettingsProvider();
    final projects = ProjectProvider();
    await tester.pump();
    final service = MacosWidgetService(settings: settings, projects: projects);
    addTearDown(service.dispose);
    addTearDown(settings.dispose);
    addTearDown(projects.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: projects),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => IncomeProvider()),
          ChangeNotifierProvider(create: (_) => ExpensesProvider()),
          Provider.value(value: service),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: const Locale('en'),
          path: 'assets/translations',
          assetLoader: _Translations(),
          child: Builder(
            builder: (context) => CupertinoApp(
              theme: AppThems.lightTheme(),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const AppLayoutHost(child: SettingsScreen()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.text('macosWidget'.tr());
    await tester.scrollUntilVisible(title, 400);
    final tile = find.ancestor(
      of: title,
      matching: find.byType(CupertinoListTile),
    );
    final toggle = find.descendant(
      of: tile,
      matching: find.byType(CupertinoSwitch),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.macosWidgetEnabled, isFalse);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.text('macosWidgetUnavailable'.tr()), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('ok'.tr()));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));
}

class _Translations extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}
