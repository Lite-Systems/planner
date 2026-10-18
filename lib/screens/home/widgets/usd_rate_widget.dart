import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import 'dashboard_style.dart';

class UsdRateWidget extends StatefulWidget {
  const UsdRateWidget({super.key});
  @override
  State<UsdRateWidget> createState() => _UsdRateWidgetState();
}

class _UsdRateWidgetState extends State<UsdRateWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      if (settings.lastRatesUpdate.isEmpty && !settings.isFetchingRates) {
        settings.fetchAndSaveRates();
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Selector<SettingsProvider, (double, double, bool, String)>(
        selector: (_, s) =>
            (s.usdToEgp, s.usdToSar, s.isFetchingRates, s.lastRatesUpdate),
        builder: (context, value, _) => DashboardPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: DashboardStyle.emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'usdRates'.tr(),
                      style: DashboardStyle.text(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const ValueKey('dashboard-refresh-rates'),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36),
                    onPressed: value.$3
                        ? null
                        : context.read<SettingsProvider>().fetchAndSaveRates,
                    child: value.$3
                        ? const CupertinoActivityIndicator(radius: 8)
                        : Icon(
                            CupertinoIcons.arrow_2_circlepath,
                            size: 17,
                            color: DashboardStyle.muted(context),
                            semanticLabel: 'dashboardRefreshRates'.tr(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _RatePill(code: 'SAR', value: value.$2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RatePill(code: 'EGP', value: value.$1),
                  ),
                ],
              ),
              if (value.$4.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${'lastUpdated'.tr()}: ${value.$4}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardStyle.text(
                    context,
                    size: 10,
                    color: DashboardStyle.muted(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _RatePill extends StatelessWidget {
  const _RatePill({required this.code, required this.value});
  final String code;
  final double value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: DashboardStyle.elevated(context),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: DashboardStyle.border(context)),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.money_dollar_circle,
            size: 22,
            color: DashboardStyle.emerald,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 USD',
                  style: DashboardStyle.text(
                    context,
                    size: 10,
                    color: DashboardStyle.muted(context),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$code ${value.toStringAsFixed(2)}',
                    style: DashboardStyle.text(
                      context,
                      size: 12,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
