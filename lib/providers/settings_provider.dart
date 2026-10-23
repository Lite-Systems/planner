import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../core/services/currency_service.dart';
import '../core/services/database_helper.dart';
import '../core/utils/currency_helper.dart';

class SettingsProvider with ChangeNotifier {
  bool _isBiometricEnabled = false;
  bool _hideAmounts = false;
  bool _isAppLocked = false;
  bool _hasUnlockedOnce = false;
  bool _areSettingsLoaded = false;
  bool _isDarkMode = false;
  String _currency = CurrencyHelper.egp;
  String _expensesCurrency = CurrencyHelper.usd;
  double _hourCost = 5.0;
  bool _showHourCostInPrint = true;
  bool _showTaskTimeInPrint = true;
  bool _showTaskTypeInPrint = true;
  bool _showSubtasksInPrint = true;
  bool _isExpensesEnabled = true;
  bool _isTodosEnabled = true;
  double _usdToEgp = 48.50;
  double _usdToSar = 3.75;
  String _lastRatesUpdate = '';
  bool _isFetchingRates = false;
  bool _ratesRefreshFailed = false;
  late final Future<void> _settingsReady;
  bool _compactDensity = false;
  bool _rememberLastSection = false;
  bool _keyboardShortcuts = true;
  bool _macosWidgetEnabled = false;
  String _lastSection = 'home';
  List<String> listCurency = CurrencyHelper.codes;

  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get requiresInitialUnlock => _isBiometricEnabled && !_hasUnlockedOnce;
  bool get hideAmounts => _hideAmounts;
  bool get isAppLocked => _isAppLocked && _isBiometricEnabled;
  bool get areSettingsLoaded => _areSettingsLoaded;
  bool get isDarkMode => _isDarkMode;

  String get currency => _currency;
  String get expensesCurrency => _expensesCurrency;
  double get hourCost => _hourCost;
  bool get showHourCostInPrint => _showHourCostInPrint;
  bool get showTaskTimeInPrint => _showTaskTimeInPrint;
  bool get showTaskTypeInPrint => _showTaskTypeInPrint;
  bool get showSubtasksInPrint => _showSubtasksInPrint;
  bool get isExpensesEnabled => _isExpensesEnabled;
  bool get isTodosEnabled => _isTodosEnabled;
  double get usdToEgp => _usdToEgp;
  double get usdToSar => _usdToSar;
  String get lastRatesUpdate => _lastRatesUpdate;
  bool get isFetchingRates => _isFetchingRates;
  bool get ratesRefreshFailed => _ratesRefreshFailed;
  bool get compactDensity => _compactDensity;
  bool get rememberLastSection => _rememberLastSection;
  bool get keyboardShortcuts => _keyboardShortcuts;
  bool get macosWidgetEnabled => _macosWidgetEnabled;
  String get lastSection => _lastSection;
  double get cardPadding => _compactDensity ? 12 : 20;
  double get listGap => _compactDensity ? 6 : 12;

  SettingsProvider() {
    _settingsReady = _loadSettings();
  }

  static const syncedKeys = {
    'currency',
    'expensesCurrency',
    'hourCost',
    'showHourCostInPrint',
    'showTaskTimeInPrint',
    'showTaskTypeInPrint',
    'showSubtasksInPrint',
  };

  Future<void> reloadAccountSettings() => _loadSettings();

  Map<String, dynamic> get syncedPreferences => {
    'currency': _currency,
    'expensesCurrency': _expensesCurrency,
    'hourCost': _hourCost,
    'showHourCostInPrint': _showHourCostInPrint,
    'showTaskTimeInPrint': _showTaskTimeInPrint,
    'showTaskTypeInPrint': _showTaskTypeInPrint,
    'showSubtasksInPrint': _showSubtasksInPrint,
  };

  static Future<Map<String, dynamic>> guestPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'currency': prefs.getString('currency') ?? 'EGP',
      'expensesCurrency': prefs.getString('expensesCurrency') ?? 'USD',
      'hourCost': prefs.getDouble('hourCost') ?? 5.0,
      for (final key in syncedKeys.where((k) => k.startsWith('show')))
        key: prefs.getBool(key) ?? true,
    };
  }

  Future<void> _saveSyncedPreference(String key, Object value) async {
    if (DatabaseHelper.instance.accountId != null) {
      await DatabaseHelper.instance.setAccountPreference(key, value);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;
    _hideAmounts = prefs.getBool('hideAmounts') ?? false;
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _currency = CurrencyHelper.normalize(prefs.getString('currency') ?? 'EGP');
    _expensesCurrency = CurrencyHelper.normalize(
      prefs.getString('expensesCurrency') ?? 'USD',
    );
    _hourCost = prefs.getDouble('hourCost') ?? 5.0;
    _showHourCostInPrint = prefs.getBool('showHourCostInPrint') ?? true;
    _showTaskTimeInPrint = prefs.getBool('showTaskTimeInPrint') ?? true;
    _showTaskTypeInPrint = prefs.getBool('showTaskTypeInPrint') ?? true;
    _showSubtasksInPrint = prefs.getBool('showSubtasksInPrint') ?? true;
    _isExpensesEnabled = prefs.getBool('isExpensesEnabled') ?? true;
    _isTodosEnabled = prefs.getBool('isTodosEnabled') ?? true;
    _usdToEgp = prefs.getDouble('usdToEgp') ?? 48.50;
    _usdToSar = prefs.getDouble('usdToSar') ?? 3.75;
    _lastRatesUpdate = prefs.getString('lastRatesUpdate') ?? '';
    _compactDensity = prefs.getBool('compactDensity') ?? false;
    _rememberLastSection = prefs.getBool('rememberLastSection') ?? false;
    _keyboardShortcuts = prefs.getBool('keyboardShortcuts') ?? true;
    _macosWidgetEnabled = prefs.getBool('macosWidgetEnabled') ?? false;
    _lastSection = prefs.getString('lastSection') ?? 'home';
    if (DatabaseHelper.instance.accountId != null) {
      final cloud = await DatabaseHelper.instance.accountPreferences();
      _currency = CurrencyHelper.normalize(
        cloud['currency'] as String? ?? 'EGP',
      );
      _expensesCurrency = CurrencyHelper.normalize(
        cloud['expensesCurrency'] as String? ?? 'USD',
      );
      _hourCost = (cloud['hourCost'] as num?)?.toDouble() ?? 5.0;
      _showHourCostInPrint = cloud['showHourCostInPrint'] as bool? ?? true;
      _showTaskTimeInPrint = cloud['showTaskTimeInPrint'] as bool? ?? true;
      _showTaskTypeInPrint = cloud['showTaskTypeInPrint'] as bool? ?? true;
      _showSubtasksInPrint = cloud['showSubtasksInPrint'] as bool? ?? true;
    }
    _areSettingsLoaded = true;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    if (_isBiometricEnabled == value) return;
    final prefs = await SharedPreferences.getInstance();
    _isBiometricEnabled = value;
    if (!value) _isAppLocked = false;
    await prefs.setBool('isBiometricEnabled', value);
    notifyListeners();
  }

  Future<void> setHideAmounts(bool value) async {
    if (_hideAmounts == value) return;
    final prefs = await SharedPreferences.getInstance();
    _hideAmounts = value;
    await prefs.setBool('hideAmounts', value);
    notifyListeners();
  }

  String formatMoney(double amount, [String? currency]) {
    return CurrencyHelper.format(
      amount,
      currency ?? _currency,
      hidden: _hideAmounts,
    );
  }

  void lockApp() {
    if (!_isBiometricEnabled || !_hasUnlockedOnce) return;
    _isAppLocked = true;
    notifyListeners();
  }

  void unlockApp() {
    _isAppLocked = false;
    _hasUnlockedOnce = true;
    notifyListeners();
  }

  Future<void> refreshRatesIfNeeded() async {
    await _settingsReady;
    final last = DateTime.tryParse(_lastRatesUpdate);
    if (last == null ||
        DateTime.now().difference(last) >= const Duration(days: 1)) {
      await fetchAndSaveRates();
    }
  }

  Future<void> fetchAndSaveRates() async {
    await _settingsReady;
    if (_isFetchingRates) return;
    _isFetchingRates = true;
    _ratesRefreshFailed = false;
    notifyListeners();

    try {
      final rates = await CurrencyService.fetchLatestRates();
      if (rates == null) {
        _ratesRefreshFailed = true;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final updated = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      await prefs.setDouble('usdToEgp', rates['EGP']!);
      await prefs.setDouble('usdToSar', rates['SAR']!);
      await prefs.setString('lastRatesUpdate', updated);
      _usdToEgp = rates['EGP']!;
      _usdToSar = rates['SAR']!;
      _lastRatesUpdate = updated;
    } catch (_) {
      _ratesRefreshFailed = true;
    } finally {
      _isFetchingRates = false;
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = value;
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setCurrency(String value) async {
    final normalized = CurrencyHelper.normalize(value);
    if (_currency == normalized) return;
    _currency = normalized;
    await _saveSyncedPreference('currency', _currency);
    notifyListeners();
  }

  Future<void> setExpensesCurrency(String value) async {
    final normalized = CurrencyHelper.normalize(value);
    if (_expensesCurrency == normalized) return;
    _expensesCurrency = normalized;
    await _saveSyncedPreference('expensesCurrency', _expensesCurrency);
    notifyListeners();
  }

  double convert(double amount, String from, [String? to]) {
    return CurrencyHelper.convert(
      amount,
      from,
      to ?? _currency,
      usdToEgp: _usdToEgp,
      usdToSar: _usdToSar,
    );
  }

  Future<void> setHourCost(double value) async {
    if (_hourCost == value) return;
    _hourCost = value;
    await _saveSyncedPreference('hourCost', value);
    notifyListeners();
  }

  Future<void> setShowHourCostInPrint(bool value) async {
    if (_showHourCostInPrint == value) return;
    _showHourCostInPrint = value;
    await _saveSyncedPreference('showHourCostInPrint', value);
    notifyListeners();
  }

  Future<void> setShowTaskTimeInPrint(bool value) async {
    if (_showTaskTimeInPrint == value) return;
    _showTaskTimeInPrint = value;
    await _saveSyncedPreference('showTaskTimeInPrint', value);
    notifyListeners();
  }

  Future<void> setShowTaskTypeInPrint(bool value) async {
    if (_showTaskTypeInPrint == value) return;
    _showTaskTypeInPrint = value;
    await _saveSyncedPreference('showTaskTypeInPrint', value);
    notifyListeners();
  }

  Future<void> setShowSubtasksInPrint(bool value) async {
    if (_showSubtasksInPrint == value) return;
    _showSubtasksInPrint = value;
    await _saveSyncedPreference('showSubtasksInPrint', value);
    notifyListeners();
  }

  Future<void> setExpensesEnabled(bool value) async {
    if (_isExpensesEnabled == value) return;
    final prefs = await SharedPreferences.getInstance();
    _isExpensesEnabled = value;
    await prefs.setBool('isExpensesEnabled', value);
    notifyListeners();
  }

  Future<void> setTodosEnabled(bool value) async {
    if (_isTodosEnabled == value) return;
    final prefs = await SharedPreferences.getInstance();
    _isTodosEnabled = value;
    await prefs.setBool('isTodosEnabled', value);
    notifyListeners();
  }

  Future<void> setCompactDensity(bool value) async {
    if (_compactDensity == value) return;
    final prefs = await SharedPreferences.getInstance();
    _compactDensity = value;
    await prefs.setBool('compactDensity', value);
    notifyListeners();
  }

  Future<void> setRememberLastSection(bool value) async {
    if (_rememberLastSection == value) return;
    final prefs = await SharedPreferences.getInstance();
    _rememberLastSection = value;
    await prefs.setBool('rememberLastSection', value);
    notifyListeners();
  }

  Future<void> setKeyboardShortcuts(bool value) async {
    if (_keyboardShortcuts == value) return;
    final prefs = await SharedPreferences.getInstance();
    _keyboardShortcuts = value;
    await prefs.setBool('keyboardShortcuts', value);
    notifyListeners();
  }

  Future<void> setLastSection(String value) async {
    if (_lastSection == value) return;
    _lastSection = value;
    if (!_rememberLastSection) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSection', value);
  }

  Future<void> setMacosWidgetEnabled(bool value) async {
    if (_macosWidgetEnabled == value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('macosWidgetEnabled', value);
    _macosWidgetEnabled = value;
    notifyListeners();
  }
}
