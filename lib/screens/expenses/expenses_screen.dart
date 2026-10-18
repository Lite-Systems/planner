import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/app_layout.dart';
import '../../core/utils/app_tokens.dart';
import '../../models/expense.dart';
import '../../models/expense_category.dart';
import '../../models/payment_method.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import 'add_expense_screen.dart';
import 'expense_categories_screen.dart';
import 'widgets/expense_card.dart';
import 'widgets/expense_summary_chart.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _selectedCategoryId = 'all';
  DateTime? _selectedMonth;
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    // Entrance animations play once on first layout, then the screen renders
    // statically. Replaying slide/fade on every data change or scroll remount
    // is a big source of desktop jank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_entranceDone) {
        setState(() => _entranceDone = true);
      }
    });
  }

  // ── Safe helpers ────────────────────────────────────────────────────────────

  /// Returns the payment method for an expense, or null if unavailable.
  /// Prevents the "Bad state: No element" crash when paymentMethods is empty.
  PaymentMethod? _paymentMethodFor(
    Expense expense,
    List<PaymentMethod> methods,
  ) {
    if (expense.paymentMethodId == null || methods.isEmpty) return null;
    try {
      return methods.firstWhere((m) => m.id == expense.paymentMethodId);
    } catch (_) {
      return null;
    }
  }

  List<DateTime> _getAvailableMonths(List<Expense> expenses) {
    final List<DateTime> months = [];
    for (final exp in expenses) {
      final date = DateTime(exp.date.year, exp.date.month);
      if (!months.any((m) => m.year == date.year && m.month == date.month)) {
        months.add(date);
      }
    }
    months.sort((a, b) => b.compareTo(a)); // latest first
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpensesProvider>(
      builder: (context, expProvider, child) {
        context
            .select<SettingsProvider, (String, String, bool, double, double)>(
              (s) => (
                s.currency,
                s.expensesCurrency,
                s.hideAmounts,
                s.usdToEgp,
                s.usdToSar,
              ),
            );
        final settings = context.read<SettingsProvider>();
        // Rebuild only when the wallet *set* changes, not on every balance
        // refresh (which now fires on each income/expense change).
        context.select<WalletProvider, String>(
          (w) => w.paymentMethods.map((m) => '${m.id}:${m.name}').join('|'),
        );
        final walletProvider = context.read<WalletProvider>();
        final desktop = AppLayout.of(context).isDesktop;
        final allExpenses = expProvider.expenses;
        final availableMonths = _getAvailableMonths(allExpenses);

        // 1. Filter by Selected Month
        List<Expense> monthFiltered = allExpenses;
        if (_selectedMonth != null) {
          monthFiltered = allExpenses
              .where(
                (e) =>
                    e.date.year == _selectedMonth!.year &&
                    e.date.month == _selectedMonth!.month,
              )
              .toList();
        }

        // Calculate total for monthFiltered
        final double monthTotal = monthFiltered.fold(
          0.0,
          (sum, e) =>
              sum +
              settings.convert(e.amount, e.currency, settings.expensesCurrency),
        );

        // Calculate Category Aggregates for monthFiltered
        final monthExpensesByCategory = <String, double>{};
        for (final exp in monthFiltered) {
          monthExpensesByCategory[exp.categoryId] =
              (monthExpensesByCategory[exp.categoryId] ?? 0.0) +
              settings.convert(
                exp.amount,
                exp.currency,
                settings.expensesCurrency,
              );
        }

        // 2. Filter by Category
        final filtered = _selectedCategoryId == 'all'
            ? monthFiltered
            : monthFiltered
                  .where((e) => e.categoryId == _selectedCategoryId)
                  .toList();

        return CupertinoPageScaffold(
          navigationBar: AppNavigationBar(
            middle: Text('expenses'.tr()),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  _navigateTo(context, const ExpenseCategoriesScreen()),
              child: const Icon(CupertinoIcons.tag),
            ),
          ),
          child: SafeArea(
            child: AppLayout.constrain(
              CustomScrollView(
                slivers: [
                  // ── Total Card ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: (desktop || _entranceDone)
                        ? _buildTotalCard(
                            monthTotal,
                            monthFiltered.length,
                            settings,
                          )
                        : _buildTotalCard(
                                monthTotal,
                                monthFiltered.length,
                                settings,
                              )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: -0.08, end: 0),
                  ),

                  // ── Month Filter ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildMonthFilterBar(availableMonths),
                  ),

                  // ── Chart ──────────────────────────────────────────────────
                  if (monthExpensesByCategory.isNotEmpty)
                    SliverToBoxAdapter(
                      child: (desktop || _entranceDone)
                          ? _buildChartSection(
                              monthExpensesByCategory,
                              expProvider.categories,
                              monthTotal,
                              settings,
                            )
                          : _buildChartSection(
                              monthExpensesByCategory,
                              expProvider.categories,
                              monthTotal,
                              settings,
                            ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                    ),

                  // ── Category Filter ─────────────────────────────────────────
                  if (monthExpensesByCategory.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildCategoryFilter(
                        expProvider,
                        monthExpensesByCategory,
                      ),
                    ),

                  // ── Section Header ──────────────────────────────────────────
                  if (allExpenses.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          '${_selectedCategoryId == 'all' ? monthFiltered.length : filtered.length} ${'expenseRecords'.tr()}',
                          style: AppText.caption(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  // ── Expenses List ────────────────────────────────────────────
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState(context))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 24),
                      sliver: AppLayout.of(context).isExpanded
                          ? SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 520,
                                    mainAxisExtent: 132,
                                  ),
                              delegate: SliverChildBuilderDelegate((_, i) {
                                return _expenseCard(
                                  context,
                                  filtered[i],
                                  expProvider,
                                  walletProvider,
                                  i,
                                );
                              }, childCount: filtered.length),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate((_, i) {
                                return _expenseCard(
                                  context,
                                  filtered[i],
                                  expProvider,
                                  walletProvider,
                                  i,
                                );
                              }, childCount: filtered.length),
                            ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
              maxWidth: AppLayout.maxContentWidth,
            ),
          ),
        );
      },
    );
  }

  // ── Total Card ──────────────────────────────────────────────────────────────

  Widget _buildTotalCard(
    double totalAmount,
    int recordCount,
    SettingsProvider settings,
  ) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    padding: const EdgeInsets.all(20),
    decoration: AppCard.container(
      context,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.arrow_up_right,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text('totalExpenses'.tr(), style: AppText.cardTitle(context)),
              ],
            ),
            CupertinoButton(
              key: const ValueKey('add-expense'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              onPressed: () => _navigateTo(context, const AddExpenseScreen()),
              child: Text(
                'addExpense'.tr(),
                style: AppText.caption(
                  context,
                ).copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            settings.formatMoney(totalAmount, settings.expensesCurrency),
            style: AppText.amount(
              context,
              AppColors.primary,
            ).copyWith(fontSize: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$recordCount ${'expenseRecords'.tr()}',
          style: AppText.caption(context),
        ),
      ],
    ),
  );

  // ── Chart Section ───────────────────────────────────────────────────────────

  Widget _buildChartSection(
    Map<String, double> expensesByCategory,
    List<ExpenseCategory> categories,
    double total,
    SettingsProvider settings,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppCard.container(context, radius: AppRadius.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient accent
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.expensePrimary.withValues(alpha: 0.07),
                  AppColors.expenseSecondary.withValues(alpha: 0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.expenseGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.expensePrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.chart_pie_fill,
                    color: CupertinoColors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'expenseBreakdown'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.expensePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${expensesByCategory.length} cat.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expensePrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chart body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: RepaintBoundary(
              child: ExpenseSummaryChart(
                expensesByCategory: expensesByCategory,
                categories: categories,
                total: total,
                currency: settings.expensesCurrency,
                animate: !AppLayout.of(context).isDesktop,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Month Filter Bar ───────────────────────────────────────────────────────

  Widget _buildMonthFilterBar(List<DateTime> availableMonths) {
    if (availableMonths.isEmpty) return const SizedBox.shrink();

    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: availableMonths.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final DateTime? month = isAll ? null : availableMonths[index - 1];
          final isSelected = isAll
              ? (_selectedMonth == null)
              : (_selectedMonth != null &&
                    _selectedMonth!.year == month!.year &&
                    _selectedMonth!.month == month.month);

          String label;
          if (isAll) {
            label = 'all'.tr();
          } else {
            label = DateFormat.yMMMM(context.locale.toString()).format(month!);
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMonth = month;
                _selectedCategoryId =
                    'all'; // Reset category filter when switching month
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: AppColors.expenseGradient)
                    : null,
                color: isSelected
                    ? null
                    : (isDark
                          ? AppColors.cardDark
                          : AppColors.elevatedBackground(context)),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected
                      ? CupertinoColors.transparent
                      : (isDark
                            ? AppColors.cardBorderDark
                            : const Color(0xFFE2E8F0)),
                  width: 0.8,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? CupertinoColors.white
                      : CupertinoColors.label.resolveFrom(context),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Category Filter ─────────────────────────────────────────────────────────

  Widget _buildCategoryFilter(
    ExpensesProvider provider,
    Map<String, double> expensesByCategory,
  ) {
    final categories = provider.categories
        .where((c) => expensesByCategory.containsKey(c.id))
        .toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('allExpenses'.tr(), 'all', null),
          ...categories.map(
            (cat) => _buildFilterChip(cat.name, cat.id, Color(cat.color)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String id, Color? color) {
    final isSelected = _selectedCategoryId == id;
    final chipColor = color ?? AppColors.expensePrimary;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : chipColor.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? CupertinoColors.white : chipColor,
          ),
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.expensePrimary.withValues(alpha: 0.12),
                  AppColors.expenseSecondary.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.expensePrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'noExpenses'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'addFirstExpense'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => _navigateTo(context, const AddExpenseScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.expenseGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.expensePrimary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'addExpense'.tr(),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _expenseCard(
    BuildContext context,
    Expense expense,
    ExpensesProvider expProvider,
    WalletProvider walletProvider,
    int i,
  ) {
    final card = ExpenseCard(
      expense: expense,
      category: expProvider.getCategoryById(expense.categoryId),
      paymentMethod: _paymentMethodFor(expense, walletProvider.paymentMethods),
      onTap: () => _navigateTo(context, AddExpenseScreen(expense: expense)),
      onDelete: () => _confirmDelete(context, expense, expProvider),
    );
    if (AppLayout.of(context).isDesktop || _entranceDone || i >= 8) {
      return card;
    }
    return card
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: i * 40),
          duration: const Duration(milliseconds: 280),
        )
        .slideX(begin: 0.04, end: 0);
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }

  void _confirmDelete(
    BuildContext context,
    Expense expense,
    ExpensesProvider provider,
  ) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('deleteExpense'.tr()),
        content: Text('deleteExpenseConfirm'.tr()),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              provider.deleteExpense(expense.id);
              Navigator.pop(context);
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }
}
