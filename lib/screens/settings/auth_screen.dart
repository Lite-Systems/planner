import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/settings_provider.dart';
import '../../core/services/biometric_service.dart';
import '../shell/app_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.isOverlay = false});

  final bool isOverlay;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;
  bool _hasCheckedAuth = false;

  void _goHome() {
    if (!mounted) return;
    context.read<SettingsProvider>().unlockApp();
    if (widget.isOverlay) return;
    Navigator.of(
      context,
    ).pushReplacement(NoAnimationPageRoute(builder: (_) => const AppShell()));
  }

  Future<void> _checkAuth() async {
    setState(() => _isLoading = true);
    final isAuthenticated = await _biometricService.authenticate();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (isAuthenticated) {
      _goHome();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    if (!settings.areSettingsLoaded || _hasCheckedAuth) return;
    _hasCheckedAuth = true;
    if (!settings.isBiometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        if (!settings.areSettingsLoaded || !settings.isBiometricEnabled) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        return CupertinoPageScaffold(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AppLayout.constrain(
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: AppCard.container(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.lock_shield,
                          size: 44,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'welcomeBack'.tr(),
                          textAlign: TextAlign.center,
                          style: AppText.display(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'pleaseAuthenticate'.tr(),
                          textAlign: TextAlign.center,
                          style: AppText.bodySecondary(context),
                        ),
                        const SizedBox(height: 28),
                        if (_isLoading)
                          const CupertinoActivityIndicator(radius: 12)
                        else
                          CupertinoButton.filled(
                            onPressed: _checkAuth,
                            child: Text('unlock'.tr()),
                          ),
                      ],
                    ),
                  ),
                  maxWidth: 440,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
