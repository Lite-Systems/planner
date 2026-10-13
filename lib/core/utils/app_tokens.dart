/// Design tokens — the single source of truth for radii, spacing, elevation
/// and typography. Screens should consume these instead of hand-rolling
/// values, so the app keeps one consistent visual language across mobile
/// and desktop.
///
/// Token styles that depend on brightness take a [BuildContext] so dark mode
/// is resolved at call sites.
library;

import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

// ── Radius ───────────────────────────────────────────────────────────────────

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

// ── Spacing ──────────────────────────────────────────────────────────────────

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal screen gutter for content that isn't inside [AppLayout].
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: 16);
}

// ── Typography ───────────────────────────────────────────────────────────────

abstract final class AppText {
  static const String family = 'Almarai';

  /// Page-level display ("Dashboard overview").
  static TextStyle display(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: _label(context),
  );

  /// Section titles ("Recent projects").
  static TextStyle sectionTitle(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: _label(context),
  );

  /// Card headings ("Tasks progress").
  static TextStyle heading(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _label(context),
  );

  /// Card titles ("Recent income").
  static TextStyle cardTitle(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _label(context),
  );

  /// Primary body copy.
  static TextStyle body(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: _label(context),
  );

  /// Supporting copy inside cards.
  static TextStyle bodySecondary(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryLabel(context),
  );

  /// Timestamps, badges, metadata.
  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryLabel(context),
  );

  /// Micro labels (10px).
  static TextStyle micro(BuildContext context) => TextStyle(
    fontFamily: family,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryLabel(context),
  );

  /// Money amounts (emphasized, tabular figures for stable width).
  static TextStyle amount(BuildContext context, Color color) => TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color,
  );

  static Color _label(BuildContext context) =>
      CupertinoColors.label.resolveFrom(context);
}

// ── Elevation ────────────────────────────────────────────────────────────────

abstract final class AppShadows {
  /// Standard single soft shadow for surface cards. Replaces the 1–2 ad-hoc
  /// shadow layers used across screens.
  static List<BoxShadow> card(BuildContext context, {Color? tint}) => [
    BoxShadow(
      color: tint ?? AppColors.cardShadow(context),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Stronger shadow for emphasized hero cards (colored gradient cards).
  static List<BoxShadow> hero(Color tint, {double alpha = 0.28}) => [
    BoxShadow(
      color: tint.withValues(alpha: alpha),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

// ── Card decoration ──────────────────────────────────────────────────────────

abstract final class AppCard {
  /// Standard surface card: background, hairline border, one soft shadow.
  static BoxDecoration container(
    BuildContext context, {
    double radius = AppRadius.xl,
    Color? color,
    List<BoxShadow>? shadows,
    BoxBorder? border,
  }) => BoxDecoration(
    color: color ?? AppColors.cardBackground(context),
    borderRadius: BorderRadius.circular(radius),
    border:
        border ?? Border.all(color: AppColors.separator(context), width: 0.5),
    boxShadow: shadows ?? AppShadows.card(context),
  );
}

// ── Interaction ──────────────────────────────────────────────────────────────

/// Tap target with desktop-appropriate cursor feedback. Wrap every custom
/// GestureDetector row/card so mouse users get a pointer cursor — a plain
/// GestureDetector shows the default arrow and feels dead on desktop.
class AppClickable extends StatelessWidget {
  const AppClickable({
    super.key,
    required this.onTap,
    required this.child,
    this.cursor = SystemMouseCursors.click,
  });

  final GestureTapCallback? onTap;
  final Widget child;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}
