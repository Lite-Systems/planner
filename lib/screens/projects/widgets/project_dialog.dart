import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/file_persist.dart';
import 'package:planner/core/utils/icon_utils.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import '../../../models/project.dart';
import '../../../providers/project_provider.dart';

const _projectIcons = [
  0xe19f, // briefcase
  0xe30a, // laptop
  0xe8d0, // store
  0xe1b1, // house
  0xeacc, // building
  0xe8cc, // cart
  0xe406, // graduation
  0xeb3f, // plane
  0xe0b0, // phone
  0xe54c, // film
  0xe838, // star
  0xe8f6, // gift
  0xe84f, // dollar
  0xe8f0, // wallet
];

class ProjectDialog {
  static void show(BuildContext context, {Project? project}) {
    final nameController = TextEditingController(text: project?.name ?? '');
    final descriptionController = TextEditingController(
      text: project?.description ?? '',
    );
    final customerController = TextEditingController(
      text: project?.customer ?? '',
    );
    DateTime? endDate = project?.endDate;
    String? imagePath = project?.imagePath;
    var coverType = project?.coverType ?? Project.coverImage;
    var icon = project?.icon ?? _projectIcons.first;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            project == null ? 'addProject'.tr() : 'editProject'.tr(),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text('cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text('save'.tr()),
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              var persistedImage = imagePath;
              if (persistedImage != null &&
                  persistedImage != project?.imagePath) {
                persistedImage = await FilePersist.copyToDocuments(
                  persistedImage,
                );
              }

              final customer = customerController.text.trim();
              final newProject = Project(
                id: project?.id ?? const Uuid().v4(),
                name: nameController.text,
                description: descriptionController.text,
                endDate: endDate,
                status: project?.status ?? 'active',
                imagePath: persistedImage,
                customer: customer.isEmpty ? null : customer,
                coverType: coverType,
                icon: icon,
              );

              if (!context.mounted) return;
              final provider = Provider.of<ProjectProvider>(
                context,
                listen: false,
              );
              if (project == null) {
                await provider.addProject(newProject);
              } else {
                await provider.updateProject(newProject);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: coverType,
                  children: {
                    Project.coverImage: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('coverImage'.tr()),
                    ),
                    Project.coverIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('coverIcon'.tr()),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() => coverType = value);
                  },
                ),
                const SizedBox(height: 16),
                if (coverType == Project.coverImage)
                  _ImagePickerBox(
                    imagePath: imagePath,
                    onPick: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                        // Downscale/compress on pick so covers don't ship
                        // multi-megapixel originals into the documents dir.
                        maxWidth: 1600,
                        maxHeight: 1600,
                        imageQuality: 85,
                      );
                      if (pickedFile != null) {
                        setState(() => imagePath = pickedFile.path);
                      }
                    },
                  )
                else
                  _IconPicker(
                    selectedIcon: icon,
                    onSelected: (code) => setState(() => icon = code),
                  ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'projectName'.tr(),
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: customerController,
                  placeholder: 'projectCustomer'.tr(),
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: descriptionController,
                  placeholder: 'description'.tr(),
                  padding: const EdgeInsets.all(12),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePickerBox extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;

  const _ImagePickerBox({required this.imagePath, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CupertinoColors.systemGrey4),
        ),
        child: imagePath != null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  final cacheWidth = constraints.maxWidth.isFinite
                      ? (constraints.maxWidth * dpr).round()
                      : null;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                    ),
                  );
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.image,
                    size: 50,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'tapToAddImage'.tr(),
                    style: const TextStyle(color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  final int selectedIcon;
  final ValueChanged<int> onSelected;

  const _IconPicker({required this.selectedIcon, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: FaIcon(
              IconUtils.getIconData(selectedIcon),
              color: CupertinoColors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _projectIcons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final iconCode = _projectIcons[index];
              final selected = iconCode == selectedIcon;
              return GestureDetector(
                onTap: () => onSelected(iconCode),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : CupertinoColors.systemGrey5,
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    IconUtils.getIconData(iconCode),
                    color: selected
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
