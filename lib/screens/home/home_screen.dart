import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/utils/no_animation_route.dart';
import '../../core/utils/timer_ticker.dart';
import '../../models/project.dart';
import '../../models/project_task.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expenses_screen.dart';
import '../income/add_income_screen.dart';
import '../income/income_screen.dart';
import '../projects/screens/project_detail_screen.dart';
import '../projects/screens/projects_screen.dart';
import '../settings/payment_methods_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/app_shell.dart';
import '../todos/todos_screen.dart';
import 'widgets/dashboard_style.dart';
import 'widgets/home_summary_cards.dart';
import 'widgets/usd_rate_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _open(AppSection section) {
    if (section == AppSection.home) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    final page = switch (section) {
      AppSection.home => const SizedBox.shrink(),
      AppSection.projects => const ProjectsScreen(),
      AppSection.todos => const TodosScreen(),
      AppSection.income => const IncomeScreen(),
      AppSection.expenses => const ExpensesScreen(),
      AppSection.settings => const SettingsScreen(),
    };
    AppShellScope.open(context, section, page);
  }

  void _openWallets() => Navigator.of(
    context,
  ).push(NoAnimationPageRoute(builder: (_) => const PaymentMethodsScreen()));
  void _openProject(Project project) => Navigator.of(context).push(
    NoAnimationPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
  );

  @override
  Widget build(BuildContext context) {
    final flags = context.select<SettingsProvider, (bool, bool, bool)>(
      (s) => (s.hideAmounts, s.isExpensesEnabled, s.isTodosEnabled),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the available pane width, not a fixed device-size assumption.
        final wide = constraints.maxWidth >= 1040;
        final gutter = constraints.maxWidth >= 700 ? 28.0 : 16.0;
        final progress = _TaskProgressCard(
          onTap: () => _open(flags.$3 ? AppSection.todos : AppSection.projects),
        );
        final income = _IncomePreview(onSeeAll: () => _open(AppSection.income));
        final expenses = _ExpensesPreview(
          onSeeAll: () => _open(AppSection.expenses),
        );
        final wallets = _WalletsSection(onSeeAll: _openWallets);

        return CupertinoPageScaffold(
          backgroundColor: DashboardStyle.background(context),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    key: const PageStorageKey('dashboard-scroll'),
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 28),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1440),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (wide && !flags.$1)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Expanded(child: _WelcomeHeader()),
                                        const SizedBox(width: 32),
                                        const Expanded(child: UsdRateWidget()),
                                      ],
                                    )
                                  else ...[
                                    const _WelcomeHeader(),
                                    if (!flags.$1) ...[
                                      const SizedBox(height: 22),
                                      const UsdRateWidget(),
                                    ],
                                  ],
                                  const SizedBox(height: 26),
                                  _SectionHeading(
                                    title: 'dashboardFinancialOverview'.tr(),
                                    subtitle: 'dashboardAutoUpdated'.tr(),
                                  ),
                                  const SizedBox(height: 12),
                                  HomeSummaryCards(
                                    onWalletTap: _openWallets,
                                    onPendingTap: () =>
                                        _open(AppSection.projects),
                                    onIncomeTap: () => _open(AppSection.income),
                                    onBalanceTap: () => _open(
                                      flags.$2
                                          ? AppSection.expenses
                                          : AppSection.income,
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  if (wide)
                                    Row(
                                      key: const ValueKey(
                                        'dashboard-wide-columns',
                                      ),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 7,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              income,
                                              if (flags.$2) ...[
                                                const SizedBox(height: 26),
                                                expenses,
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              progress,
                                              const SizedBox(height: 24),
                                              wallets,
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    progress,
                                    const SizedBox(height: 26),
                                    income,
                                    if (flags.$2) ...[
                                      const SizedBox(height: 26),
                                      expenses,
                                    ],
                                    const SizedBox(height: 26),
                                    wallets,
                                  ],
                                  _ActiveTimersSection(
                                    onOpenProject: _openProject,
                                    onSeeAll: () => _open(
                                      flags.$3
                                          ? AppSection.todos
                                          : AppSection.projects,
                                    ),
                                  ),
                                  _RecentProjectsSection(
                                    onOpenProject: _openProject,
                                    onSeeAll: () => _open(AppSection.projects),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DashboardStyle.elevated(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: DashboardStyle.border(context)),
              ),
              child: Text(
                'welcomeBack'.tr(),
                style: DashboardStyle.text(
                  context,
                  size: 11,
                  color: DashboardStyle.muted(context),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'dashboardOverview'.tr(),
              style: DashboardStyle.text(
                context,
                size: 27,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: DashboardStyle.emerald.withValues(alpha: 0.08),
          border: Border.all(
            color: DashboardStyle.emerald.withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: DashboardStyle.emerald,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'dashboardLocalWorkspace'.tr(),
              style: DashboardStyle.text(
                context,
                size: 10,
                color: DashboardStyle.dark(context)
                    ? const Color(0xFF34D399)
                    : const Color(0xFF047857),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.amount,
    this.color,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String? amount;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: DashboardStyle.text(
                context,
                size: 15,
                weight: FontWeight.w700,
              ),
            ),
            if (amount != null) ...[
              const SizedBox(height: 4),
              Text(
                amount!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: DashboardStyle.text(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 12),
      if (onSeeAll != null)
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(44, 36),
          onPressed: onSeeAll,
          child: Text(
            'viewAll'.tr(),
            style: DashboardStyle.text(
              context,
              size: 12,
              weight: FontWeight.w700,
              color: DashboardStyle.orange,
            ),
          ),
        )
      else if (subtitle != null)
        Flexible(
          child: Text(
            subtitle!,
            textAlign: TextAlign.end,
            style: DashboardStyle.text(
              context,
              size: 10,
              color: DashboardStyle.muted(context),
            ),
          ),
        ),
    ],
  );
}

class _TaskProgressCard extends StatelessWidget {
  const _TaskProgressCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(
    BuildContext context,
  ) => Selector<ProjectProvider, (int, int, int, int)>(
    selector: (_, p) => (
      p.totalTasksCount,
      p.completedTasksCount,
      p.pendingTasksCount,
      p.inProgressTasksCount,
    ),
    builder: (context, stats, _) {
      final progress = stats.$1 == 0
          ? 0.0
          : (stats.$2 / stats.$1).clamp(0.0, 1.0);
      return DashboardPanel(
        key: const ValueKey('dashboard-progress'),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'tasksProgress'.tr(),
                        style: DashboardStyle.text(
                          context,
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '\u2066${stats.$2} / ${stats.$1}\u2069 ${'tasksCompleted'.tr()}',
                        style: DashboardStyle.text(
                          context,
                          size: 11,
                          color: DashboardStyle.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(progress * 100).round()}%',
                  style: DashboardStyle.text(
                    context,
                    size: 26,
                    weight: FontWeight.w800,
                    color: DashboardStyle.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              label: 'tasksProgress'.tr(),
              value: '${(progress * 100).round()}%',
              child: Container(
                height: 10,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: DashboardStyle.elevated(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DashboardStyle.border(context)),
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [DashboardStyle.amber, DashboardStyle.orange],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    context,
                    'workingOn'.tr(),
                    stats.$4,
                    DashboardStyle.emerald,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stat(
                    context,
                    'pending'.tr(),
                    stats.$3,
                    DashboardStyle.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _stat(
                    context,
                    'totalTasks'.tr(),
                    stats.$1,
                    DashboardStyle.label(context),
                  ),
                ),
              ],
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(top: 10),
              minimumSize: const Size(44, 36),
              onPressed: onTap,
              child: Text(
                'dashboardViewTasks'.tr(),
                style: DashboardStyle.text(
                  context,
                  size: 11,
                  color: DashboardStyle.orange,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _stat(BuildContext context, String label, int value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: DashboardStyle.elevated(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: DashboardStyle.text(
                context,
                size: 17,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: DashboardStyle.text(
                context,
                size: 10,
                color: DashboardStyle.muted(context),
              ),
            ),
          ],
        ),
      );
}

class _IncomePreview extends StatelessWidget {
  const _IncomePreview({required this.onSeeAll});
  final VoidCallback onSeeAll;
  @override
  Widget build(
    BuildContext context,
  ) => Consumer2<IncomeProvider, SettingsProvider>(
    builder: (context, income, settings, _) {
      final total = income.incomes.fold<double>(
        0,
        (sum, e) => sum + settings.convert(e.amount, e.currency),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            title: 'recentIncome'.tr(),
            amount: settings.formatMoney(total),
            color: DashboardStyle.emerald,
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          if (income.incomes.isEmpty)
            _EmptyState(
              icon: CupertinoIcons.arrow_down_left,
              label: 'noIncome'.tr(),
              onTap: onSeeAll,
            )
          else
            for (final entry in income.recentIncomes(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionRow(
                  title: entry.title,
                  subtitle:
                      '${income.getCategoryById(entry.categoryId)?.name ?? 'other'.tr()} • ${DateFormat.MMMd(context.locale.toString()).format(entry.date)}',
                  amount: settings.hideAmounts
                      ? settings.formatMoney(entry.amount, entry.currency)
                      : '+${settings.formatMoney(entry.amount, entry.currency)}',
                  icon: entry.taskId == null
                      ? CupertinoIcons.arrow_down_left
                      : CupertinoIcons.briefcase,
                  color: DashboardStyle.emerald,
                  onTap: () => Navigator.of(context).push(
                    NoAnimationPageRoute(
                      builder: (_) => AddIncomeScreen(income: entry),
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class _ExpensesPreview extends StatelessWidget {
  const _ExpensesPreview({required this.onSeeAll});
  final VoidCallback onSeeAll;
  @override
  Widget build(
    BuildContext context,
  ) => Consumer2<ExpensesProvider, SettingsProvider>(
    builder: (context, expenses, settings, _) {
      final total = expenses.expenses.fold<double>(
        0,
        (sum, e) =>
            sum +
            settings.convert(e.amount, e.currency, settings.expensesCurrency),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(
            title: 'recentExpenses'.tr(),
            amount: settings.formatMoney(total, settings.expensesCurrency),
            color: DashboardStyle.orange,
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          if (expenses.expenses.isEmpty)
            _EmptyState(
              icon: CupertinoIcons.arrow_up_right,
              label: 'noExpenses'.tr(),
              onTap: onSeeAll,
            )
          else
            for (final entry in expenses.recentExpenses(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionRow(
                  title: entry.title,
                  subtitle:
                      '${expenses.getCategoryById(entry.categoryId)?.name ?? 'other'.tr()} • ${DateFormat.MMMd(context.locale.toString()).format(entry.date)}',
                  amount: settings.hideAmounts
                      ? settings.formatMoney(entry.amount, entry.currency)
                      : '−${settings.formatMoney(entry.amount, entry.currency)}',
                  icon: CupertinoIcons.arrow_up_right,
                  color: DashboardStyle.orange,
                  onTap: () => Navigator.of(context).push(
                    NoAnimationPageRoute(
                      builder: (_) => AddExpenseScreen(expense: entry),
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: DashboardPanel(
      padding: const EdgeInsets.all(13),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.20)),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DashboardStyle.text(
                      context,
                      size: 12,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DashboardStyle.text(
                      context,
                      size: 10,
                      color: DashboardStyle.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.33,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  textDirection: TextDirection.ltr,
                  style: DashboardStyle.text(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WalletsSection extends StatelessWidget {
  const _WalletsSection({required this.onSeeAll});
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) =>
      Consumer2<WalletProvider, SettingsProvider>(
        builder: (context, wallet, settings, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeading(
              title: 'dashboardYourWallets'.tr(),
              onSeeAll: onSeeAll,
            ),
            const SizedBox(height: 12),
            if (wallet.paymentMethods.isEmpty)
              _EmptyState(
                icon: CupertinoIcons.creditcard,
                label: 'dashboardNoWallets'.tr(),
                onTap: onSeeAll,
              )
            else
              DashboardPanel(
                child: Column(
                  children: [
                    for (
                      var i = 0;
                      i < wallet.paymentMethods.length && i < 3;
                      i++
                    ) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Container(
                            height: 1,
                            color: DashboardStyle.border(context),
                          ),
                        ),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.creditcard,
                            color: Color(wallet.paymentMethods[i].color),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              wallet.paymentMethods[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DashboardStyle.text(
                                context,
                                size: 12,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              settings.formatMoney(
                                wallet.balanceFor(
                                  wallet.paymentMethods[i],
                                  settings: settings,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: DashboardStyle.text(
                                context,
                                size: 12,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
}

class _ActiveTimersSection extends StatelessWidget {
  const _ActiveTimersSection({
    required this.onOpenProject,
    required this.onSeeAll,
  });
  final ValueChanged<Project> onOpenProject;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) => Consumer<ProjectProvider>(
    builder: (context, projects, _) {
      final active = projects.projects
          .expand((p) => projects.getTasks(p.id))
          .where((t) => t.isTimerRunning && !t.isArchived)
          .toList();
      if (active.isEmpty) return const SizedBox.shrink();
      final byId = {
        for (final project in projects.projects) project.id: project,
      };
      return Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeading(title: 'activeTimers'.tr(), onSeeAll: onSeeAll),
            const SizedBox(height: 12),
            for (final task in active.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DashboardPanel(
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.timer,
                        color: DashboardStyle.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => onOpenProject(byId[task.projectId]!),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DashboardStyle.text(
                                context,
                                size: 12,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 88,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _ElapsedTimer(
                            key: ValueKey(task.id),
                            task: task,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        onPressed: () =>
                            projects.toggleTaskTimer(task.id, task.projectId),
                        child: Icon(
                          CupertinoIcons.pause_circle,
                          color: DashboardStyle.orange,
                          semanticLabel: 'dashboardPauseTimer'.tr(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer({super.key, required this.task});
  final ProjectTask task;
  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  @override
  void initState() {
    super.initState();
    TimerTicker.instance.acquire();
  }

  @override
  void dispose() {
    TimerTicker.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: TimerTicker.instance.tick,
    builder: (context, _, _) {
      var seconds = widget.task.timeSpentInSeconds;
      if (widget.task.lastStartTime != null) {
        seconds += DateTime.now()
            .difference(widget.task.lastStartTime!)
            .inSeconds;
      }
      if (seconds < 0) seconds = 0;
      final label =
          '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      return Text(
        label,
        textDirection: TextDirection.ltr,
        style: DashboardStyle.text(
          context,
          size: 12,
          weight: FontWeight.w700,
          color: DashboardStyle.orange,
        ),
      );
    },
  );
}

class _RecentProjectsSection extends StatelessWidget {
  const _RecentProjectsSection({
    required this.onOpenProject,
    required this.onSeeAll,
  });
  final ValueChanged<Project> onOpenProject;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) => Consumer<ProjectProvider>(
    builder: (context, projects, _) => Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(title: 'recentProjects'.tr(), onSeeAll: onSeeAll),
          const SizedBox(height: 12),
          if (projects.projects.isEmpty)
            _EmptyState(
              icon: CupertinoIcons.briefcase,
              label: 'noProjectsYet'.tr(),
              onTap: onSeeAll,
            )
          else
            for (final project in projects.projects.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => onOpenProject(project),
                  child: DashboardPanel(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: DashboardStyle.orange.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.briefcase,
                            size: 19,
                            color: DashboardStyle.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DashboardStyle.text(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              if (project.customer?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(
                                  project.customer!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DashboardStyle.text(
                                    context,
                                    size: 11,
                                    color: DashboardStyle.muted(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${projects.getTasks(project.id).where((t) => !t.isArchived).length}',
                          style: DashboardStyle.text(
                            context,
                            weight: FontWeight.w700,
                            color: DashboardStyle.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.chevron_forward,
                          size: 14,
                          color: DashboardStyle.muted(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: DashboardPanel(
      child: Row(
        children: [
          Icon(icon, size: 22, color: DashboardStyle.muted(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: DashboardStyle.text(
                context,
                size: 12,
                color: DashboardStyle.muted(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.add_circled,
            color: DashboardStyle.orange,
            size: 22,
          ),
        ],
      ),
    ),
  );
}
