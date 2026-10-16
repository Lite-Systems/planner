import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/models/project_member.dart';
import 'package:planner/providers/project_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class ProjectMembersSheet extends StatelessWidget {
  const ProjectMembersSheet({super.key, required this.projectId});

  final String projectId;

  static Future<void> show(BuildContext context, String projectId) {
    return showCupertinoModalPopup(
      context: context,
      builder: (_) => ProjectMembersSheet(projectId: projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout.sheet(
      context,
      Container(
        height: MediaQuery.sizeOf(context).height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.separator(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'members'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showMemberForm(context),
                      child: Text('addMember'.tr()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<ProjectProvider>(
                  builder: (_, provider, _) {
                    final members = provider.getMembers(projectId);
                    if (members.isEmpty) {
                      return Center(
                        child: Text(
                          'noMembers'.tr(),
                          style: TextStyle(
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: members.length,
                      separatorBuilder: (_, _) => Container(
                        height: 0.5,
                        color: AppColors.separator(context),
                      ),
                      itemBuilder: (_, i) {
                        final m = members[i];
                        return CupertinoListTile(
                          leading: _Avatar(member: m),
                          title: Text(m.name),
                          subtitle: m.phone != null && m.phone!.isNotEmpty
                              ? Text(m.phone!)
                              : (m.email != null && m.email!.isNotEmpty
                                    ? Text(m.email!)
                                    : null),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                onPressed: () =>
                                    _showMemberForm(context, member: m),
                                child: const Icon(
                                  CupertinoIcons.pencil,
                                  size: 18,
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                onPressed: () => _confirmDelete(context, m),
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  size: 18,
                                  color: CupertinoColors.destructiveRed,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProjectMember member,
  ) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('deleteMember'.tr()),
        content: Text(
          'deleteMemberConfirm'.tr(namedArgs: {'name': member.name}),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('cancel'.tr()),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('delete'.tr()),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ProjectProvider>().deleteMember(member.id, projectId);
    }
  }

  Future<void> _showMemberForm(
    BuildContext context, {
    ProjectMember? member,
  }) async {
    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final phoneCtrl = TextEditingController(text: member?.phone ?? '');
    final emailCtrl = TextEditingController(text: member?.email ?? '');
    var color = member?.color ?? AppColors.categoryPalette.first.toARGB32();

    await showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => CupertinoAlertDialog(
          title: Text(member == null ? 'addMember'.tr() : 'editMember'.tr()),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: nameCtrl,
                  placeholder: 'memberName'.tr(),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: phoneCtrl,
                  placeholder: 'memberPhone'.tr(),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: emailCtrl,
                  placeholder: 'memberEmail'.tr(),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColors.categoryPalette.map((c) {
                    final argb = c.toARGB32();
                    final selected = color == argb;
                    return GestureDetector(
                      onTap: () => setLocal(() => color = argb),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(
                                  color: CupertinoColors.white,
                                  width: 2,
                                )
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('cancel'.tr()),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              child: Text('save'.tr()),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final provider = context.read<ProjectProvider>();
                final next = ProjectMember(
                  id: member?.id ?? const Uuid().v4(),
                  projectId: projectId,
                  name: name,
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  color: color,
                );
                if (member == null) {
                  await provider.addMember(next);
                } else {
                  await provider.updateMember(next);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member});
  final ProjectMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(member.color).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Text(
        member.initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(member.color),
        ),
      ),
    );
  }
}
