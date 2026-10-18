import '../expense_categories_screen.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planner/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../../models/expense_category.dart';

class ExpenseSummaryChart extends StatefulWidget {
  final Map<String, double> expensesByCategory;
  final List<ExpenseCategory> categories;
  final double total;
  final String currency;
  final bool animate;

  const ExpenseSummaryChart({
    super.key,
    required this.expensesByCategory,
    required this.categories,
    required this.total,
    this.currency = 'USD',
    this.animate = true,
  });

  @override
  State<ExpenseSummaryChart> createState() => _ExpenseSummaryChartState();
}

class _ExpenseSummaryChartState extends State<ExpenseSummaryChart>
    with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<MapEntry<String, double>> get _sortedEntries {
    final entries = widget.expensesByCategory.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  ExpenseCategory _categoryFor(String id) {
    return widget.categories.firstWhere(
      (c) => c.id == id,
      orElse: () =>
          ExpenseCategory(id: id, name: id, color: 0xFF64748B, icon: 0xe8b8),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expensesByCategory.isEmpty) return const SizedBox.shrink();

    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final sortedEntries = _sortedEntries;

    return Column(
      children: [
        // ── Donut Chart + Center Label ────────────────────────────────────
        _maybeAnimate(
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final none =
                              !event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null;
                          final index = none
                              ? -1
                              : response.touchedSection!.touchedSectionIndex;
                          if (index == _touchedIndex) return;
                          setState(() => _touchedIndex = index);
                          if (widget.animate && index >= 0) {
                            if (!_pulseController.isAnimating) {
                              _pulseController.repeat(reverse: true);
                            }
                          } else {
                            _pulseController.stop();
                          }
                        },
                      ),
                      sections: _buildSections(sortedEntries),
                      centerSpaceRadius: 72,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                    ),
                  ),
                ),
                _buildCenterLabel(sortedEntries, isDark),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Legend ───────────────────────────────────────────────────────
        _buildLegend(sortedEntries, isDark),
      ],
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, double>> entries,
  ) {
    return List.generate(entries.length, (i) {
      final entry = entries[i];
      final cat = _categoryFor(entry.key);
      final pct = widget.total > 0 ? (entry.value / widget.total * 100) : 0.0;
      final isTouched = i == _touchedIndex;

      return PieChartSectionData(
        color: Color(cat.color),
        value: entry.value,
        title: pct >= 10 ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 72 : 60,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 11,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.white,
          shadows: const [Shadow(color: CupertinoColors.black, blurRadius: 4)],
        ),
        borderSide: isTouched
            ? BorderSide(
                color: CupertinoColors.white.withValues(alpha: 0.8),
                width: 2.5,
              )
            : const BorderSide(width: 0),
        badgeWidget: isTouched ? _buildBadge(cat.color) : null,
        badgePositionPercentageOffset: 1.1,
      );
    });
  }

  Widget _buildBadge(int color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, _) => Transform.scale(
        scale: _pulseAnimation.value,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Color(color),
            shape: BoxShape.circle,
            border: Border.all(color: CupertinoColors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Color(color).withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Center Label ───────────────────────────────────────────────────────────

  Widget _buildCenterLabel(
    List<MapEntry<String, double>> entries,
    bool isDark,
  ) {
    // Rebuild the chart only when hide-amounts changes, not on unrelated
    // settings churn (e.g. the twice-per-refresh isFetchingRates flag).
    context.select<SettingsProvider, bool>((s) => s.hideAmounts);
    final settings = context.read<SettingsProvider>();
    final bool hasTouched =
        _touchedIndex >= 0 && _touchedIndex < entries.length;
    final entry = hasTouched ? entries[_touchedIndex] : null;
    final cat = entry != null ? _categoryFor(entry.key) : null;
    final pct = (entry != null && widget.total > 0)
        ? (entry.value / widget.total * 100)
        : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: hasTouched && cat != null
          ? Column(
              key: ValueKey('touched_$_touchedIndex'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(cat.color).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      ExpenseCategoriesScreen.iconForCode(cat.icon),
                      size: 18,
                      color: Color(cat.color),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  settings.formatMoney(entry!.value, widget.currency),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(cat.color),
                  ),
                ),
                if (pct != null)
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
              ],
            )
          : Column(
              key: const ValueKey('total'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.hideAmounts ? '' : widget.currency,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? CupertinoColors.systemGrey2
                        : CupertinoColors.systemGrey,
                  ),
                ),
                Text(
                  settings.formatMoney(widget.total, widget.currency),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? CupertinoColors.white
                        : const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${widget.expensesByCategory.length} categories',
                  style: const TextStyle(
                    fontSize: 10,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend(List<MapEntry<String, double>> entries, bool isDark) {
    context.select<SettingsProvider, bool>((s) => s.hideAmounts);
    final settings = context.read<SettingsProvider>();
    return Column(
      children: List.generate(entries.length, (i) {
        final entry = entries[i];
        final cat = _categoryFor(entry.key);
        final pct = widget.total > 0 ? (entry.value / widget.total * 100) : 0.0;
        final isSelected = i == _touchedIndex;
        final barWidth = widget.total > 0 ? (entry.value / widget.total) : 0.0;

        final row = GestureDetector(
          onTap: () => setState(() => _touchedIndex = isSelected ? -1 : i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Color(cat.color).withValues(alpha: 0.08)
                  : (isDark
                        ? AppColors.cardDark
                        : AppColors.cardBackground(context)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Color(cat.color).withValues(alpha: 0.4)
                    : (isDark
                          ? AppColors.cardBorderDark
                          : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(cat.color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          ExpenseCategoriesScreen.iconForCode(cat.icon),
                          size: 16,
                          color: Color(cat.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                cat.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.label.resolveFrom(context),
                                ),
                              ),
                              Text(
                                settings.formatMoney(
                                  entry.value,
                                  widget.currency,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(cat.color),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(
                                    cat.color,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(cat.color),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(
                                  height: 4,
                                  color: Color(
                                    cat.color,
                                  ).withValues(alpha: 0.12),
                                ),
                                AnimatedFractionallySizedBox(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  widthFactor: barWidth.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(
                                            cat.color,
                                          ).withValues(alpha: 0.7),
                                          Color(cat.color),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        if (!widget.animate) return row;
        return row
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideX(begin: 0.06, end: 0);
      }),
    );
  }

  Widget _maybeAnimate(Widget child) {
    if (!widget.animate) return child;
    return child
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
  }
}
