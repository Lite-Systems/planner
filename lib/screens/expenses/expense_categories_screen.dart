import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/expense_category.dart';
import '../../../providers/expenses_provider.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/app_layout.dart';

class ExpenseCategoriesScreen extends StatelessWidget {
  const ExpenseCategoriesScreen({super.key});

  /// Public static helper so other widgets (ExpenseCard, etc.) can reuse.
  static IconData iconForCode(int code) {
    const iconMap = {
      0xe8b8: CupertinoIcons.tag,
      0xe3b7: CupertinoIcons.wrench,
      0xe0af: CupertinoIcons.briefcase,
      0xe1d5: CupertinoIcons.airplane,
      0xe8f0: CupertinoIcons.repeat,
      0xe862: CupertinoIcons.cart,
      0xe226: CupertinoIcons.flame,
      0xe531: CupertinoIcons.heart_circle,
      0xe80b: CupertinoIcons.heart,
      0xe87f: CupertinoIcons.house,
      0xe559: CupertinoIcons.car,
      0xe8cc: CupertinoIcons.creditcard,
    };
    return iconMap[code] ?? CupertinoIcons.tag;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(
        middle: Text('expenseCategories'.tr()),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showCategoryDialog(context, null),
          child: const Icon(CupertinoIcons.add_circled_solid),
        ),
      ),
      child: SafeArea(
        child: Consumer<ExpensesProvider>(
          builder: (_, provider, child) {
            final categories = provider.categories;
            if (categories.isEmpty) {
              return _buildEmptyState(context);
            }
            return _CategoryList(
              itemCount: categories.length,
              itemBuilder: (context, i) =>
                  _buildCategoryItem(context, categories[i], provider, i),
            );
          },
        ),
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.expensePrimary.withValues(alpha: 0.12),
                  AppColors.expenseSecondary.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.tag,
              size: 36,
              color: AppColors.expensePrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'noCategories'.tr(),
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Category List Item ──────────────────────────────────────────────────────

  Widget _buildCategoryItem(
    BuildContext context,
    ExpenseCategory cat,
    ExpensesProvider provider,
    int index,
  ) {
    final catColor = Color(cat.color);

    return Dismissible(
      key: Key(cat.id),
      direction: cat.isDefault
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (cat.isDefault) return false;
        _confirmDelete(context, cat, provider);
        return false; // we handle deletion ourselves in _confirmDelete
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.delete_solid,
              color: CupertinoColors.white,
              size: 22,
            ),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _showCategoryDialog(context, cat),
        onLongPress: () => _showActionSheet(context, cat, provider),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.separator(context), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: catColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        catColor.withValues(alpha: 0.2),
                        catColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: catColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(iconForCode(cat.icon), color: catColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Name & badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (cat.isDefault) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.elevatedBackground(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'defaultCategory'.tr(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Color swatch
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: catColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: catColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Action button
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  onPressed: () => _showActionSheet(context, cat, provider),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.elevatedBackground(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      size: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Action Sheet ────────────────────────────────────────────────────────────

  void _showActionSheet(
    BuildContext context,
    ExpenseCategory cat,
    ExpensesProvider provider,
  ) {
    showCupertinoModalPopup<void>(
      useRootNavigator: false,
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(
          cat.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        message: cat.isDefault
            ? Text('defaultCategory'.tr())
            : const Text('Choose an action'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showCategoryDialog(context, cat);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.pencil,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'editCategory'.tr(),
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          if (!cat.isDefault)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(context, cat, provider);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.delete,
                    size: 18,
                    color: CupertinoColors.destructiveRed,
                  ),
                  const SizedBox(width: 8),
                  Text('deleteCategory'.tr()),
                ],
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

  // ── Delete Confirmation ─────────────────────────────────────────────────────

  void _confirmDelete(
    BuildContext context,
    ExpenseCategory cat,
    ExpensesProvider provider,
  ) {
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('deleteCategory'.tr()),
        content: Text(
          'deleteCategoryConfirm'.tr(namedArgs: {'name': cat.name}),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final deleted = await provider.deleteCategory(cat.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!deleted) {
                showCupertinoDialog(
                  useRootNavigator: false,
                  context: context,
                  builder: (_) => CupertinoAlertDialog(
                    title: Text('cannotDelete'.tr()),
                    content: Text('categoryInUse'.tr()),
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

  // ── Add / Edit Dialog ───────────────────────────────────────────────────────

  void _showCategoryDialog(BuildContext context, ExpenseCategory? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final iconOptions = const [
      CupertinoIcons.tag,
      CupertinoIcons.wrench,
      CupertinoIcons.briefcase,
      CupertinoIcons.airplane,
      CupertinoIcons.repeat,
      CupertinoIcons.cart,
      CupertinoIcons.flame,
      CupertinoIcons.heart_circle,
      CupertinoIcons.heart,
      CupertinoIcons.house,
      CupertinoIcons.car,
      CupertinoIcons.creditcard,
    ];
    final iconCodes = iconOptions.map((ic) => ic.codePoint).toList();
    int selectedColor =
        existing?.color ?? AppColors.categoryPalette[0].toARGB32();
    int selectedIcon = existing?.icon ?? CupertinoIcons.tag.codePoint;

    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: Text(
            existing == null ? 'addCategory'.tr() : 'editCategory'.tr(),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              // Name field
              CupertinoTextField(
                controller: nameCtrl,
                placeholder: 'categoryName'.tr(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.elevatedBackground(ctx),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              // Section label: Color
              Text(
                'pickColor'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8),
              // Color picker
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppColors.categoryPalette.map((c) {
                  final isSelected = c.toARGB32() == selectedColor;
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColor = c.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: CupertinoColors.white, width: 3)
                            : Border.all(
                                color: CupertinoColors.white.withValues(
                                  alpha: 0,
                                ),
                                width: 0,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.55),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              CupertinoIcons.checkmark,
                              size: 14,
                              color: CupertinoColors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Section label: Icon
              Text(
                'pickIcon'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8),
              // Icon picker
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(iconOptions.length, (i) {
                  final iconData = iconOptions[i];
                  final iconCode = iconCodes[i];
                  final isSelected = iconCode == selectedIcon;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = iconCode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(selectedColor).withValues(alpha: 0.15)
                            : AppColors.elevatedBackground(ctx),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: Color(selectedColor),
                                width: 1.8,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(
                                    selectedColor,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        iconData,
                        size: 20,
                        color: isSelected
                            ? Color(selectedColor)
                            : CupertinoColors.systemGrey,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final provider = Provider.of<ExpensesProvider>(
                  ctx,
                  listen: false,
                );
                if (existing == null) {
                  await provider.addCategory(
                    ExpenseCategory(
                      id: const Uuid().v4(),
                      name: name,
                      color: selectedColor,
                      icon: selectedIcon,
                    ),
                  );
                } else {
                  await provider.updateCategory(
                    existing.copyWith(
                      name: name,
                      color: selectedColor,
                      icon: selectedIcon,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'create'.tr() : 'update'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Category list that plays its entrance animation only on the first frame
/// (and never on desktop), so scrolling an item back into view does not replay
/// the fade/slide.
class _CategoryList extends StatefulWidget {
  const _CategoryList({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<_CategoryList> {
  bool _entranceDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_entranceDone) setState(() => _entranceDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AppLayout.of(context).isDesktop;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: widget.itemCount,
      itemBuilder: (context, i) {
        final item = widget.itemBuilder(context, i);
        if (desktop || _entranceDone || i >= 8) return item;
        return item
            .animate(delay: Duration(milliseconds: i * 45))
            .fadeIn(duration: 280.ms)
            .slideX(begin: 0.05, end: 0);
      },
    );
  }
}
