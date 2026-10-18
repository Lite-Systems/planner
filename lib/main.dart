import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:upgrader/upgrader.dart';

import 'core/utils/app_layout.dart';
import 'core/utils/app_thems.dart';
import 'providers/settings_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/project_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/expenses_provider.dart';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/services/notification_service.dart';
import 'core/services/macos_widget_service.dart';
import 'screens/splash/splash_screen.dart';
import 'core/widgets/restart_widget.dart';
import 'core/widgets/app_lock_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _configureDesktopDatabase();
  } catch (e) {
    log('Desktop database configuration failed: $e');
  }
  try {
    await EasyLocalization.ensureInitialized();
  } catch (e) {
    log('Localization initialization failed: $e');
  }

  runApp(
    RestartWidget(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => ProjectProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ExpensesProvider()),
          ChangeNotifierProvider(create: (_) => IncomeProvider()),
          Provider(
            lazy: false,
            create: (context) => MacosWidgetService(
              settings: context.read<SettingsProvider>(),
              projects: context.read<ProjectProvider>(),
            ),
            dispose: (_, service) => service.dispose(),
          ),
        ],
        child: ProviderWiring(
          child: EasyLocalization(
            supportedLocales: const [Locale('ar'), Locale('en')],
            path: 'assets/translations',
            fallbackLocale: const Locale('ar'),
            child: const PlannerApp(),
          ),
        ),
      ),
    ),
  );

  // Nothing but settings/locale restore runs before the first frame; local
  // notifications and (via the USD widget) the rate fetch start once the first
  // frame is on screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeBackgroundServices());
  });
}

/// Cross-provider wiring that must live below [MultiProvider] and above every
/// screen. Lives here — not in a screen — because side effects must survive
/// section changes (e.g. the app opening straight into Projects, where Home
/// was never built).
///
/// [RestartWidget] recreates this widget along with the providers, so wiring
/// always targets the current notifier instances after a restart.
class ProviderWiring extends StatefulWidget {
  const ProviderWiring({super.key, required this.child});

  final Widget child;

  @override
  State<ProviderWiring> createState() => _ProviderWiringState();
}

class _ProviderWiringState extends State<ProviderWiring> {
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    final projects = Provider.of<ProjectProvider>(context, listen: false);
    final income = Provider.of<IncomeProvider>(context, listen: false);
    final expenses = Provider.of<ExpensesProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    // Paying a task creates the matching income record; unpaying removes it.
    projects.onTaskPaidChanged = (task, isPaid) async {
      if (isPaid) {
        await income.addIncomeFromTask(task, settings.currency);
      } else {
        await income.removeIncomeForTask(task.id);
      }
    };
    // Wallet balances follow income/expense changes via a SQL-grouped cache.
    income.addListener(() => unawaited(wallet.refreshFlowTotals()));
    expenses.addListener(() => unawaited(wallet.refreshFlowTotals()));
    // Load every provider in parallel after the first frame; each notifies its
    // listeners when ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future.wait([
          wallet.loadData(),
          projects.loadData(),
          expenses.loadData(),
          income.loadData(),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// sqflite only ships sqlite3 bindings for Android/iOS (via sqflite_android and
/// sqflite_darwin). On Windows and Linux the database layer is a no-op unless
/// the FFI backend is initialized before the first query.
///
/// The FFI factory defaults its databases path to `.dart_tool/...` relative
/// to the *current working directory* — fine for tests, wrong for a shipped
/// app. Pin it to the per-user application support directory instead.
Future<void> _configureDesktopDatabase() async {
  if (kIsWeb) return;
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    await databaseFactory.setDatabasesPath(dir.path);
  }
}

Future<void> _initializeBackgroundServices() async {
  // Local notifications only; the app no longer depends on Firebase/FCM.
  try {
    await NotificationService().init();
  } catch (e) {
    log('Notification initialization failed: $e');
  }
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final app = CupertinoApp(
      title: 'appName'.tr(),
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? AppThems.darkTheme() : AppThems.lightTheme(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: const SplashScreen(),
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => AppLayoutHost(
        child: AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    );

    // The in-app update prompt does not function on macOS here; skip it there
    // while keeping it on the platforms that support it.
    if (!kIsWeb && Platform.isMacOS) return app;

    return UpgradeAlert(dialogStyle: UpgradeDialogStyle.cupertino, child: app);
  }
}
