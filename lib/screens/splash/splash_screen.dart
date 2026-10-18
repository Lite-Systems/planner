import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:planner/providers/locale_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/screens/settings/auth_screen.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToNext());
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currentLocale = context.locale;
    final navigator = Navigator.of(context);
    final started = DateTime.now();
    while (!settings.areSettingsLoaded &&
        DateTime.now().difference(started) < const Duration(seconds: 3)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    final nextLocale = localeProvider.locale;
    if (mounted && nextLocale != null && nextLocale != currentLocale) {
      await context.setLocale(nextLocale);
    }
    if (!mounted) return;
    navigator.pushReplacement(
      NoAnimationPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.square_grid_2x2,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'appName'.tr(),
                textAlign: TextAlign.center,
                style: AppText.display(context),
              ),
              const SizedBox(height: 10),
              Text(
                'trackYourWealth'.tr(),
                textAlign: TextAlign.center,
                style: AppText.bodySecondary(context),
              ),
              const SizedBox(height: 32),
              const CupertinoActivityIndicator(radius: 10),
            ],
          ),
        ),
      ),
    ),
  );
}
