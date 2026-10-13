import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:planner/models/income.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/screens/income/add_income_screen.dart';
import 'package:planner/screens/income/income_categories_screen.dart';
import 'package:provider/provider.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<IncomeProvider, SettingsProvider, WalletProvider>(
      builder: (_, provider, settings, wallet, _) {
        final total = provider.incomes.fold<double>(
          0,
          (sum, e) => sum + settings.convert(e.amount, e.currency),
        );
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text('income'.tr()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).push(
                    NoAnimationPageRoute(
                      builder: (_) => const IncomeCategoriesScreen(),
                    ),
                  ),
                  child: const Icon(CupertinoIcons.square_grid_2x2),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).push(
                    NoAnimationPageRoute(
                      builder: (_) => const AddIncomeScreen(),
                    ),
                  ),
                  child: const Icon(CupertinoIcons.add),
                ),
              ],
            ),
          ),
          child: SafeArea(
            child: provider.incomes.isEmpty
                ? Center(child: Text('noIncome'.tr()))
                : AppLayout.constrain(
                    _IncomeList(
                      total: total,
                      incomes: provider.incomes,
                      categoryName: (id) => provider.getCategoryById(id)?.name,
                      onEdit: (income) => Navigator.of(context).push(
                        NoAnimationPageRoute(
                          builder: (_) => AddIncomeScreen(income: income),
                        ),
                      ),
                      onDelete: provider.deleteIncome,
                    ),
                    maxWidth: AppLayout.maxContentWidth,
                  ),
          ),
        );
      },
    );
  }
}

class _IncomeList extends StatelessWidget {
  const _IncomeList({
    required this.total,
    required this.incomes,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  final double total;
  final List<Income> incomes;
  final String? Function(String id) categoryName;
  final ValueChanged<Income> onEdit;
  final ValueChanged<String> onDelete;

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        context.read<SettingsProvider>().formatMoney(total),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF10B981),
        ),
      ),
    );
  }

  Widget _tile(Income income) {
    return _IncomeTile(
      income: income,
      categoryName: categoryName(income.categoryId),
      onTap: () => onEdit(income),
      onDelete: () => onDelete(income.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppLayout.of(context).isExpanded) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 520,
                mainAxisExtent: 92,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _tile(incomes[i]),
                childCount: incomes.length,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: incomes.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) return _header(context);
        return _tile(incomes[index - 1]);
      },
    );
  }
}

class _IncomeTile extends StatelessWidget {
  final Income income;
  final String? categoryName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _IncomeTile({
    required this.income,
    required this.categoryName,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppClickable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppCard.container(
          context,
          radius: AppRadius.lg,
          shadows: const [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(income.title, style: AppText.cardTitle(context)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${categoryName ?? 'other'.tr()} · ${DateFormat.yMMMd().format(income.date)}',
                    style: AppText.caption(context),
                  ),
                ],
              ),
            ),
            Text(
              context.read<SettingsProvider>().formatMoney(
                income.amount,
                income.currency,
              ),
              style: AppText.amount(context, AppColors.success),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              minimumSize: const Size(0, 0),
              onPressed: onDelete,
              child: const Icon(
                CupertinoIcons.delete,
                color: CupertinoColors.systemRed,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
