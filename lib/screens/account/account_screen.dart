import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/services/database_helper.dart';
import '../../core/sync/firebase_auth_service.dart';
import '../../core/utils/app_layout.dart';
import '../../core/utils/no_animation_route.dart';
import '../../core/widgets/app_list_section.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static Future<bool> confirm(
    BuildContext context,
    String title,
    String message, {
    bool destructive = false,
  }) async =>
      await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title.tr()),
          content: Text(message.tr()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.pop(context, true),
              child: Text('confirm'.tr()),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final sync = account.sync;
    final disabled =
        account.working || account.switching || (sync?.busy ?? false);
    final groups = account.conflicts
        .map((c) => c['group_key']! as String)
        .toSet();
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(middle: Text('accountSync'.tr())),
      child: SafeArea(
        child: AppLayout.constrain(
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(CupertinoIcons.person_crop_circle, size: 58),
              const SizedBox(height: 12),
              Text(
                'accountSync'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (account.user?.email != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(account.user!.email, textAlign: TextAlign.center),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'accountDescription'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'accountFilesLocal'.tr(),
                  textAlign: TextAlign.center,
                ),
              ),
              if (!account.configured) ...[
                _Message(
                  FirebaseAuthService.instance.initializationError ??
                      'accountUnavailable',
                ),
                const SizedBox(height: 12),
                Text('accountGuestInfo'.tr(), textAlign: TextAlign.center),
              ] else if (account.user == null) ...[
                if (account.workingLocally) _Message('accountWorkingLocally'),
                const _EmailAccountForm(),
                const SizedBox(height: 12),
                Text('accountGuestInfo'.tr(), textAlign: TextAlign.center),
              ] else ...[
                AppListSection(
                  children: [
                    CupertinoListTile(
                      title: Text('syncStatus'.tr()),
                      trailing: sync?.busy == true
                          ? const CupertinoActivityIndicator()
                          : Text(
                              sync?.errorKey != null
                                  ? 'syncWaiting'.tr()
                                  : groups.isNotEmpty
                                  ? 'syncNeedsReview'.tr()
                                  : (sync?.pendingCount ?? 0) > 0
                                  ? 'syncPending'.tr()
                                  : 'syncUpToDate'.tr(),
                            ),
                    ),
                    CupertinoListTile(
                      title: Text('syncPendingChanges'.tr()),
                      trailing: Text('${sync?.pendingCount ?? 0}'),
                    ),
                    CupertinoListTile(
                      title: Text('syncLast'.tr()),
                      trailing: Text(
                        sync?.lastSynced == null
                            ? 'syncNever'.tr()
                            : DateFormat.yMd(
                                context.locale.languageCode,
                              ).add_Hm().format(sync!.lastSynced!),
                      ),
                    ),
                    CupertinoListTile(
                      title: Text('syncNow'.tr()),
                      leading: const Icon(CupertinoIcons.arrow_2_circlepath),
                      onTap: disabled ? null : () => sync?.syncNow(),
                    ),
                  ],
                ),
                if (sync?.errorKey != null) _Message(sync!.errorKey!),
                if (account.importAvailable)
                  AppListSection(
                    children: [
                      CupertinoListTile(
                        title: Text('accountImport'.tr()),
                        subtitle: Text('accountImportMessage'.tr()),
                        onTap: disabled
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  'accountImportTitle',
                                  'accountImportMessage',
                                )) {
                                  await account.decideImport(
                                    import: true,
                                    guestPreferences:
                                        await SettingsProvider.guestPreferences(),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                AppListSection(
                  children: [
                    CupertinoListTile(
                      title: Text('accountSignOut'.tr()),
                      subtitle: Text('accountSignOutSubtitle'.tr()),
                      onTap: disabled
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                'accountSignOut',
                                'accountSignOutMessage',
                              )) {
                                await account.signOut();
                              }
                            },
                    ),
                    CupertinoListTile(
                      title: Text('accountClearCache'.tr()),
                      subtitle: Text('accountClearCacheSubtitle'.tr()),
                      onTap: disabled
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                'accountClearCache',
                                'accountClearCacheMessage',
                              )) {
                                await account.clearDeviceCache();
                              }
                            },
                    ),
                    CupertinoListTile(
                      title: Text(
                        'accountDelete'.tr(),
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                      onTap: disabled
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                'accountDelete',
                                'accountDeleteMessage',
                                destructive: true,
                              )) {
                                {
                                  if (!context.mounted) return;
                                  final password = await _passwordForDeletion(
                                    context,
                                  );
                                  if (password != null && password.isNotEmpty) {
                                    await account.deleteAccount(password);
                                  }
                                }
                              }
                            },
                    ),
                  ],
                ),
              ],
              if (groups.isNotEmpty)
                AppListSection(
                  header: Text('syncConflicts'.tr()),
                  children: [
                    for (final group in groups)
                      CupertinoListTile(
                        title: Text('syncReviewChanges'.tr()),
                        subtitle: Text(_groupTitle(group, account.conflicts)),
                        trailing: const CupertinoListTileChevron(),
                        onTap: disabled
                            ? null
                            : () => Navigator.of(context).push(
                                NoAnimationPageRoute(
                                  builder: (_) => _ConflictScreen(group: group),
                                ),
                              ),
                      ),
                  ],
                ),
              if (account.errorKey != null) _Message(account.errorKey!),
              if (account.working)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CupertinoActivityIndicator(),
                ),
            ],
          ),
          maxWidth: 700,
        ),
      ),
    );
  }

  Future<String?> _passwordForDeletion(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('accountConfirmPassword'.tr()),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              obscureText: true,
              placeholder: 'accountPassword'.tr(),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('accountDelete'.tr()),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _groupTitle(String group, List<Map<String, Object?>> conflicts) {
    final first = conflicts.firstWhere((c) => c['group_key'] == group);
    final remote = jsonDecode(first['remote']! as String) as Map;
    final data = remote['payload'] as Map;
    return (data['name'] ??
            data['title'] ??
            data['content'] ??
            'syncRelatedChanges'.tr())
        .toString();
  }
}

class _Message extends StatelessWidget {
  const _Message(this.keyName);
  final String keyName;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      keyName.tr(),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

class _ConflictScreen extends StatefulWidget {
  const _ConflictScreen({required this.group});
  final String group;
  @override
  State<_ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<_ConflictScreen> {
  late Future<
    List<({Map<String, dynamic> remote, Map<String, dynamic>? local})>
  >
  _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<List<({Map<String, dynamic> remote, Map<String, dynamic>? local})>>
  _load() async {
    final remotes = await context.read<AccountProvider>().conflictDetails(
      widget.group,
    );
    final db = await DatabaseHelper.instance.database;
    final result =
        <({Map<String, dynamic> remote, Map<String, dynamic>? local})>[];
    for (final remote in remotes) {
      final entity = remote['entity'] as String;
      final payload = remote['payload'] as Map;
      final rows = await db.query(
        entity,
        where: entity == 'task_assignees' ? 'taskId=? AND memberId=?' : 'id=?',
        whereArgs: entity == 'task_assignees'
            ? [payload['taskId'], payload['memberId']]
            : [payload['id']],
      );
      result.add((
        remote: remote,
        local: rows.isEmpty ? null : Map<String, dynamic>.from(rows.first),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final sync = account.sync;
    return CupertinoPageScaffold(
      navigationBar: AppNavigationBar(middle: Text('syncReviewChanges'.tr())),
      child: SafeArea(
        child: AppLayout.constrain(
          FutureBuilder(
            future: _details,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('syncRetryError'.tr()),
                      CupertinoButton(
                        onPressed: () => setState(() => _details = _load()),
                        child: Text('syncNow'.tr()),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    (snapshot.data!.any((i) => i.remote['source'] == 'backup')
                            ? 'backupConflictExplanation'
                            : 'syncConflictExplanation')
                        .tr(),
                  ),
                  const SizedBox(height: 16),
                  for (final item in snapshot.data!)
                    AppListSection(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'syncThisDevice'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _Version(data: item.local),
                              const SizedBox(height: 16),
                              Text(
                                (item.remote['source'] == 'backup'
                                        ? 'backupVersion'
                                        : 'syncCloudVersion')
                                    .tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _Version(
                                data: item.remote['deleted'] == true
                                    ? null
                                    : Map<String, dynamic>.from(
                                        item.remote['payload'] as Map,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  for (final keepLocal in [true, false])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: CupertinoButton.filled(
                        onPressed:
                            account.working ||
                                account.switching ||
                                sync?.busy == true
                            ? null
                            : () async {
                                await account.resolveConflict(
                                  widget.group,
                                  keepLocal: keepLocal,
                                );
                                if (context.mounted &&
                                    account.errorKey == null &&
                                    !account.conflicts.any(
                                      (c) => c['group_key'] == widget.group,
                                    )) {
                                  Navigator.pop(context);
                                }
                              },
                        child: Text(
                          (keepLocal
                                  ? 'syncKeepDevice'
                                  : snapshot.data!.any(
                                      (i) => i.remote['source'] == 'backup',
                                    )
                                  ? 'backupUseVersion'
                                  : 'syncKeepCloud')
                              .tr(),
                        ),
                      ),
                    ),
                  if (sync?.busy == true) const CupertinoActivityIndicator(),
                  if (sync?.errorKey != null) _Message(sync!.errorKey!),
                  if (account.errorKey != null) _Message(account.errorKey!),
                ],
              );
            },
          ),
          maxWidth: 800,
        ),
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({required this.data});
  final Map<String, dynamic>? data;
  static const fields = [
    'name',
    'title',
    'content',
    'description',
    'details',
    'status',
    'cost',
    'amount',
    'currency',
    'startDate',
    'endDate',
    'date',
    'isPaid',
    'timeSpentInSeconds',
    'estimatedTime',
    'hourlyRate',
    'note',
    'phone',
    'email',
    'startingBalance',
    'value',
  ];
  @override
  Widget build(BuildContext context) {
    if (data == null) return Text('syncDeleted'.tr());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in fields)
          if (data![key] != null && data![key].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${'syncField_$key'.tr()}: ${_value(key, data![key])}',
              ),
            ),
        if (data!['attachments'] != null)
          Text(
            'syncAttachmentCount'.tr(
              namedArgs: {
                'count':
                    '${(jsonDecode(data!['attachments'] as String) as List).length}',
              },
            ),
          ),
        if (data!['subTasks'] != null)
          for (final sub in (jsonDecode(data!['subTasks'] as String) as List))
            Text(
              '${sub['isDone'] == true ? '✓' : '○'} ${sub['text'] ?? sub['title'] ?? sub['name'] ?? ''}',
            ),
      ],
    );
  }

  String _value(String key, dynamic value) {
    if (key == 'isPaid') return (value == 1 ? 'paid' : 'unpaid').tr();
    if (key == 'status') return value.toString().tr();
    return value.toString();
  }
}

class _EmailAccountForm extends StatefulWidget {
  const _EmailAccountForm();
  @override
  State<_EmailAccountForm> createState() => _EmailAccountFormState();
}

class _EmailAccountFormState extends State<_EmailAccountForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _register = false;
  String? _message;

  Future<void> _submit() async {
    final account = context.read<AccountProvider>();
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _message = 'accountInvalidEmail');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _message = 'accountWeakPassword');
      return;
    }
    if (_register && _password.text != _confirmation.text) {
      setState(() => _message = 'accountPasswordsDiffer');
      return;
    }
    setState(() => _message = null);
    await account.authenticate(
      _email.text,
      _password.text,
      register: _register,
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    return AutofillGroup(
      child: Column(
        children: [
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: _register,
            children: {
              false: Text('accountSignIn'.tr()),
              true: Text('accountRegister'.tr()),
            },
            onValueChanged: (value) {
              if (account.working) return;
              setState(() {
                _register = value ?? false;
                _message = null;
              });
            },
          ),
          const SizedBox(height: 20),
          CupertinoTextField(
            controller: _email,
            enabled: !account.working,
            placeholder: 'accountEmail'.tr(),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.next,
            padding: const EdgeInsets.all(14),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _password,
            enabled: !account.working,
            placeholder: 'accountPassword'.tr(),
            obscureText: true,
            autofillHints: [
              _register ? AutofillHints.newPassword : AutofillHints.password,
            ],
            onSubmitted: (_) {
              if (!_register) _submit();
            },
            padding: const EdgeInsets.all(14),
          ),
          if (_register) ...[
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _confirmation,
              enabled: !account.working,
              placeholder: 'accountConfirmPassword'.tr(),
              obscureText: true,
              onSubmitted: (_) => _submit(),
              padding: const EdgeInsets.all(14),
            ),
          ],
          const SizedBox(height: 20),
          CupertinoButton.filled(
            onPressed: account.working ? null : _submit,
            child: Text((_register ? 'accountRegister' : 'accountSignIn').tr()),
          ),
          CupertinoButton(
            onPressed: account.working
                ? null
                : () async {
                    if (!_email.text.contains('@')) {
                      setState(() => _message = 'accountInvalidEmail');
                      return;
                    }
                    final sent = await account.resetPassword(_email.text);
                    if (mounted && sent) {
                      setState(() => _message = 'accountPasswordResetSent');
                    }
                  },
            child: Text('accountForgotPassword'.tr()),
          ),
          if (_message != null) _Message(_message!),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}
