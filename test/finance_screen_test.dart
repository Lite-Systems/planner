import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_thems.dart';
import 'package:planner/models/income.dart';
import 'package:planner/models/expense.dart';
import 'package:planner/models/expense_category.dart';
import 'package:planner/providers/expenses_provider.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/screens/expenses/expenses_screen.dart';
import 'package:planner/screens/expenses/widgets/expense_summary_chart.dart';
import 'package:planner/screens/income/income_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final screen in [const IncomeScreen(), const ExpensesScreen()]) {
    testWidgets(
      '${screen.runtimeType} builds and responds to settings changes',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider();
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider(create: (_) => IncomeProvider()),
              ChangeNotifierProvider(create: (_) => ExpensesProvider()),
              ChangeNotifierProvider(create: (_) => WalletProvider()),
            ],
            child: CupertinoApp(home: AppLayoutHost(child: screen)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await settings.setHideAmounts(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final screen in [const IncomeScreen(), const ExpensesScreen()]) {
    testWidgets(
      '${screen.runtimeType} renders saved records on desktop',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'currency': 'SAR',
          'expensesCurrency': 'USD',
          'usdToEgp': 50.0,
          'usdToSar': 4.0,
        });
        await EasyLocalization.ensureInitialized();
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
              ChangeNotifierProvider<IncomeProvider>(
                create: (_) => _SavedIncomes(),
              ),
              ChangeNotifierProvider<ExpensesProvider>(
                create: (_) => _SavedExpenses(),
              ),
              ChangeNotifierProvider(create: (_) => WalletProvider()),
            ],
            child: EasyLocalization(
              supportedLocales: const [Locale('en'), Locale('ar')],
              assetLoader: _FinanceTranslations(),
              startLocale: const Locale('en'),
              path: 'assets/translations',
              child: Builder(
                builder: (context) => CupertinoApp(
                  theme: AppThems.lightTheme(),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  scrollBehavior: const AppScrollBehavior(),
                  home: AppLayoutHost(child: screen),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Saved payment'), findsOneWidget);
        if (screen is ExpensesScreen) {
          final chart = tester.widget<ExpenseSummaryChart>(
            find.byType(ExpenseSummaryChart),
          );
          expect(chart.currency, 'USD');
          expect(chart.total, closeTo(2, 0.001));
          expect(chart.expensesByCategory, {'software': 2.0});
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }),
    );
  }
}

class _FinanceTranslations extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _SavedIncomes extends IncomeProvider {
  @override
  List<Income> get incomes => [
    Income(
      id: 'income',
      title: 'Saved payment',
      amount: 120,
      date: DateTime(2026, 10, 18),
      categoryId: 'software',
    ),
  ];
}

class _SavedExpenses extends ExpensesProvider {
  @override
  List<ExpenseCategory> get categories => [
    ExpenseCategory(
      id: 'software',
      name: 'Software',
      color: 0xFF6366F1,
      icon: 0xe3b7,
    ),
  ];
  @override
  List<Expense> get expenses => [
    Expense(
      id: 'expense',
      title: 'Saved payment',
      amount: 50,
      date: DateTime(2026, 10, 18),
      categoryId: 'software',
      paymentMethodId: 'missing-wallet',
    ),
    Expense(
      id: 'usd-expense',
      title: 'Second expense',
      amount: 1,
      date: DateTime(2026, 10, 18),
      categoryId: 'software',
      currency: 'USD',
    ),
  ];
}
