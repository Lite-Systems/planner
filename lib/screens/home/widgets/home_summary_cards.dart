import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/providers/expenses_provider.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:provider/provider.dart';

/// Home dashboard summary: net balance, income, expenses, pending, wallet.
///
/// Rebuild granularity matters here: each card subscribes only to the
/// providers it reads, so an expense change doesn't rebuild the income card
/// (and vice versa). The row skeleton only rebuilds when the *structure*
/// changes (expenses toggled, wallets added/removed).
class HomeSummaryCards extends StatelessWidget {
  const HomeSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Selector2<SettingsProvider, WalletProvider, (bool, bool)>(
      selector: (_, settings, wallet) =>
          (settings.isExpensesEnabled, wallet.paymentMethods.isNotEmpty),
      builder: (context, value, _) {
        final showExpenses = value.$1;
        final hasWallets = value.$2;

        final cards = <Widget>[
          const _NetBalanceCard(),
          const _IncomeTotalCard(),
          if (showExpenses) const _ExpenseTotalCard(),
          const _PendingTotalCard(),
          if (hasWallets) const _WalletTotalCard(),
        ];

        if (layout.hasSidebar) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: layout.isExpanded ? 240 : 200,
                    height: 132,
                    child: card,
                  ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => cards[i],
          ),
        );
      },
    );
  }
}

// ── Card data + shell ────────────────────────────────────────────────────────

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.amount,
    required this.currency,
    required this.colors,
    required this.icon,
  });

  final String title;
  final double amount;
  final String currency;
  final List<Color> colors;
  final FaIconData icon;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      width: 200,
      height: 132,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Color.lerp(data.colors[0], const Color(0xFF000000), 0.25)!,
                  Color.lerp(data.colors[1], const Color(0xFF000000), 0.15)!,
                ]
              : data.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: data.colors[0].withValues(alpha: isDark ? 0.35 : 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FaIcon(
                data.icon,
                color: CupertinoColors.white.withValues(alpha: 0.85),
                size: 16,
              ),
            ],
          ),
          Text(
            context.read<SettingsProvider>().formatMoney(
              data.amount,
              data.currency,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-card widgets, each with scoped subscriptions ─────────────────────────

class _NetBalanceCard extends StatelessWidget {
  const _NetBalanceCard();

  @override
  Widget build(BuildContext context) {
    return Consumer3<IncomeProvider, ExpensesProvider, SettingsProvider>(
      builder: (_, income, expenses, settings, _) {
        final incomeTotal = income.incomes.fold<double>(
          0,
          (sum, e) => sum + settings.convert(e.amount, e.currency),
        );
        final expenseTotal = expenses.expenses.fold<double>(
          0,
          (sum, e) => sum + settings.convert(e.amount, e.currency),
        );
        return _SummaryCard(
          data: _SummaryCardData(
            title: 'netBalance'.tr(),
            amount: incomeTotal - expenseTotal,
            currency: settings.currency,
            colors: AppColors.netBalanceGradient,
            icon: FontAwesomeIcons.scaleBalanced,
          ),
        );
      },
    );
  }
}

class _IncomeTotalCard extends StatelessWidget {
  const _IncomeTotalCard();

  @override
  Widget build(BuildContext context) {
    return Consumer2<IncomeProvider, SettingsProvider>(
      builder: (_, income, settings, _) {
        final incomeTotal = income.incomes.fold<double>(
          0,
          (sum, e) => sum + settings.convert(e.amount, e.currency),
        );
        return _SummaryCard(
          data: _SummaryCardData(
            title: 'totalIncome'.tr(),
            amount: incomeTotal,
            currency: settings.currency,
            colors: AppColors.incomeGradient,
            icon: FontAwesomeIcons.arrowTrendUp,
          ),
        );
      },
    );
  }
}

class _ExpenseTotalCard extends StatelessWidget {
  const _ExpenseTotalCard();

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpensesProvider, SettingsProvider>(
      builder: (_, expenses, settings, _) {
        final expenseTotal = expenses.expenses.fold<double>(
          0,
          (sum, e) => sum + settings.convert(e.amount, e.currency),
        );
        return _SummaryCard(
          data: _SummaryCardData(
            title: 'totalExpenses'.tr(),
            amount: expenseTotal,
            currency: settings.currency,
            colors: AppColors.expenseGradient,
            icon: FontAwesomeIcons.arrowTrendDown,
          ),
        );
      },
    );
  }
}

class _PendingTotalCard extends StatelessWidget {
  const _PendingTotalCard();

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProjectProvider, SettingsProvider>(
      builder: (_, projects, settings, _) {
        var pending = 0.0;
        for (final project in projects.projects) {
          for (final task in projects.getTasks(project.id)) {
            if (task.isArchived || task.isPaid) continue;
            pending += settings.convert(task.cost, task.currency);
          }
        }
        return _SummaryCard(
          data: _SummaryCardData(
            title: 'pendingPayment'.tr(),
            amount: pending,
            currency: settings.currency,
            colors: AppColors.pendingGradient,
            icon: FontAwesomeIcons.clockRotateLeft,
          ),
        );
      },
    );
  }
}

class _WalletTotalCard extends StatelessWidget {
  const _WalletTotalCard();

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, SettingsProvider>(
      builder: (_, wallet, settings, _) {
        final walletTotal = wallet.paymentMethods.fold<double>(0, (sum, m) {
          return sum + wallet.balanceFor(m, settings: settings);
        });
        return _SummaryCard(
          data: _SummaryCardData(
            title: 'wallet'.tr(),
            amount: walletTotal,
            currency: settings.currency,
            colors: AppColors.primaryGradient,
            icon: FontAwesomeIcons.wallet,
          ),
        );
      },
    );
  }
}
