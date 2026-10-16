import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/settings/auth_screen.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || !mounted) return;
    context.read<SettingsProvider>().lockApp();
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.select<SettingsProvider, bool>(
      (s) => s.isAppLocked,
    );
    return Stack(
      fit: StackFit.expand,
      children: [widget.child, if (locked) const AuthScreen(isOverlay: true)],
    );
  }
}
