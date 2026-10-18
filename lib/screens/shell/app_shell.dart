import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/app_layout.dart';
import '../../core/utils/app_tokens.dart';
import '../../core/utils/no_animation_route.dart';
import '../../providers/settings_provider.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expenses_screen.dart';
import '../home/home_screen.dart';
import '../income/add_income_screen.dart';
import '../income/income_screen.dart';
import '../projects/screens/projects_screen.dart';
import '../projects/widgets/project_dialog.dart';
import '../settings/settings_screen.dart';
import '../todos/todos_screen.dart';

enum AppSection { home, projects, todos, income, expenses, settings }

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.section,
    required this.embedded,
    required this.goTo,
    required super.child,
  });

  final AppSection section;
  final bool embedded;
  final ValueChanged<AppSection> goTo;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  static void open(BuildContext context, AppSection section, Widget page) {
    final scope = maybeOf(context);
    if (scope != null && scope.embedded) {
      scope.goTo(section);
    } else {
      Navigator.of(context).push(NoAnimationPageRoute(builder: (_) => page));
    }
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      section != oldWidget.section || embedded != oldWidget.embedded;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppSection _section = AppSection.home;
  bool _didRestoreSection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    if (_didRestoreSection || !settings.areSettingsLoaded) return;
    _didRestoreSection = true;
    if (settings.rememberLastSection) {
      _section = AppSection.values.firstWhere(
        (section) => section.name == settings.lastSection,
        orElse: () => AppSection.home,
      );
    }
  }

  List<AppSection> _sections(SettingsProvider settings) => [
    AppSection.home,
    AppSection.projects,
    if (settings.isTodosEnabled) AppSection.todos,
    AppSection.income,
    if (settings.isExpensesEnabled) AppSection.expenses,
    AppSection.settings,
  ];

  void _goTo(AppSection section) {
    final sections = _sections(context.read<SettingsProvider>());
    if (!sections.contains(section)) section = AppSection.home;
    // Module changes close detail routes, not the shell. The top bar therefore
    // remains available from editors and on phones, without a drawer or rail.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (_section == section) return;
    setState(() => _section = section);
    context.read<SettingsProvider>().setLastSection(section.name);
  }

  void _newItem() {
    final pageContext = _navigatorKey.currentState?.overlay?.context;
    if (pageContext == null) return;
    switch (_section) {
      case AppSection.home:
      case AppSection.projects:
        ProjectDialog.show(pageContext);
      case AppSection.income:
        _navigatorKey.currentState!.push(
          NoAnimationPageRoute(builder: (_) => const AddIncomeScreen()),
        );
      case AppSection.expenses:
        if (context.read<SettingsProvider>().isExpensesEnabled) {
          _navigatorKey.currentState!.push(
            NoAnimationPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        }
      case AppSection.todos:
      case AppSection.settings:
        break;
    }
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(List<AppSection> sections) {
    final result = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          _navigatorKey.currentState?.maybePop(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newItem,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newItem,
    };
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      result[SingleActivator(digits[i], meta: true)] = () => _goTo(section);
      result[SingleActivator(digits[i], control: true)] = () => _goTo(section);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final sections = _sections(settings);
    final current = sections.contains(_section) ? _section : AppSection.home;
    Widget shell = AppShellScope(
      section: current,
      embedded: true,
      goTo: _goTo,
      child: ColoredBox(
        color: AppColors.backgroundColor(context),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ModuleBar(section: current, sections: sections, onSelect: _goTo),
              Expanded(
                child: NavigatorPopHandler(
                  onPopWithResult: (_) => _navigatorKey.currentState!.pop(),
                  child: Navigator(
                    key: _navigatorKey,
                    onGenerateRoute: (_) => NoAnimationPageRoute(
                      builder: (context) {
                        final selected = AppShellScope.maybeOf(
                          context,
                        )!.section;
                        return KeyedSubtree(
                          key: ValueKey(selected),
                          child: _pageFor(context, selected),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (settings.keyboardShortcuts) {
      shell = CallbackShortcuts(
        bindings: _shortcuts(sections),
        child: Focus(autofocus: true, child: shell),
      );
    }
    return shell;
  }

  Widget _pageFor(BuildContext context, AppSection section) =>
      switch (section) {
        AppSection.home => const HomeScreen(),
        AppSection.projects => ProjectsScreen(
          embedded: AppLayout.of(context).isExpanded,
        ),
        AppSection.todos => const TodosScreen(),
        AppSection.income => const IncomeScreen(),
        AppSection.expenses => const ExpensesScreen(),
        AppSection.settings => const SettingsScreen(),
      };
}

class _ModuleBar extends StatelessWidget {
  const _ModuleBar({
    required this.section,
    required this.sections,
    required this.onSelect,
  });

  final AppSection section;
  final List<AppSection> sections;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 720;
      final labels = constraints.maxWidth >= 1100;
      final navigation = Row(
        children: [
          for (final module in sections)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _ModuleButton(
                  module: module,
                  selected: section == module,
                  showLabel: labels || narrow,
                  stacked: narrow,
                  onTap: () => onSelect(module),
                ),
              ),
            ),
        ],
      );
      return Container(
        key: const ValueKey('module-top-bar'),
        padding: EdgeInsets.fromLTRB(12, 8, 12, narrow ? 10 : 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor(context),
          border: Border(
            bottom: BorderSide(color: AppColors.separator(context)),
          ),
        ),
        child: narrow
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(child: _CompactBrand()),
                      _PrivacyButton(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  navigation,
                ],
              )
            : Row(
                children: [
                  const SizedBox(width: 170, child: _CompactBrand()),
                  const SizedBox(width: 16),
                  Expanded(child: navigation),
                  const SizedBox(width: 12),
                  _PrivacyButton(),
                ],
              ),
      );
    },
  );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        key: const ValueKey('app-brand-icon'),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          CupertinoIcons.square_grid_2x2,
          color: CupertinoColors.white,
          size: 16,
        ),
      ),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          'Smart Planner',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.cardTitle(context).copyWith(fontSize: 13),
        ),
      ),
    ],
  );
}

class _PrivacyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<SettingsProvider, bool>(
    selector: (_, settings) => settings.hideAmounts,
    builder: (context, hidden, _) => Tooltip(
      message: (hidden ? 'dashboardShowAmounts' : 'dashboardHideAmounts').tr(),
      child: CupertinoButton(
        key: const ValueKey('app-privacy'),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        onPressed: () =>
            context.read<SettingsProvider>().setHideAmounts(!hidden),
        child: Icon(
          hidden ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
          size: 19,
          color: AppColors.secondaryLabel(context),
        ),
      ),
    ),
  );
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.module,
    required this.selected,
    required this.showLabel,
    required this.stacked,
    required this.onTap,
  });

  final AppSection module;
  final bool selected;
  final bool showLabel;
  final bool stacked;
  final VoidCallback onTap;

  IconData get _icon => switch (module) {
    AppSection.home => CupertinoIcons.house,
    AppSection.projects => CupertinoIcons.briefcase,
    AppSection.todos => CupertinoIcons.checkmark_square,
    AppSection.income => CupertinoIcons.arrow_down_left,
    AppSection.expenses => CupertinoIcons.arrow_up_right,
    AppSection.settings => CupertinoIcons.gear,
  };

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : AppColors.secondaryLabel(context);
    final icon = Icon(_icon, size: 19, color: color);
    final label = Flexible(
      child: Text(
        (module == AppSection.home ? 'home' : module.name).tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption(context).copyWith(
          fontSize: stacked ? 10 : 12,
          color: color,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: (module == AppSection.home ? 'home' : module.name).tr(),
        child: CupertinoButton(
          key: ValueKey('module-${module.name}'),
          padding: EdgeInsets.zero,
          minimumSize: Size(44, stacked ? 60 : 44),
          onPressed: onTap,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: stacked ? 60 : 44),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.elevatedBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.separator(context),
              ),
            ),
            child: stacked
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [icon, const SizedBox(height: 5), label],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      if (showLabel) ...[const SizedBox(width: 8), label],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
