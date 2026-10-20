import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_thems.dart';
import 'package:planner/models/expense.dart';
import 'package:planner/models/income.dart';
import 'package:planner/models/payment_method.dart';
import 'package:planner/models/project.dart';
import 'package:planner/models/project_task.dart';
import 'package:planner/models/sticky_note.dart';
import 'package:planner/providers/expenses_provider.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:planner/providers/locale_provider.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/sticky_notes_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/screens/home/home_screen.dart';
import 'package:planner/screens/home/widgets/usd_rate_widget.dart';
import 'package:planner/screens/projects/screens/projects_screen.dart';
import 'package:planner/screens/shell/app_shell.dart';
import 'package:planner/screens/income/add_income_screen.dart';
import 'package:planner/screens/expenses/add_expense_screen.dart';
import 'package:planner/screens/expenses/expense_categories_screen.dart';
import 'package:planner/screens/income/income_categories_screen.dart';
import 'package:planner/screens/projects/screens/add_task_screen.dart';
import 'package:planner/screens/projects/screens/project_detail_screen.dart';
import 'package:planner/screens/settings/archive_screen.dart';
import 'package:planner/screens/settings/payment_methods_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureKey = ValueKey('dashboard-capture');
const _captureDirectory = String.fromEnvironment('DASHBOARD_CAPTURE_DIR');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Almarai')
      ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'));
    await font.load();
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await icons.load();
    for (final (family, asset) in [
      (
        'packages/font_awesome_flutter/FontAwesomeSolid',
        'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
      ),
      (
        'packages/font_awesome_flutter/FontAwesomeRegular',
        'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
      ),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  for (final (width, dark, language, scale, platform) in [
    (320.0, false, 'en', 1.0, TargetPlatform.android),
    (390.0, true, 'ar', 1.0, TargetPlatform.iOS),
    (768.0, false, 'ar', 1.0, TargetPlatform.macOS),
    (1440.0, true, 'ar', 1.0, TargetPlatform.windows),
    (375.0, true, 'ar', 1.6, TargetPlatform.android),
  ]) {
    testWidgets(
      'dashboard fits $width/$language/${dark ? 'dark' : 'light'}/text $scale',
      (tester) async {
        await _pumpDashboard(
          tester,
          width: width,
          dark: dark,
          language: language,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('dashboard-metric-wallet')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('dashboard-metric-pending')),
          findsOneWidget,
        );
        final wallet = tester.getRect(
          find.byKey(const ValueKey('dashboard-metric-wallet')),
        );
        final balance = tester.getRect(
          find.byKey(const ValueKey('dashboard-metric-balance')),
        );
        if (width >= 900) {
          expect(wallet.top, balance.top);
        } else {
          expect(balance.top, greaterThan(wallet.top));
        }
        expect(find.byKey(const ValueKey('module-top-bar')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('dashboard-wide-columns')),
          width >= 1040 ? findsOneWidget : findsNothing,
        );

        // Capture the first screen for visual inspection with the real bundled font.
        if (_captureDirectory.isNotEmpty &&
            scale == 1 &&
            (width == 390 || width == 1440)) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(_captureKey),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$_captureDirectory/planner-dashboard-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -1600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Working on dashboard'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets('privacy hides every amount and hides exchange rates', (
    tester,
  ) async {
    final settings = await _pumpDashboard(tester, width: 390);
    expect(find.text('+USD 120.00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-privacy')));
    await tester.pumpAndSettle();
    expect(settings.hideAmounts, isTrue);
    expect(find.byType(UsdRateWidget), findsNothing);
    final amounts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => RegExp(r'(USD|EGP|SAR)\s*[0-9]').hasMatch(text));
    expect(amounts, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (width, language, scale, platform) in [
    (320.0, 'en', 1.6, TargetPlatform.android),
    (390.0, 'ar', 1.0, TargetPlatform.iOS),
    (375.0, 'ar', 1.6, TargetPlatform.android),
    (600.0, 'en', 1.0, TargetPlatform.macOS),
    (900.0, 'en', 1.0, TargetPlatform.macOS),
    (1440.0, 'ar', 1.0, TargetPlatform.windows),
  ]) {
    testWidgets('top navigation fits every module $width/$language/$scale', (
      tester,
    ) async {
      final settings = await _pumpDashboard(
        tester,
        width: width,
        language: language,
        scale: scale,
        dark: true,
        shell: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('dashboard-bottom-nav')), findsNothing);
      expect(find.byKey(const ValueKey('desktopSidebar')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('app-brand-icon'))),
        const Size(24, 24),
      );
      expect(
        find.byKey(const ValueKey('app-brand-name')),
        platform == TargetPlatform.macOS || platform == TargetPlatform.windows
            ? findsNothing
            : findsOneWidget,
      );
      for (final section in AppSection.values) {
        await tester.tap(find.byKey(ValueKey('module-${section.name}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: section.name);
        expect(find.byKey(const ValueKey('module-top-bar')), findsOneWidget);
        expect(find.byKey(ValueKey(section)), findsOneWidget);
        if (scale == 1 && (width == 390 || width == 1440)) {
          await _capture(tester, '${section.name}-${width.toInt()}');
        }
        for (var i = 0; i < 4; i++) {
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isEmpty) break;
          await tester.drag(scrolls.first, const Offset(0, -700));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${section.name} scrolled',
          );
        }
      }
      await tester.tap(find.byKey(const ValueKey('app-privacy')));
      await tester.pumpAndSettle();
      expect(settings.hideAmounts, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets(
    'module bar remains available in an editor and shortcuts change modules',
    (tester) async {
      final settings = await _pumpDashboard(tester, width: 1280);
      await settings.setRememberLastSection(true);
      await tester.tap(find.byKey(const ValueKey('module-income')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pumpAndSettle();
      expect(find.byType(AddIncomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('module-top-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(AddIncomeScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('module-projects')));
      await tester.pumpAndSettle();
      expect(find.byType(AddIncomeScreen), findsNothing);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('lastSection'),
        'projects',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(AppSection.settings)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('restores the last module, resizes an editor and handles back', (
    tester,
  ) async {
    await _pumpDashboard(
      tester,
      width: 1280,
      remember: true,
      lastSection: 'income',
    );
    expect(find.byKey(const ValueKey(AppSection.income)), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(AddIncomeScreen));
    tester.view.physicalSize = const Size(320, 950);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(AddIncomeScreen)), same(state));
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AddIncomeScreen), findsNothing);
    expect(find.byKey(const ValueKey(AppSection.income)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'disabled modules are removed and saved disabled selection falls back home',
    (tester) async {
      await _pumpDashboard(
        tester,
        width: 390,
        remember: true,
        lastSection: 'expenses',
        expensesEnabled: false,
        todosEnabled: false,
      );
      expect(find.byKey(const ValueKey('module-expenses')), findsNothing);
      expect(find.byKey(const ValueKey('module-todos')), findsNothing);
      expect(find.byKey(const ValueKey(AppSection.home)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final (width, language, scale) in [
    (375.0, 'ar', 1.3),
    (1280.0, 'en', 1.0),
  ]) {
    testWidgets('secondary screens and editors fit $width/$language', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        width: width,
        language: language,
        dark: true,
        scale: scale,
      );
      final navigator = tester.state<NavigatorState>(
        find
            .descendant(
              of: find.byType(AppShell),
              matching: find.byType(Navigator),
            )
            .first,
      );
      final project = _Projects(false).projects.first;
      for (final page in <Widget>[
        const AddIncomeScreen(),
        const AddExpenseScreen(),
        const IncomeCategoriesScreen(),
        const ExpenseCategoriesScreen(),
        const PaymentMethodsScreen(),
        const TaskArchiveScreen(),
        ProjectDetailScreen(project: project),
        const AddTaskScreen(projectId: 'p1'),
      ]) {
        navigator.push(CupertinoPageRoute<void>(builder: (_) => page));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: page.runtimeType.toString(),
        );
        expect(find.byKey(const ValueKey('module-top-bar')), findsOneWidget);
        await _capture(tester, '${page.runtimeType}-${width.toInt()}');
        for (var i = 0; i < 5; i++) {
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isEmpty) break;
          await tester.drag(scrolls.first, const Offset(0, -650));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} scrolled',
          );
        }
        navigator.pop();
        await tester.pumpAndSettle();
      }
      navigator.push(
        CupertinoPageRoute<void>(builder: (_) => const PaymentMethodsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('USD 10480.04'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('app-privacy')));
      await tester.pumpAndSettle();
      expect(find.text('USD 10480.04'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'mobile navigation opens Projects and empty dashboard stays usable',
    (tester) async {
      await _pumpDashboard(tester, width: 390, empty: true);
      expect(tester.takeException(), isNull);
      expect(find.text('0%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('module-projects')));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<SettingsProvider> _pumpDashboard(
  WidgetTester tester, {
  required double width,
  bool dark = false,
  String language = 'en',
  double scale = 1,
  bool empty = false,
  bool shell = true,
  bool remember = false,
  String lastSection = 'home',
  bool expensesEnabled = true,
  bool todosEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'currency': 'USD',
    'expensesCurrency': 'USD',
    'usdToEgp': 50.0,
    'usdToSar': 3.75,
    'lastRatesUpdate': DateTime.now().toString(),
    'isDarkMode': dark,
    'rememberLastSection': remember,
    'lastSection': lastSection,
    'isExpensesEnabled': expensesEnabled,
    'isTodosEnabled': todosEnabled,
  });
  await EasyLocalization.ensureInitialized();
  tester.view.physicalSize = Size(width, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = SettingsProvider();
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider<IncomeProvider>(create: (_) => _Income(empty)),
        ChangeNotifierProvider<ExpensesProvider>(
          create: (_) => _Expenses(empty),
        ),
        ChangeNotifierProvider<ProjectProvider>(
          create: (_) => _Projects(empty),
        ),
        ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallet(empty)),
        ChangeNotifierProvider<StickyNotesProvider>(
          create: (_) => _StickyNotes(empty),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: Locale(language),
        path: 'assets/translations',
        assetLoader: _Translations(),
        child: Builder(
          builder: (context) => CupertinoApp(
            theme: dark ? AppThems.darkTheme() : AppThems.lightTheme(),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            scrollBehavior: const AppScrollBehavior(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: _captureKey,
              child: AppLayoutHost(
                child: shell ? const AppShell() : const HomeScreen(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDirectory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$_captureDirectory/planner-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Translations extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _Income extends IncomeProvider {
  _Income(this.empty);
  final bool empty;
  @override
  List<Income> get incomes => empty
      ? []
      : [
          Income(
            id: 'i1',
            title:
                'Design system implementation with a deliberately long title',
            amount: 120,
            date: DateTime(2026, 10, 18),
            categoryId: 'work',
            currency: 'USD',
          ),
          Income(
            id: 'i2',
            title: 'API integration',
            amount: 2500,
            date: DateTime(2026, 10, 17),
            categoryId: 'work',
            currency: 'EGP',
          ),
        ];
  @override
  List<Income> recentIncomes([int count = 5]) => incomes.take(count).toList();
}

class _Expenses extends ExpensesProvider {
  _Expenses(this.empty);
  final bool empty;
  @override
  List<Expense> get expenses => empty
      ? []
      : [
          Expense(
            id: 'e1',
            title: 'Design tools subscription',
            amount: 20,
            date: DateTime(2026, 10, 18),
            categoryId: 'tools',
            currency: 'USD',
          ),
        ];
  @override
  List<Expense> recentExpenses([int count = 5]) =>
      expenses.take(count).toList();
}

class _Wallet extends WalletProvider {
  _Wallet(this.empty);
  final bool empty;
  @override
  List<PaymentMethod> get paymentMethods => empty
      ? []
      : [
          PaymentMethod(
            id: 'w1',
            name: 'Freelance wallet with a long display name',
            color: 0xFFF97316,
            icon: 0xe8cc,
          ),
        ];
  @override
  double balanceFor(
    PaymentMethod method, {
    required SettingsProvider settings,
  }) => 10480.04;
}

class _StickyNotes extends StickyNotesProvider {
  _StickyNotes(this.empty);
  final bool empty;
  @override
  List<StickyNote> get notes => empty
      ? []
      : [
          StickyNote(
            id: 'n1',
            content: 'Remember the client call tomorrow at 10am',
            colorIndex: 0,
            createdAt: DateTime(2026, 10, 20),
            updatedAt: DateTime(2026, 10, 20),
          ),
        ];
}

class _Projects extends ProjectProvider {
  _Projects(this.empty);
  final bool empty;
  @override
  Future<void> loadTasks(String projectId) async {}
  @override
  List<Project> get projects => empty
      ? []
      : [
          Project(
            id: 'p1',
            name: 'Smart Planner',
            description: '',
            customer: 'Lite Systems',
          ),
        ];
  @override
  List<ProjectTask> getTasks(String projectId) => empty
      ? []
      : [
          ProjectTask(
            id: 't1',
            projectId: 'p1',
            name: 'Working on dashboard',
            details: '',
            attachments: [],
            startDate: DateTime(2026, 10, 18),
            cost: 286,
            currency: 'USD',
            isTimerRunning: true,
            timeSpentInSeconds: 5400,
          ),
        ];
  @override
  int get totalTasksCount => empty ? 0 : 12;
  @override
  int get completedTasksCount => empty ? 0 : 9;
  @override
  int get pendingTasksCount => 0;
  @override
  int get inProgressTasksCount => empty ? 0 : 3;
}
