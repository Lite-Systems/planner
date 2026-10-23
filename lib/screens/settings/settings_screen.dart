import 'dart:io';

import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/widgets/app_list_section.dart';
import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../account/account_screen.dart';
import '../../providers/locale_provider.dart';
import '../../core/services/database_backup_service.dart';
import '../../core/services/database_helper.dart';
import '../../core/services/macos_widget_service.dart';
import 'payment_methods_screen.dart';
import 'archive_screen.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/project_provider.dart';
import '../../core/widgets/restart_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(middle: Text('settings'.tr())),
      child: SafeArea(
        child: AppLayout.constrain(
          const RepaintBoundary(child: _SettingsList()),
          maxWidth: 880,
        ),
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList();

  Future<File?> _prepareBackup(BuildContext context) async {
    final account = context.read<AccountProvider?>();
    if (account == null) return DatabaseBackupService.createBackupFile();
    return account.exportDatabase(
      allowLocalSnapshot: () async {
        if (!context.mounted) return false;
        return AccountScreen.confirm(
          context,
          'backupLocalTitle',
          'backupLocalMessage',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDesktop =
        AppLayout.of(context).isDesktop ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    return Consumer2<LocaleProvider, SettingsProvider>(
      builder: (context, localeProvider, settings, _) {
        return ListView(
          primary: true,
          physics: const ClampingScrollPhysics(),
          addAutomaticKeepAlives: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16.0),
          children: [
            if (context.watch<AccountProvider?>() != null)
              AppListSection(
                margin: const EdgeInsets.all(8),
                children: [
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.person_crop_circle),
                    title: Text('accountSync'.tr()),
                    subtitle: Text(
                      context.watch<AccountProvider>().user?.email ??
                          (context.watch<AccountProvider>().workingLocally
                              ? 'accountWorkingLocally'.tr()
                              : 'accountGuestInfo'.tr()),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      NoAnimationPageRoute(
                        builder: (_) => const AccountScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            // Language Selection
            AppListSection(
              margin: EdgeInsets.all(8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Text(
                        'language'.tr(),
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                      CupertinoSlidingSegmentedControl<String>(
                        backgroundColor: AppColors.elevatedBackground(context),
                        thumbColor: AppColors.cardBackground(context),
                        groupValue: context.locale.languageCode,
                        children: {
                          'en': Text(
                            'english'.tr(),
                            style: TextStyle(
                              color: context.locale.languageCode == 'en'
                                  ? (settings.isDarkMode
                                        ? CupertinoColors.white
                                        : CupertinoColors.black)
                                  : CupertinoColors.secondaryLabel.resolveFrom(
                                      context,
                                    ),
                              fontWeight: context.locale.languageCode == 'en'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          'ar': Text(
                            'arabic'.tr(),
                            style: TextStyle(
                              color: context.locale.languageCode == 'ar'
                                  ? (settings.isDarkMode
                                        ? CupertinoColors.white
                                        : CupertinoColors.black)
                                  : CupertinoColors.secondaryLabel.resolveFrom(
                                      context,
                                    ),
                              fontWeight: context.locale.languageCode == 'ar'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        },
                        onValueChanged: (value) async {
                          if (value != null &&
                              value != context.locale.languageCode) {
                            await showCupertinoDialog(
                              useRootNavigator: false,
                              context: context,
                              builder: (_) => CupertinoAlertDialog(
                                title: Text('changeLanguage'.tr()),
                                content: Text(
                                  'changeLanguageConfirmation'.tr(),
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () => Navigator.pop(context),
                                    isDestructiveAction: false,
                                    child: Text('cancel'.tr()),
                                  ),
                                  CupertinoDialogAction(
                                    isDefaultAction: true,
                                    child: Text('ok'.tr()),
                                    onPressed: () async {
                                      // Navigator.pop(context);
                                      await localeProvider.setLocale(
                                        context,
                                        Locale(value),
                                      );
                                      if (context.mounted) {
                                        // Reload providers to update translated data
                                        await Provider.of<WalletProvider>(
                                          context,
                                          listen: false,
                                        ).loadData();
                                        if (context.mounted) {
                                          await Provider.of<ProjectProvider>(
                                            context,
                                            listen: false,
                                          ).loadData();
                                        }
                                        if (context.mounted) {
                                          // Pop the dialog
                                          Navigator.of(context).pop();
                                          // Pop back to home to refresh the entire view
                                          Navigator.of(
                                            context,
                                          ).popUntil((route) => route.isFirst);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Currency Selection
            AppListSection(
              margin: EdgeInsets.all(8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Text(
                        'currency'.tr(),
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                      CupertinoSlidingSegmentedControl<String>(
                        backgroundColor: AppColors.elevatedBackground(context),
                        thumbColor: AppColors.cardBackground(context),
                        groupValue: settings.currency,
                        children: {
                          for (final code in ['EGP', 'USD', 'SAR'])
                            code: Text(
                              code.tr(),
                              style: TextStyle(
                                color: settings.currency == code
                                    ? (settings.isDarkMode
                                          ? CupertinoColors.white
                                          : CupertinoColors.black)
                                    : CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                fontWeight: settings.currency == code
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                        },
                        onValueChanged: (value) {
                          if (value != null) {
                            settings.setCurrency(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Expenses Currency Selection
            AppListSection(
              margin: EdgeInsets.all(8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'expensesCurrency'.tr(),
                                  style: CupertinoTheme.of(
                                    context,
                                  ).textTheme.textStyle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'expensesCurrencySubtitle'.tr(),
                                  style: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .copyWith(
                                        fontSize: 12,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSlidingSegmentedControl<String>(
                            backgroundColor: AppColors.elevatedBackground(
                              context,
                            ),
                            thumbColor: AppColors.cardBackground(context),
                            groupValue: settings.expensesCurrency,
                            children: {
                              for (final code in ['USD', 'EGP', 'SAR'])
                                code: Text(
                                  code.tr(),
                                  style: TextStyle(
                                    color: settings.expensesCurrency == code
                                        ? (settings.isDarkMode
                                              ? CupertinoColors.white
                                              : CupertinoColors.black)
                                        : CupertinoColors.secondaryLabel
                                              .resolveFrom(context),
                                    fontWeight:
                                        settings.expensesCurrency == code
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                            },
                            onValueChanged: (value) {
                              if (value != null) {
                                settings.setExpensesCurrency(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Hour Cost
            AppListSection(
              margin: EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  title: Text('hourCost'.tr()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(settings.formatMoney(settings.hourCost)),
                      const SizedBox(width: 8),
                      const CupertinoListTileChevron(),
                    ],
                  ),
                  onTap: () {
                    final controller = TextEditingController(
                      text: settings.hourCost.toString(),
                    );
                    showCupertinoDialog(
                      useRootNavigator: false,
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text('editHourCost'.tr()),
                        content: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: CupertinoTextField(
                            decoration: AppCard.container(
                              context,
                              radius: AppRadius.md,
                            ),
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            placeholder: 'enterHourCost'.tr(),
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
                              final value =
                                  double.tryParse(controller.text) ?? 0.0;
                              settings.setHourCost(value);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            // App lock
            AppListSection(
              margin: EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  title: Text('lockApp'.tr()),
                  subtitle: Text('lockAppSubtitle'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.isBiometricEnabled,
                    onChanged: (value) {
                      settings.setBiometricEnabled(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  title: Text('hideAmounts'.tr()),
                  subtitle: Text('hideAmountsSubtitle'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.hideAmounts,
                    onChanged: (value) {
                      settings.setHideAmounts(value);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Printing Settings
            AppListSection(
              header: Text(
                'printingSettings'.tr(),
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
              margin: const EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  title: Text('showHourCostInPrint'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.showHourCostInPrint,
                    onChanged: (value) {
                      settings.setShowHourCostInPrint(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  title: Text('showTaskTimeInPrint'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.showTaskTimeInPrint,
                    onChanged: (value) {
                      settings.setShowTaskTimeInPrint(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  title: Text('showTaskTypeInPrint'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.showTaskTypeInPrint,
                    onChanged: (value) {
                      settings.setShowTaskTypeInPrint(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  title: Text('showSubtasksInPrint'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.showSubtasksInPrint,
                    onChanged: (value) {
                      settings.setShowSubtasksInPrint(value);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // ── Modules ──────────────────────────────────────────────
            AppListSection(
              header: Text(
                'modules'.tr(),
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
              margin: const EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.receipt,
                    color: CupertinoColors.systemPink,
                    size: 20,
                  ),
                  title: Text('expensesModule'.tr()),
                  subtitle: Text('expensesModuleSubtitle'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.isExpensesEnabled,
                    onChanged: (value) {
                      settings.setExpensesEnabled(value);
                    },
                  ),
                ),
                CupertinoListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.listCheck,
                    color: CupertinoColors.systemIndigo,
                    size: 20,
                  ),
                  title: Text('todoModule'.tr()),
                  subtitle: Text('todoModuleSubtitle'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.isTodosEnabled,
                    onChanged: (value) {
                      settings.setTodosEnabled(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Dark Mode ─────────────────────────────────────────────
            AppListSection(
              margin: const EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.moon_fill,
                    color: CupertinoColors.systemPurple,
                  ),
                  title: Text('darkMode'.tr()),
                  trailing: CupertinoSwitch(
                    activeTrackColor: AppColors.primary,
                    value: settings.isDarkMode,
                    onChanged: (value) {
                      settings.setDarkMode(value);
                    },
                  ),
                ),
              ],
            ),
            if (showDesktop) ...[
              const SizedBox(height: 16),
              AppListSection(
                header: Text(
                  'desktopSettings'.tr(),
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
                margin: const EdgeInsets.all(8),
                children: [
                  CupertinoListTile(
                    title: Text('compactDensity'.tr()),
                    subtitle: Text('compactDensitySubtitle'.tr()),
                    trailing: CupertinoSwitch(
                      activeTrackColor: AppColors.primary,
                      value: settings.compactDensity,
                      onChanged: settings.setCompactDensity,
                    ),
                  ),
                  CupertinoListTile(
                    title: Text('rememberLastSection'.tr()),
                    subtitle: Text('rememberLastSectionSubtitle'.tr()),
                    trailing: CupertinoSwitch(
                      activeTrackColor: AppColors.primary,
                      value: settings.rememberLastSection,
                      onChanged: settings.setRememberLastSection,
                    ),
                  ),
                  CupertinoListTile(
                    title: Text('keyboardShortcuts'.tr()),
                    subtitle: Text('keyboardShortcutsSubtitle'.tr()),
                    trailing: CupertinoSwitch(
                      activeTrackColor: AppColors.primary,
                      value: settings.keyboardShortcuts,
                      onChanged: settings.setKeyboardShortcuts,
                    ),
                  ),
                  if (MacosWidgetService.isSupported) ...[
                    CupertinoListTile(
                      title: Text('macosWidget'.tr()),
                      subtitle: Text('macosWidgetSubtitle'.tr()),
                      trailing: CupertinoSwitch(
                        activeTrackColor: AppColors.primary,
                        value: settings.macosWidgetEnabled,
                        onChanged: (value) async {
                          try {
                            await context.read<MacosWidgetService>().setEnabled(
                              value,
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            final messageKey = switch (error) {
                              PlatformException(
                                code: 'widget_app_group_unavailable',
                              ) =>
                                'macosWidgetUnavailable',
                              PlatformException(
                                code: 'widget_extension_missing',
                              ) =>
                                'macosWidgetExtensionMissing',
                              _ => 'macosWidgetEnableFailed',
                            };
                            await showCupertinoDialog<void>(
                              useRootNavigator: false,
                              context: context,
                              builder: (dialogContext) => CupertinoAlertDialog(
                                title: Text('macosWidget'.tr()),
                                content: Text(messageKey.tr()),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: Text('ok'.tr()),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    CupertinoListTile(
                      title: Text('addMacosWidget'.tr()),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => showCupertinoDialog<void>(
                        useRootNavigator: false,
                        context: context,
                        builder: (dialogContext) => CupertinoAlertDialog(
                          title: Text('addMacosWidget'.tr()),
                          content: Text('macosWidgetInstructions'.tr()),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text('ok'.tr()),
                            ),
                            CupertinoDialogAction(
                              child: Text('openMacosWidgetSettings'.tr()),
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                try {
                                  await context
                                      .read<MacosWidgetService>()
                                      .openSettings();
                                } catch (_) {
                                  // The dialog also contains the complete manual steps.
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Payment Methods
            CupertinoListTile(
              padding: EdgeInsets.all(0),
              leading: const FaIcon(
                FontAwesomeIcons.creditCard,
                color: CupertinoColors.systemTeal,
                size: 20,
              ),
              title: Text('paymentMethods'.tr()),
              subtitle: Text('paymentMethodsSubtitle'.tr()),
              trailing: const CupertinoListTileChevron(),
              onTap: () {
                Navigator.push(
                  context,
                  NoAnimationPageRoute(
                    builder: (_) => const PaymentMethodsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            CupertinoListTile(
              padding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.boxArchive,
                color: CupertinoColors.systemOrange,
                size: 20,
              ),
              title: Text('taskArchive'.tr()),
              subtitle: Text('taskArchiveSubtitle'.tr()),
              trailing: const CupertinoListTileChevron(),
              onTap: () {
                Navigator.push(
                  context,
                  NoAnimationPageRoute(
                    builder: (_) => const TaskArchiveScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Database Backup
            AppListSection(
              header: Text(
                'databaseBackup'.tr(),
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
              margin: const EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.cloudArrowUp,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text('exportDatabase'.tr()),
                  subtitle: Text('exportDatabaseSubtitle'.tr()),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () async {
                    try {
                      final backup = await _prepareBackup(context);
                      if (backup == null) return;
                      await DatabaseBackupService.createAndShareBackup(
                        backup: backup,
                      );
                      if (context.mounted) {
                        showCupertinoDialog(
                          useRootNavigator: false,
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              'done'.tr(),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                            content: Text(
                              'backupSuccess'.tr(),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.copyWith(fontSize: 14),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: Text('ok'.tr()),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showCupertinoDialog(
                          useRootNavigator: false,
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              'invalidInput'.tr(),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                            content: Text(
                              'backupError'.tr(
                                namedArgs: {'error': e.toString()},
                              ),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.copyWith(fontSize: 14),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: Text('ok'.tr()),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                ),
                CupertinoListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.hardDrive,
                    color: CupertinoColors.systemTeal,
                    size: 20,
                  ),
                  title: Text('saveBackup'.tr()),
                  subtitle: Text('saveBackupSubtitle'.tr()),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () async {
                    try {
                      final backup = await _prepareBackup(context);
                      if (backup == null) return;
                      final saved =
                          await DatabaseBackupService.saveBackupToStorage(
                            backup: backup,
                          );
                      if (saved && context.mounted) {
                        showCupertinoDialog(
                          useRootNavigator: false,
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              'done'.tr(),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                            content: Text(
                              'saveBackupSuccess'.tr(),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.copyWith(fontSize: 14),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: Text('ok'.tr()),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showCupertinoDialog(
                          useRootNavigator: false,
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              'invalidInput'.tr(),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                            content: Text(
                              'backupError'.tr(
                                namedArgs: {'error': e.toString()},
                              ),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.copyWith(fontSize: 14),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: Text('ok'.tr()),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                ),
                CupertinoListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.cloudArrowDown,
                    color: CupertinoColors.systemOrange,
                    size: 20,
                  ),
                  title: Text('importDatabase'.tr()),
                  subtitle: Text('importDatabaseSubtitle'.tr()),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () async {
                    try {
                      final account = context.read<AccountProvider?>();
                      final workspaceId = account?.workspaceId;
                      final path = await DatabaseBackupService.pickBackupPath();
                      if (path == null || !context.mounted) return;
                      if (account?.workspaceId != workspaceId) {
                        throw StateError(
                          'The active planner changed while choosing a backup. Please select the file again.',
                        );
                      }
                      if (account == null) {
                        await DatabaseBackupService.restoreBackup(path);
                      } else {
                        await account.importDatabase(path);
                      }
                      if (context.mounted) {
                        showCupertinoDialog(
                          useRootNavigator: false,
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              'done'.tr(),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                            content: Text(
                              'restoreSuccess'.tr(),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.copyWith(fontSize: 14),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: Text('ok'.tr()),
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (account == null) {
                                    RestartWidget.restartApp(context);
                                  } else if (account.conflicts.isNotEmpty) {
                                    Navigator.of(context).push(
                                      NoAnimationPageRoute(
                                        builder: (_) => const AccountScreen(),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showCupertinoDialog(
                          useRootNavigator: false,
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              'invalidInput'.tr(),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                            ),
                            content: Text(
                              'restoreError'.tr(
                                namedArgs: {'error': e.toString()},
                              ),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.textStyle.copyWith(fontSize: 14),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: Text('ok'.tr()),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Reset Database
            AppListSection(
              margin: const EdgeInsets.all(8),
              children: [
                CupertinoListTile(
                  leading: const FaIcon(
                    FontAwesomeIcons.trashCan,
                    color: CupertinoColors.systemRed,
                    size: 20,
                  ),
                  title: Text(
                    'resetDatabase'.tr(),
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                  subtitle: Text('resetDatabaseSubtitle'.tr()),
                  onTap: () {
                    if (DatabaseHelper.instance.accountId != null) {
                      Navigator.of(context).push(
                        NoAnimationPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                      return;
                    }
                    showCupertinoDialog(
                      useRootNavigator: false,
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(
                          'resetDatabaseConfirmTitle'.tr(),
                          style: CupertinoTheme.of(context).textTheme.textStyle
                              .copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                        ),
                        content: Text(
                          'resetDatabaseConfirmMessage'.tr(),
                          style: CupertinoTheme.of(
                            context,
                          ).textTheme.textStyle.copyWith(fontSize: 14),
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: Text('cancel'.tr()),
                            onPressed: () => Navigator.pop(context),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: Text('reset'.tr()),
                            onPressed: () async {
                              await DatabaseHelper.instance.resetDatabase();
                              if (context.mounted) {
                                Navigator.pop(context);
                                RestartWidget.restartApp(context);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
