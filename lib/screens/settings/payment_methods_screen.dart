import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/utils/icon_utils.dart';

import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/payment_method.dart';
import 'package:uuid/uuid.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<SettingsProvider, (bool, String, double, double)>(
      (settings) => (
        settings.hideAmounts,
        settings.currency,
        settings.usdToEgp,
        settings.usdToSar,
      ),
    );
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(middle: Text('paymentMethods'.tr())),
      child: SafeArea(
        child: AppLayout.constrain(
          Stack(
            children: [
              Consumer<WalletProvider>(
                builder: (context, provider, child) {
                  if (provider.paymentMethods.isEmpty) {
                    return Center(child: Text('noPaymentMethods'.tr()));
                  }
                  final settings = Provider.of<SettingsProvider>(
                    context,
                    listen: false,
                  );
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: provider.paymentMethods.length,
                    itemBuilder: (context, index) {
                      final method = provider.paymentMethods[index];
                      final balance = provider.balanceFor(
                        method,
                        settings: settings,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Container(
                          decoration: AppCard.container(context),
                          child: CupertinoListTile(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: CupertinoColors.transparent,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Color(method.color),
                                shape: BoxShape.circle,
                              ),
                              child: FaIcon(
                                IconUtils.getIconData(method.icon),
                                color: CupertinoColors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(method.name),
                            subtitle: Text(settings.formatMoney(balance)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _showPaymentMethodDialog(
                                    context,
                                    method: method,
                                  ),
                                  child: const FaIcon(
                                    FontAwesomeIcons.pen,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _confirmDelete(context, method, provider);
                                  },
                                  child: const FaIcon(
                                    FontAwesomeIcons.trashCan,
                                    color: CupertinoColors.systemRed,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showPaymentMethodDialog(context),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.plus,
                        color: CupertinoColors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          maxWidth: 880,
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    PaymentMethod method,
    WalletProvider provider,
  ) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          'deletePaymentMethod'.tr(),
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: Text(
          'deletePaymentMethodConfirm'.tr(namedArgs: {'name': method.name}),
          style: CupertinoTheme.of(
            context,
          ).textTheme.textStyle.copyWith(fontSize: 14),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final deleted = await provider.deletePaymentMethod(method.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!deleted) {
                showCupertinoDialog(
                  useRootNavigator: false,
                  context: context,
                  builder: (_) => CupertinoAlertDialog(
                    title: Text('cannotDelete'.tr()),
                    content: Text('paymentMethodInUse'.tr()),
                    actions: [
                      CupertinoDialogAction(
                        child: Text('ok'.tr()),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodDialog(BuildContext context, {PaymentMethod? method}) {
    showCupertinoModalPopup(
      useRootNavigator: false,
      context: context,
      builder: (_) => PaymentMethodDialog(method: method),
    );
  }
}

class PaymentMethodDialog extends StatefulWidget {
  final PaymentMethod? method;

  const PaymentMethodDialog({super.key, this.method});

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  late TextEditingController _nameController;
  late TextEditingController _cardNumberController;
  late TextEditingController _balanceController;
  late int _selectedColor;
  late int _selectedIcon;
  late PaymentMethodType _selectedType;
  String? _errorText;

  final List<int> _colors = [
    0xFF4CAF50, // Green
    0xFF2196F3, // Blue
    0xFFFFC107, // Amber
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFF607D8B, // Blue Grey
    0xFFFF5722, // Deep Orange
  ];

  final List<int> _icons = [
    0xe8cc, // payment
    0xeacc, // account_balance_wallet
    0xe870, // card_membership
    0xe3f7, // attach_money
    0xe1b1, // account_balance
    0xe19f, // credit_card (visa)
    0xe84f, // account_balance (bank)
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.method?.name ?? '');
    _cardNumberController = TextEditingController(
      text: widget.method?.cardNumber ?? '',
    );
    _balanceController = TextEditingController(
      text: widget.method?.startingBalance.toString() ?? '0',
    );
    _selectedColor = widget.method?.color ?? _colors[0];
    _selectedIcon = widget.method?.icon ?? _icons[0];
    _selectedType = widget.method?.type ?? PaymentMethodType.cash;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.method == null
                    ? 'addPaymentMethod'.tr()
                    : 'editPaymentMethod'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Type Selector
              SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (context) {
                    final isDark =
                        CupertinoTheme.brightnessOf(context) == Brightness.dark;
                    return CupertinoSlidingSegmentedControl<PaymentMethodType>(
                      backgroundColor: AppColors.elevatedBackground(context),
                      thumbColor: AppColors.cardBackground(context),
                      groupValue: _selectedType,
                      children: {
                        PaymentMethodType.cash: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'cash'.tr(),
                            style: TextStyle(
                              color: _selectedType == PaymentMethodType.cash
                                  ? (isDark
                                        ? CupertinoColors.white
                                        : CupertinoColors.black)
                                  : CupertinoColors.secondaryLabel.resolveFrom(
                                      context,
                                    ),
                              fontWeight:
                                  _selectedType == PaymentMethodType.cash
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        PaymentMethodType.visa: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'visa'.tr(),
                            style: TextStyle(
                              color: _selectedType == PaymentMethodType.visa
                                  ? (isDark
                                        ? CupertinoColors.white
                                        : CupertinoColors.black)
                                  : CupertinoColors.secondaryLabel.resolveFrom(
                                      context,
                                    ),
                              fontWeight:
                                  _selectedType == PaymentMethodType.visa
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        PaymentMethodType.bank: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'bank'.tr(),
                            style: TextStyle(
                              color: _selectedType == PaymentMethodType.bank
                                  ? (isDark
                                        ? CupertinoColors.white
                                        : CupertinoColors.black)
                                  : CupertinoColors.secondaryLabel.resolveFrom(
                                      context,
                                    ),
                              fontWeight:
                                  _selectedType == PaymentMethodType.bank
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                            // Auto-select icon based on type
                            if (_selectedType == PaymentMethodType.cash) {
                              _selectedIcon = 0xe8cc; // payment
                            } else if (_selectedType ==
                                PaymentMethodType.visa) {
                              _selectedIcon = 0xe19f; // credit_card
                            } else if (_selectedType ==
                                PaymentMethodType.bank) {
                              _selectedIcon = 0xe84f; // account_balance
                            }
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedType == PaymentMethodType.visa) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'cardNumber'.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CupertinoTextField(
                      controller: _cardNumberController,
                      placeholder: '0000 0000 0000 0000',
                      keyboardType: TextInputType.number,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedBackground(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'methodName'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'enterMethodName'.tr(),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedBackground(context),
                      borderRadius: BorderRadius.circular(8),
                      border: _errorText != null
                          ? Border.all(color: CupertinoColors.systemRed)
                          : null,
                    ),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'startingBalance'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 4),
              CupertinoTextField(
                controller: _balanceController,
                placeholder: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.elevatedBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'pickColor'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: _selectedColor == color
                              ? Border.all(
                                  color: CupertinoColors.white,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: _selectedColor == color
                            ? const FaIcon(
                                FontAwesomeIcons.check,
                                color: CupertinoColors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'pickIcon'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _icons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final iconCode = _icons[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = iconCode),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _selectedIcon == iconCode
                              ? CupertinoColors.systemTeal
                              : AppColors.elevatedBackground(context),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          IconUtils.getIconData(iconCode),
                          color: _selectedIcon == iconCode
                              ? CupertinoColors.white
                              : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _saveMethod,
                child: Text(
                  widget.method == null ? 'create'.tr() : 'update'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveMethod() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorText = 'pleaseEnterName'.tr());
      return;
    }

    final provider = Provider.of<WalletProvider>(context, listen: false);
    final method = PaymentMethod(
      id: widget.method?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      color: _selectedColor,
      icon: _selectedIcon,
      type: _selectedType,
      cardNumber: _selectedType == PaymentMethodType.visa
          ? _cardNumberController.text.trim()
          : null,
      startingBalance: double.tryParse(_balanceController.text) ?? 0,
    );

    if (widget.method == null) {
      provider.addPaymentMethod(method);
    } else {
      provider.updatePaymentMethod(method);
    }

    Navigator.pop(context);
  }
}
