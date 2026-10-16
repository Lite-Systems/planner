import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';

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
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.lastRatesUpdate.isEmpty) {
        settings.fetchAndSaveRates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Selector<SettingsProvider, (double, double, bool, String)>(
      selector: (_, s) =>
          (s.usdToEgp, s.usdToSar, s.isFetchingRates, s.lastRatesUpdate),
      builder: (context, _, _) {
        final settings = context.read<SettingsProvider>();
        final card = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppCard.container(context, radius: AppRadius.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'usdRates'.tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),

                  // Refresh button with loading animation
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed: settings.isFetchingRates
                        ? null
                        : () => settings.fetchAndSaveRates(),
                    child: settings.isFetchingRates
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CupertinoActivityIndicator(radius: 7),
                          )
                        : const Icon(
                            CupertinoIcons.arrow_2_circlepath,
                            size: 16,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Rates Row ───────────────────────────────────────────
              Row(
                children: [
                  // USD to EGP Pill
                  Expanded(
                    child: _buildRatePill(
                      context,
                      flag: '🇺🇸',
                      base: '1 USD',
                      targetFlag: '🇪🇬',
                      rate: '${settings.usdToEgp.toStringAsFixed(2)} EGP',
                    ),
                  ),
                  const SizedBox(width: 10),
                  // USD to SAR Pill
                  Expanded(
                    child: _buildRatePill(
                      context,
                      flag: '🇺🇸',
                      base: '1 USD',
                      targetFlag: '🇸🇦',
                      rate: '${settings.usdToSar.toStringAsFixed(2)} SAR',
                    ),
                  ),
                ],
              ),

              // ── Footer Last Updated ─────────────────────────────────
              if (settings.lastRatesUpdate.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${'lastUpdated'.tr()}: ${settings.lastRatesUpdate}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? CupertinoColors.systemGrey3
                        : CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ],
          ),
        );
        if (AppLayout.of(context).hasSidebar) return card;
        return card
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildRatePill(
    BuildContext context, {
    required String flag,
    required String base,
    required String targetFlag,
    required String rate,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator(context), width: 0.5),
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              base,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              CupertinoIcons.right_chevron,
              size: 10,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          Text(targetFlag, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              rate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
