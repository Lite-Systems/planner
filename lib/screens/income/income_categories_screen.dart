import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/models/income_category.dart';
import 'package:planner/providers/income_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class IncomeCategoriesScreen extends StatelessWidget {
  const IncomeCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(
        middle: Text('incomeCategories'.tr()),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showDialog(context, null),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: AppLayout.constrain(
          Consumer<IncomeProvider>(
            builder: (_, provider, _) {
              return ListView(
                children: provider.categories
                    .map(
                      (cat) => Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        decoration: AppCard.container(context),
                        child: CupertinoListTile(
                          title: Text(cat.name),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final deleted = await provider.deleteCategory(
                                cat.id,
                              );
                              if (!deleted && context.mounted) {
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
                            child: const Icon(
                              CupertinoIcons.delete,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          maxWidth: 880,
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, IncomeCategory? existing) {
    final controller = TextEditingController(text: existing?.name ?? '');
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(
          existing == null ? 'addCategory'.tr() : 'editCategory'.tr(),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            decoration: AppCard.container(context, radius: AppRadius.md),
            controller: controller,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: Text('save'.tr()),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              final provider = Provider.of<IncomeProvider>(
                context,
                listen: false,
              );
              provider.addCategory(
                IncomeCategory(
                  id: existing?.id ?? const Uuid().v4(),
                  name: controller.text.trim(),
                  color: 0xFF10B981,
                  icon: 0xe0af,
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
