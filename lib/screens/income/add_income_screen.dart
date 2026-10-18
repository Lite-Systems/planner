import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/currency_helper.dart';
import 'package:planner/models/income.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:planner/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddIncomeScreen extends StatefulWidget {
  final Income? income;

  const AddIncomeScreen({super.key, this.income});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  String _currency = CurrencyHelper.egp;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _currency = settings.currency;
    if (widget.income != null) {
      final e = widget.income!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toString();
      _noteController.text = e.note ?? '';
      _date = e.date;
      _selectedCategoryId = e.categoryId;
      _selectedPaymentMethodId = e.paymentMethodId;
      _currency = CurrencyHelper.normalize(e.currency);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty ||
        (double.tryParse(_amountController.text) ?? 0) <= 0 ||
        _selectedCategoryId == null) {
      return;
    }
    setState(() => _isSaving = true);
    final provider = Provider.of<IncomeProvider>(context, listen: false);
    final income = Income(
      id: widget.income?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: _date,
      categoryId: _selectedCategoryId!,
      paymentMethodId: _selectedPaymentMethodId,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      taskId: widget.income?.taskId,
      currency: _currency,
    );
    if (widget.income != null) {
      await provider.updateIncome(income);
    } else {
      await provider.addIncome(income);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(
        middle: Text(
          widget.income == null ? 'addIncome'.tr() : 'editIncome'.tr(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : Text('save'.tr()),
        ),
      ),
      child: SafeArea(
        child: AppLayout.constrain(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CupertinoTextField(
                decoration: AppCard.container(context, radius: AppRadius.md),
                controller: _titleController,
                placeholder: 'titlePlaceholder'.tr(),
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      decoration: AppCard.container(
                        context,
                        radius: AppRadius.md,
                      ),
                      controller: _amountController,
                      placeholder: 'amountPlaceholder'.tr(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    onPressed: () {
                      showCupertinoModalPopup(
                        useRootNavigator: false,
                        context: context,
                        builder: (_) => CupertinoActionSheet(
                          actions: CurrencyHelper.codes
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
                    },
                    child: Text(_currency),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Consumer<IncomeProvider>(
                builder: (_, provider, _) {
                  return Wrap(
                    spacing: 8,
                    children: provider.categories.map((cat) {
                      final selected = _selectedCategoryId == cat.id;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategoryId = cat.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(cat.color)
                                : AppColors.elevatedBackground(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              color: selected ? CupertinoColors.white : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Consumer<WalletProvider>(
                builder: (_, wallet, _) {
                  return CupertinoButton(
                    onPressed: () {
                      showCupertinoModalPopup(
                        useRootNavigator: false,
                        context: context,
                        builder: (_) => CupertinoActionSheet(
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                setState(() => _selectedPaymentMethodId = null);
                                Navigator.pop(context);
                              },
                              child: Text('none'.tr()),
                            ),
                            ...wallet.paymentMethods.map(
                              (m) => CupertinoActionSheetAction(
                                onPressed: () {
                                  setState(
                                    () => _selectedPaymentMethodId = m.id,
                                  );
                                  Navigator.pop(context);
                                },
                                child: Text(m.name),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      wallet.paymentMethods
                          .where((m) => m.id == _selectedPaymentMethodId)
                          .map((m) => m.name)
                          .firstWhere(
                            (_) => true,
                            orElse: () => 'selectPaymentMethod'.tr(),
                          ),
                    ),
                  );
                },
              ),
              CupertinoTextField(
                decoration: AppCard.container(context, radius: AppRadius.md),
                controller: _noteController,
                placeholder: 'noteOptional'.tr(),
                padding: const EdgeInsets.all(12),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
