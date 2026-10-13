import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/screens/expenses/add_expense_screen.dart';
import 'package:planner/screens/expenses/expenses_screen.dart';
import 'package:planner/screens/home/home_screen.dart';
import 'package:planner/screens/income/add_income_screen.dart';
import 'package:planner/screens/income/income_screen.dart';
import 'package:planner/screens/projects/screens/projects_screen.dart';
import 'package:planner/screens/projects/widgets/project_dialog.dart';
import 'package:planner/screens/settings/settings_screen.dart';
import 'package:planner/screens/todos/todos_screen.dart';
import 'package:provider/provider.dart';

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
      return;
    }
    Navigator.of(context).push(NoAnimationPageRoute(builder: (_) => page));
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
  AppSection _section = AppSection.home;
  bool _drawerOpen = false;
  bool _didRestoreSection = false;

  /// Drives the desktop content-pane scrollbar. Scrollables inside the active
  /// page attach to it via [PrimaryScrollController].
  final ScrollController _contentScrollController = ScrollController();

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRestoreSection) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.areSettingsLoaded) return;
    _didRestoreSection = true;
    if (settings.rememberLastSection) {
      final restored = _sectionFromName(settings.lastSection);
      if (restored != null) {
        _section = restored;
      }
    }
  }

  List<AppSection> _visibleSections(SettingsProvider settings) {
    return [
      AppSection.home,
      AppSection.projects,
      if (settings.isTodosEnabled) AppSection.todos,
      AppSection.income,
      if (settings.isExpensesEnabled) AppSection.expenses,
      AppSection.settings,
    ];
  }

  AppSection? _sectionFromName(String name) {
    for (final section in AppSection.values) {
      if (section.name == name) return section;
    }
    return null;
  }

  void _goTo(AppSection section) {
    final settings = context.read<SettingsProvider>();
    if (section == AppSection.expenses && !settings.isExpensesEnabled) {
      section = AppSection.home;
    }
    if (section == AppSection.todos && !settings.isTodosEnabled) {
      section = AppSection.home;
    }
    setState(() {
      _section = section;
      _drawerOpen = false;
    });
    settings.setLastSection(section.name);
  }

  void _toggleDrawer() => setState(() => _drawerOpen = !_drawerOpen);

  void _onNewItem() {
    switch (_section) {
      case AppSection.home:
      case AppSection.projects:
        ProjectDialog.show(context);
      case AppSection.todos:
        break;
      case AppSection.income:
        Navigator.of(
          context,
        ).push(NoAnimationPageRoute(builder: (_) => const AddIncomeScreen()));
      case AppSection.expenses:
        if (context.read<SettingsProvider>().isExpensesEnabled) {
          Navigator.of(context).push(
            NoAnimationPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        }
      case AppSection.settings:
        break;
    }
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(List<AppSection> sections) {
    final map = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_drawerOpen) _toggleDrawer();
      },
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _onNewItem,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): _onNewItem,
    };
    final digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    for (var i = 0; i < sections.length && i < digits.length; i++) {
      final section = sections[i];
      map[SingleActivator(digits[i], meta: true)] = () => _goTo(section);
      map[SingleActivator(digits[i], control: true)] = () => _goTo(section);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final flags = context
        .select<SettingsProvider, (bool, bool, bool, bool, bool)>(
          (s) => (
            s.isExpensesEnabled,
            s.isTodosEnabled,
            s.compactSidebar,
            s.keyboardShortcuts,
            s.areSettingsLoaded,
          ),
        );
    final showExpenses = flags.$1;
    final showTodos = flags.$2;
    final compactSidebar = flags.$3;
    final keyboardShortcuts = flags.$4;
    final sections = _visibleSections(context.read<SettingsProvider>());
    var current = _section;
    if (current == AppSection.expenses && !showExpenses) {
      current = AppSection.home;
    }
    if (current == AppSection.todos && !showTodos) {
      current = AppSection.home;
    }
    final scope = AppShellScope(
      section: current,
      embedded: layout.hasSidebar,
      goTo: _goTo,
      child: layout.hasSidebar
          ? _buildWide(
              section: current,
              compactSidebar: compactSidebar,
              showExpenses: showExpenses,
              showTodos: showTodos,
              expanded: layout.isExpanded,
            )
          : _buildCompact(),
    );

    if (!keyboardShortcuts) return scope;

    return CallbackShortcuts(
      bindings: _shortcuts(sections),
      child: Focus(autofocus: true, child: scope),
    );
  }

  Widget _buildCompact() {
    return Stack(
      children: [
        HomeScreen(onMenuTap: _toggleDrawer),
        if (_drawerOpen)
          GestureDetector(
            onTap: _toggleDrawer,
            child: Container(
              color: CupertinoColors.black.withValues(alpha: 0.45),
            ),
          ),
        _buildDrawer(),
      ],
    );
  }

  Widget _buildWide({
    required AppSection section,
    required bool compactSidebar,
    required bool showExpenses,
    required bool showTodos,
    required bool expanded,
  }) {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Row(
        children: [
          RepaintBoundary(
            child: _Sidebar(
              section: section,
              compact: compactSidebar,
              showExpenses: showExpenses,
              showTodos: showTodos,
              onSelect: _goTo,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(expanded ? 16 : 0),
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(expanded ? 18 : 0),
                  child: ColoredBox(
                    color: AppColors.cardBackground(context),
                    child: PrimaryScrollController(
                      controller: _contentScrollController,
                      child: CupertinoScrollbar(
                        controller: _contentScrollController,
                        thumbVisibility: true,
                        thickness: 7,
                        thicknessWhileDragging: 9,
                        radius: const Radius.circular(4),
                        child: KeyedSubtree(
                          key: ValueKey(section),
                          child: _pageFor(section, expanded),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageFor(AppSection section, bool expanded) {
    switch (section) {
      case AppSection.home:
        return const HomeScreen();
      case AppSection.projects:
        return ProjectsScreen(embedded: expanded);
      case AppSection.todos:
        return const TodosScreen();
      case AppSection.income:
        return const IncomeScreen();
      case AppSection.expenses:
        return const ExpensesScreen();
      case AppSection.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildDrawer() {
    return AnimatedPositionedDirectional(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      start: _drawerOpen ? 0 : -280,
      top: 0,
      bottom: 0,
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context).withValues(alpha: 0.97),
          boxShadow: [
            BoxShadow(color: AppColors.cardShadow(context), blurRadius: 20),
          ],
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SafeArea(
              child: Column(
                children: [
                  _drawerHeader(),
                  const SizedBox(height: 20),
                  _drawerItem(
                    icon: FontAwesomeIcons.house,
                    title: 'home'.tr(),
                    onTap: () => _goTo(AppSection.home),
                  ),
                  _drawerItem(
                    icon: FontAwesomeIcons.briefcase,
                    title: 'projects'.tr(),
                    onTap: () {
                      _toggleDrawer();
                      Navigator.of(context).push(
                        NoAnimationPageRoute(
                          builder: (_) => const ProjectsScreen(),
                        ),
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (_, settings, _) => settings.isTodosEnabled
                        ? _drawerItem(
                            icon: FontAwesomeIcons.listCheck,
                            title: 'todos'.tr(),
                            onTap: () {
                              _toggleDrawer();
                              Navigator.of(context).push(
                                NoAnimationPageRoute(
                                  builder: (_) => const TodosScreen(),
                                ),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  _drawerItem(
                    icon: FontAwesomeIcons.moneyBillTrendUp,
                    title: 'income'.tr(),
                    onTap: () {
                      _toggleDrawer();
                      Navigator.of(context).push(
                        NoAnimationPageRoute(
                          builder: (_) => const IncomeScreen(),
                        ),
                      );
                    },
                  ),
                  Consumer<SettingsProvider>(
                    builder: (_, settings, _) => settings.isExpensesEnabled
                        ? _drawerItem(
                            icon: FontAwesomeIcons.receipt,
                            title: 'expenses'.tr(),
                            onTap: () {
                              _toggleDrawer();
                              Navigator.of(context).push(
                                NoAnimationPageRoute(
                                  builder: (_) => const ExpensesScreen(),
                                ),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  _drawerItem(
                    icon: FontAwesomeIcons.gear,
                    title: 'settings'.tr(),
                    onTap: () {
                      _toggleDrawer();
                      Navigator.of(context).push(
                        NoAnimationPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'v 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryLabel(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.drawerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(
              FontAwesomeIcons.checkToSlot,
              color: CupertinoColors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'appName'.tr(),
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required FaIconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile(
      leading: FaIcon(icon, size: 20, color: CupertinoColors.systemGrey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.compact,
    required this.showExpenses,
    required this.showTodos,
    required this.onSelect,
  });

  final AppSection section;
  final bool compact;
  final bool showExpenses;
  final bool showTodos;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(AppSection, FaIconData, String)>[
      (AppSection.home, FontAwesomeIcons.house, 'home'.tr()),
      (AppSection.projects, FontAwesomeIcons.briefcase, 'projects'.tr()),
      if (showTodos)
        (AppSection.todos, FontAwesomeIcons.listCheck, 'todos'.tr()),
      (AppSection.income, FontAwesomeIcons.moneyBillTrendUp, 'income'.tr()),
      if (showExpenses)
        (AppSection.expenses, FontAwesomeIcons.receipt, 'expenses'.tr()),
      (AppSection.settings, FontAwesomeIcons.gear, 'settings'.tr()),
    ];

    return Container(
      width: compact ? 76 : 240,
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        border: BorderDirectional(
          end: BorderSide(color: AppColors.separator(context), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 20, 8, 16),
              child: compact
                  ? const FaIcon(
                      FontAwesomeIcons.checkToSlot,
                      color: AppColors.primary,
                    )
                  : Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.checkToSlot,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'appName'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            for (final item in items)
              _SidebarItem(
                icon: item.$2,
                label: item.$3,
                selected: section == item.$1,
                compact: compact,
                onTap: () => onSelect(item.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? CupertinoTheme.of(context).primaryColor
        : AppColors.secondaryLabel(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? CupertinoTheme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.12)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: compact
              ? FaIcon(icon, size: 18, color: color)
              : Row(
                  children: [
                    FaIcon(icon, size: 16, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
