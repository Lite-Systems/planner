import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../providers/expenses_provider.dart';
import '../../../providers/income_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';
import 'dashboard_style.dart';

class HomeSummaryCards extends StatelessWidget {
  const HomeSummaryCards({
    super.key,
    this.onWalletTap,
    this.onPendingTap,
    this.onIncomeTap,
    this.onBalanceTap,
  });
  final VoidCallback? onWalletTap;
  final VoidCallback? onPendingTap;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onBalanceTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 280
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: Consumer2<WalletProvider, SettingsProvider>(
              builder: (_, wallet, settings, _) => _MetricCard(
                id: 'wallet',
                title: 'wallet'.tr(),
                subtitle: 'dashboardTotalValue'.tr(),
                amount: wallet.paymentMethods.fold(
                  0,
                  (sum, m) => sum + wallet.balanceFor(m, settings: settings),
                ),
                settings: settings,
                color: DashboardStyle.orange,
                icon: CupertinoIcons.square_stack_3d_up,
                onTap: onWalletTap,
              ),
            ),
          ),
          SizedBox(
            width: width,
            child: Consumer2<ProjectProvider, SettingsProvider>(
              builder: (_, projects, settings, _) {
                var pending = 0.0;
                for (final project in projects.projects) {
                  for (final task in projects.getTasks(project.id)) {
                    if (!task.isArchived && !task.isPaid) {
                      pending += settings.convert(task.cost, task.currency);
                    }
                  }
                }
                return _MetricCard(
                  id: 'pending',
                  title: 'pendingPayment'.tr(),
                  subtitle: 'dashboardAwaitingCollection'.tr(),
                  amount: pending,
                  settings: settings,
                  color: DashboardStyle.amber,
                  icon: CupertinoIcons.clock,
                  onTap: onPendingTap,
                );
              },
            ),
          ),
          SizedBox(
            width: width,
            child: Consumer2<IncomeProvider, SettingsProvider>(
              builder: (_, income, settings, _) => _MetricCard(
                id: 'income',
                title: 'totalIncome'.tr(),
                subtitle: 'dashboardAllIncome'.tr(),
                amount: income.incomes.fold(
                  0,
                  (sum, e) => sum + settings.convert(e.amount, e.currency),
                ),
                settings: settings,
                color: DashboardStyle.emerald,
                icon: CupertinoIcons.arrow_up_right,
                onTap: onIncomeTap,
              ),
            ),
          ),
          SizedBox(
            width: width,
            child:
                Consumer3<IncomeProvider, ExpensesProvider, SettingsProvider>(
                  builder: (_, income, expenses, settings, _) {
                    final received = income.incomes.fold<double>(
                      0,
                      (sum, e) => sum + settings.convert(e.amount, e.currency),
                    );
                    final spent = expenses.expenses.fold<double>(
                      0,
                      (sum, e) => sum + settings.convert(e.amount, e.currency),
                    );
                    return _MetricCard(
                      id: 'balance',
                      title: 'netBalance'.tr(),
                      subtitle: 'dashboardIncomeLessExpenses'.tr(),
                      amount: received - spent,
                      settings: settings,
                      color: DashboardStyle.indigo,
                      icon: CupertinoIcons.chart_bar_alt_fill,
                      onTap: onBalanceTap,
                    );
                  },
                ),
          ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.settings,
    required this.color,
    required this.icon,
    this.onTap,
  });
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final SettingsProvider settings;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = DashboardStyle.dark(context);
    final accent = dark
        ? Color.lerp(color, CupertinoColors.white, 0.18)!
        : Color.lerp(color, CupertinoColors.black, 0.18)!;
    return CupertinoButton(
      key: ValueKey('dashboard-metric-$id'),
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Color.alphaBlend(
                color.withValues(alpha: dark ? 0.10 : 0.06),
                DashboardStyle.surface(context),
              ),
              DashboardStyle.surface(context),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: dark ? 0.34 : 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DashboardStyle.text(
                      context,
                      size: 12,
                      weight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  settings.formatMoney(amount),
                  textDirection: TextDirection.ltr,
                  style: DashboardStyle.text(
                    context,
                    size: 20,
                    weight: FontWeight.w800,
                    color: id == 'income' || id == 'balance'
                        ? accent
                        : DashboardStyle.label(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
