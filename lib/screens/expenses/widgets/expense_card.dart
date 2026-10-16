import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../../models/expense.dart';
import '../../../models/expense_category.dart';
import '../../../models/payment_method.dart';
import 'package:planner/screens/expenses/expense_categories_screen.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final ExpenseCategory? category;
  final PaymentMethod? paymentMethod;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.category,
    this.paymentMethod,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Only amount-affecting settings should rebuild this card.
    context.select<SettingsProvider, (bool, String)>(
      (s) => (s.hideAmounts, s.currency),
    );
    final settings = context.read<SettingsProvider>();
    final categoryColor = category != null
        ? Color(category!.color)
        : const Color(0xFF64748B);
    final dateStr = DateFormat.MMMd().format(expense.date);
    final isFromTask = expense.taskId != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: AppCard.container(context, radius: AppRadius.lg),
          child: Row(
            children: [
              // Category color bar
              Container(
                width: 5,
                height: 70,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // Category icon
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category != null
                      ? ExpenseCategoriesScreen.iconForCode(category!.icon)
                      : CupertinoIcons.tag,
                  color: categoryColor,
                  size: 20,
                ),
              ),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFromTask)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'task'.tr(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: CupertinoColors.activeBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            category?.name ?? 'other'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $dateStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Amount
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      settings.formatMoney(
                        expense.amount,
                        expense.currency,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                    if (onDelete != null)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: onDelete,
                        child: const Icon(
                          CupertinoIcons.delete,
                          size: 16,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
