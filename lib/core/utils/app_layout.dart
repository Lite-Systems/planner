import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

class AppLayout {
  static const compactMax = 600.0;
  static const mediumMax = 1024.0;
  static const maxContentWidth = 1100.0;
  static const formMaxWidth = 560.0;
  static const sheetMaxWidth = 480.0;

  final double width;

  const AppLayout(this.width);

  factory AppLayout.of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLayoutScope>();
    if (scope != null) return scope.layout;
    return AppLayout(MediaQuery.sizeOf(context).width);
  }

  bool get isCompact => width < compactMax;
  bool get isMedium => width >= compactMax && width < mediumMax;
  bool get isExpanded => width >= mediumMax;
  bool get isDesktop => !isCompact;

  static Widget constrain(Widget child, {double maxWidth = formMaxWidth}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : double.infinity,
            ),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );
      },
    );
  }

  static Widget sheet(BuildContext context, Widget child) {
    if (AppLayout.of(context).isCompact) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: sheetMaxWidth),
        child: child,
      ),
    );
  }
}

/// Rebuilds on every window resize, but only notifies dependents when the
/// breakpoint class changes — so desktop drag-resize does not rebuild the app.
class AppLayoutHost extends StatelessWidget {
  const AppLayoutHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppLayoutScope(
      layout: AppLayout(MediaQuery.sizeOf(context).width),
      child: child,
    );
  }
}

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({super.key, required this.layout, required super.child});

  final AppLayout layout;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      layout.isDesktop != oldWidget.layout.isDesktop ||
      layout.isExpanded != oldWidget.layout.isExpanded;
}

class AppScrollBehavior extends CupertinoScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return const ClampingScrollPhysics();
      default:
        return super.getScrollPhysics(context);
    }
  }
}
