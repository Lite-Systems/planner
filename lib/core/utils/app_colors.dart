import 'package:flutter/cupertino.dart';

class AppColors {
  // Primary brand
  static const Color primary = Color(0xFFF97316);
  static const Color primaryLight = Color(0xFFFFB347);
  static const Color primaryDark = Color(0xFFC06000);
  static const Color primaryColor = primary;

  // Accent
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFCA5A5);
  static const Color info = Color(0xFF3B82F6);

  // Expenses module
  static const Color expensePrimary = primary;
  static const Color expenseSecondary = warning;

  // Gradients
  static const List<Color> primaryGradient = [primary, Color(0xFFFFB347)];
  static const List<Color> earningsGradient = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];
  static const List<Color> collectedGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];
  static const List<Color> pendingGradient = [
    Color(0xFFF59E0B),
    Color(0xFFFBBF24),
  ];
  static const List<Color> expenseGradient = [expensePrimary, expenseSecondary];
  static const List<Color> incomeGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];
  static const List<Color> netBalanceGradient = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];

  // Surfaces (light)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5F7FB);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Surfaces (dark)
  static const Color surfaceDark = Color(0xFF0B0E14);
  static const Color surfaceDarkAlt = Color(0xFF171E2E);
  static const Color cardDark = Color(0xFF121724);
  static const Color cardBorderDark = Color(0xFF232D42);

  // Dynamic tokens also work in const Cupertino decorations and text styles.
  static const background = CupertinoDynamicColor.withBrightness(
    color: surfaceAlt,
    darkColor: surfaceDark,
  );
  static const panel = CupertinoDynamicColor.withBrightness(
    color: surface,
    darkColor: cardDark,
  );
  static const elevated = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF1F5F9),
    darkColor: surfaceDarkAlt,
  );
  static const outline = CupertinoDynamicColor.withBrightness(
    color: cardBorder,
    darkColor: cardBorderDark,
  );
  static const label = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF172033),
    darkColor: Color(0xFFF1F5F9),
  );
  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF64748B),
    darkColor: Color(0xFF94A3B8),
  );

  // Category palette (for expense categories)
  static const List<Color> categoryPalette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFF97316),
    Color(0xFF64748B),
  ];

  static Color shadowColor(Color base, {double alpha = 0.15}) =>
      base.withValues(alpha: alpha);

  static bool isDark(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark;

  static Color backgroundColor(BuildContext context) =>
      background.resolveFrom(context);

  static Color cardBackground(BuildContext context) =>
      panel.resolveFrom(context);

  static Color elevatedBackground(BuildContext context) =>
      elevated.resolveFrom(context);

  static Color separator(BuildContext context) => outline.resolveFrom(context);

  static Color secondaryLabel(BuildContext context) =>
      muted.resolveFrom(context);

  static Color cardShadow(BuildContext context) =>
      CupertinoColors.black.withValues(alpha: isDark(context) ? 0.35 : 0.06);
}
