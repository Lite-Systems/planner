import 'dart:developer';
import 'package:flutter/material.dart';
import '../models/payment_method.dart';
import '../core/services/database_helper.dart';
import '../core/utils/currency_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'settings_provider.dart';

class WalletProvider with ChangeNotifier {
  List<PaymentMethod> _paymentMethods = [];

  /// Income/expense totals grouped by payment method **and** currency, cached
  /// from SQL (see [refreshFlowTotals]). Balances are then combined in Dart so
  /// only the few currency buckets are converted, never every transaction.
  final Map<String, List<_WalletFlow>> _flows = {};

  List<PaymentMethod> get paymentMethods => _paymentMethods;

  Future<void> loadData() async {
    try {
      _paymentMethods = await DatabaseHelper.instance.getPaymentMethods();

      // Translate default payment methods
      _paymentMethods = _paymentMethods.map((method) {
        if (method.id == 'cash') {
          return PaymentMethod(
            id: method.id,
            name: 'cash'.tr(),
            color: method.color,
            icon: method.icon,
            type: method.type,
            cardNumber: method.cardNumber,
            startingBalance: method.startingBalance,
          );
        }
        return method;
      }).toList();

      if (_paymentMethods.isEmpty) {
        // Add default payment methods
        await addPaymentMethod(
          PaymentMethod(
            id: 'cash',
            name: 'cash'.tr(),
            color: 0xFF4CAF50,
            icon: 0xe8cc,
          ),
        ); // payment
      }

      await _loadFlowTotals();
    } catch (e) {
      log('WalletProvider loadData error: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Recomputes the cached income/expense flow totals and notifies listeners.
  /// Wired to [IncomeProvider]/[ExpensesProvider] so a transaction change
  /// refreshes every wallet balance with a single grouped query.
  Future<void> refreshFlowTotals() async {
    await _loadFlowTotals();
    notifyListeners();
  }

  Future<void> _loadFlowTotals() async {
    try {
      final rows = await DatabaseHelper.instance.getWalletFlowTotals();
      final next = <String, List<_WalletFlow>>{};
      for (final row in rows) {
        final id = row['paymentMethodId'] as String?;
        if (id == null) continue;
        next
            .putIfAbsent(id, () => [])
            .add(
              _WalletFlow(
                currency: (row['currency'] as String?) ?? CurrencyHelper.egp,
                income: (row['incomeTotal'] as num?)?.toDouble() ?? 0,
                expense: (row['expenseTotal'] as num?)?.toDouble() ?? 0,
              ),
            );
      }
      _flows
        ..clear()
        ..addAll(next);
    } catch (e) {
      log('WalletProvider _loadFlowTotals error: $e');
    }
  }

  Future<void> addPaymentMethod(PaymentMethod method) async {
    await DatabaseHelper.instance.insertPaymentMethod(method);
    _paymentMethods.add(method);
    notifyListeners();
  }

  Future<void> updatePaymentMethod(PaymentMethod method) async {
    await DatabaseHelper.instance.updatePaymentMethod(method);
    final index = _paymentMethods.indexWhere((m) => m.id == method.id);
    if (index != -1) {
      _paymentMethods[index] = method;
      notifyListeners();
    }
  }

  Future<bool> deletePaymentMethod(String id) async {
    final used = await DatabaseHelper.instance.countUsagesOfPaymentMethod(id);
    if (used > 0) return false;
    await DatabaseHelper.instance.deletePaymentMethod(id);
    _paymentMethods.removeWhere((m) => m.id == id);
    notifyListeners();
    return true;
  }

  double balanceFor(
    PaymentMethod method, {
    required SettingsProvider settings,
  }) {
    double total = settings.convert(method.startingBalance, settings.currency);
    for (final flow in _flows[method.id] ?? const <_WalletFlow>[]) {
      total += settings.convert(flow.income, flow.currency);
      total -= settings.convert(flow.expense, flow.currency);
    }
    return total;
  }
}

class _WalletFlow {
  const _WalletFlow({
    required this.currency,
    required this.income,
    required this.expense,
  });

  final String currency;
  final double income;
  final double expense;
}
