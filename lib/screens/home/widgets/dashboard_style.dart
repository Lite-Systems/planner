import 'package:flutter/cupertino.dart';

import '../../../core/utils/app_tokens.dart';
import '../../../core/utils/app_colors.dart';

abstract final class DashboardStyle {
  static const orange = AppColors.primary;
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const indigo = Color(0xFF818CF8);

  static bool dark(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark;
  static Color background(BuildContext context) =>
      AppColors.backgroundColor(context);
  static Color surface(BuildContext context) =>
      AppColors.cardBackground(context);
  static Color elevated(BuildContext context) =>
      AppColors.elevatedBackground(context);
  static Color border(BuildContext context) => AppColors.separator(context);
  static Color label(BuildContext context) =>
      AppColors.label.resolveFrom(context);
  static Color muted(BuildContext context) => AppColors.secondaryLabel(context);
  static TextStyle text(
    BuildContext context, {
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) => TextStyle(
    fontFamily: AppText.family,
    fontSize: size,
    fontWeight: weight,
    color: color ?? label(context),
  );
}

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: DashboardStyle.surface(context),
      border: Border.all(color: DashboardStyle.border(context)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}
