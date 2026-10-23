import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';

final plannerNavigatorKey = GlobalKey<NavigatorState>();

class AccountGuard extends StatefulWidget {
  const AccountGuard({super.key, required this.child});
  final Widget child;
  @override
  State<AccountGuard> createState() => _AccountGuardState();
}

class _AccountGuardState extends State<AccountGuard> {
  bool _offered = false;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final locked = settings.isAppLocked || settings.requiresInitialUnlock;
    if (!account.switching && !locked && account.importAvailable && !_offered) {
      _offered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final dialogContext = plannerNavigatorKey.currentContext;
        if (!mounted || dialogContext == null) return;
        final import = await showCupertinoDialog<bool>(
          context: dialogContext,
          builder: (context) => CupertinoAlertDialog(
            title: Text('accountImportTitle'.tr()),
            content: Text('accountImportMessage'.tr()),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text('accountKeepSeparate'.tr()),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                child: Text('accountImport'.tr()),
              ),
            ],
          ),
        );
        if (!mounted || import == null) return;
        await account.decideImport(
          import: import,
          guestPreferences: await SettingsProvider.guestPreferences(),
        );
      });
    }
    return Stack(
      children: [
        widget.child,
        if (account.switching || account.errorKey == 'accountSwitchFailed')
          Positioned.fill(
            child: ColoredBox(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(height: 12),
                    Text('accountSwitching'.tr()),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
