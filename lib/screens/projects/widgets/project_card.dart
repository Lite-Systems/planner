import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_tokens.dart';
import 'package:planner/core/utils/icon_utils.dart';
import 'package:planner/models/project.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const ProjectCard({super.key, required this.project, required this.onTap});

  static const _coverSize = 80.0;
  static const _coverRadius = BorderRadius.only(
    topLeft: Radius.circular(12),
    bottomLeft: Radius.circular(12),
  );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: AppCard.container(context, radius: AppRadius.md),
          child: Row(
            children: [
              _cover(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: CupertinoTheme.of(context).textTheme.textStyle
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                      ),
                      if (project.customer != null &&
                          project.customer!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            project.customer!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (project.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            project.description,
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context) {
    if (project.usesIconCover) {
      return Container(
        width: _coverSize,
        height: _coverSize,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: _coverRadius,
        ),
        child: Center(
          child: FaIcon(
            IconUtils.getIconData(project.icon ?? 0xe19f),
            color: CupertinoColors.white,
            size: 28,
          ),
        ),
      );
    }

    if (project.imagePath != null) {
      final px = (_coverSize * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: _coverRadius,
        child: Image.file(
          File(project.imagePath!),
          width: _coverSize,
          height: _coverSize,
          cacheWidth: px,
          cacheHeight: px,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => _placeholder(),
        ),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: _coverSize,
      height: _coverSize,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: _coverRadius,
      ),
      child: const Center(
        child: FaIcon(
          FontAwesomeIcons.briefcase,
          size: 30,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }
}
