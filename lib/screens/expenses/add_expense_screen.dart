import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/app_layout.dart';
import '../../../models/expense.dart';
import '../../../models/expense_category.dart';
import '../../../providers/expenses_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/payment_method.dart';
import 'package:planner/screens/expenses/expense_categories_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense; // null = create, non-null = edit
  final String? prefilledTaskId;
  final String? prefilledTaskName;
  final double? prefilledAmount;

  const AddExpenseScreen({
    super.key,
    this.expense,
    this.prefilledTaskId,
    this.prefilledTaskName,
    this.prefilledAmount,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  String _currency = 'L.E';
  bool _isSaving = false;
  String? _titleError;
  String? _amountError;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _currency = settings.expensesCurrency;

    if (widget.expense != null) {
      final e = widget.expense!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toString();
      _noteController.text = e.note ?? '';
      _date = e.date;
      _selectedCategoryId = e.categoryId;
      _selectedPaymentMethodId = e.paymentMethodId;
      _currency = e.currency;
    } else if (widget.prefilledTaskName != null) {
      _titleController.text = widget.prefilledTaskName!;
      _amountController.text = widget.prefilledAmount?.toStringAsFixed(2) ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _titleError = _titleController.text.trim().isEmpty
          ? 'pleaseEnterName'.tr()
          : null;
      _amountError =
          (double.tryParse(_amountController.text) == null ||
              double.parse(_amountController.text) <= 0)
          ? 'invalidInput'.tr()
          : null;
      _categoryError = _selectedCategoryId == null
          ? 'selectCategory'.tr()
          : null;
    });
    if (_titleError != null || _amountError != null || _categoryError != null) {
      valid = false;
    }
    return valid;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);

    final provider = Provider.of<ExpensesProvider>(context, listen: false);
    final expense = Expense(
      id: widget.expense?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: _date,
      categoryId: _selectedCategoryId!,
      paymentMethodId: _selectedPaymentMethodId,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      taskId: widget.expense?.taskId ?? widget.prefilledTaskId,
      currency: _currency,
    );

    if (widget.expense != null) {
      await provider.updateExpense(expense);
    } else {
      await provider.addExpense(expense);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.expense != null;
    final isFromTask =
        widget.prefilledTaskId != null || (widget.expense?.taskId != null);

    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(
        middle: Text(isEdit ? 'editExpense'.tr() : 'addExpense'.tr()),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : Text(
                  isEdit ? 'update'.tr() : 'save'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ),
      child: SafeArea(
        child: AppLayout.constrain(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isFromTask) _buildTaskBadge(),
              const SizedBox(height: 8),
              _buildField(
                label: 'titlePlaceholder'.tr(),
                child: CupertinoTextField(
                  controller: _titleController,
                  placeholder: 'titlePlaceholder'.tr(),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground(context),
                    border: Border.all(
                      color: _titleError != null
                          ? CupertinoColors.destructiveRed
                          : AppColors.separator(context),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                error: _titleError,
              ),
              _buildField(
                label: 'amountPlaceholder'.tr(),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _amountController,
                        placeholder: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground(context),
                          border: Border.all(
                            color: _amountError != null
                                ? CupertinoColors.destructiveRed
                                : AppColors.separator(context),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<SettingsProvider>(
                      builder: (_, settings, _) => CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        color: AppColors.elevatedBackground(context),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: _pickCurrency,
                        child: Text(
                          _currency,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                error: _amountError,
              ),
              _buildField(
                label: 'dateLabel'.tr(),
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.separator(context)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat.yMMMd(
                            context.locale.toString(),
                          ).format(_date),
                        ),
                        const Icon(
                          CupertinoIcons.calendar,
                          color: CupertinoColors.systemGrey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildField(
                label: 'selectCategory'.tr(),
                child: Consumer<ExpensesProvider>(
                  builder: (_, expProvider, _) {
                    return _buildCategoryPicker(expProvider.categories);
                  },
                ),
                error: _categoryError,
              ),
              _buildField(
                label: 'selectPaymentMethod'.tr(),
                child: Consumer<WalletProvider>(
                  builder: (_, walletProvider, _) {
                    return _buildPaymentMethodPicker(
                      walletProvider.paymentMethods,
                    );
                  },
                ),
              ),
              _buildField(
                label: 'noteOptional'.tr(),
                child: CupertinoTextField(
                  controller: _noteController,
                  placeholder: 'noteOptional'.tr(),
                  maxLines: 3,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground(context),
                    border: Border.all(color: AppColors.separator(context)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.link, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'autoExpenseFromTask'.tr(),
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required Widget child,
    String? error,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 6),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(List<ExpenseCategory> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = _selectedCategoryId == cat.id;
        final catColor = Color(cat.color);
        return GestureDetector(
          onTap: () => setState(() {
            _selectedCategoryId = cat.id;
            _categoryError = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? catColor : catColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? catColor : catColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ExpenseCategoriesScreen.iconForCode(cat.icon),
                  size: 14,
                  color: isSelected ? CupertinoColors.white : catColor,
                ),
                const SizedBox(width: 5),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? CupertinoColors.white : catColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodPicker(List<PaymentMethod> paymentMethods) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.separator(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoListTile(
        leading: Icon(
          _selectedPaymentMethodId != null ? Icons.credit_card : Icons.payment,
          color: CupertinoColors.systemGrey,
        ),
        title: Text(
          _selectedPaymentMethodId != null
              ? (paymentMethods
                    .firstWhere(
                      (m) => m.id == _selectedPaymentMethodId,
                      orElse: () => paymentMethods.first,
                    )
                    .name)
              : 'selectPaymentMethod'.tr(),
          style: TextStyle(
            color: _selectedPaymentMethodId != null
                ? null
                : CupertinoColors.systemGrey,
          ),
        ),
        trailing: const CupertinoListTileChevron(),
        onTap: () => _showPaymentMethodPicker(paymentMethods),
      ),
    );
  }

  void _pickDate() {
    showCupertinoModalPopup(
      useRootNavigator: false,
      context: context,
      builder: (_) => Container(
        height: 280,
        color: AppColors.cardBackground(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text('done'.tr()),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _date,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (d) => setState(() => _date = d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickCurrency() {
    final currencies = ['EGP', 'USD', 'SAR'];
    showCupertinoModalPopup(
      useRootNavigator: false,
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text('selectCurrency'.tr()),
        actions: currencies
            .map(
              (c) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _currency = c);
                  Navigator.pop(context);
                },
                child: Text(c),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
      ),
    );
  }

  void _showPaymentMethodPicker(List<PaymentMethod> paymentMethods) {
    showCupertinoModalPopup(
      useRootNavigator: false,
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text('selectPaymentMethod'.tr()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedPaymentMethodId = null);
              Navigator.pop(context);
            },
            child: Text('none'.tr()),
          ),
          ...paymentMethods.map(
            (m) => CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _selectedPaymentMethodId = m.id);
                Navigator.pop(context);
              },
              child: Text(m.name),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
      ),
    );
  }
}
