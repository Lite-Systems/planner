import 'package:flutter/cupertino.dart';

import '../utils/app_tokens.dart';
import '../utils/app_colors.dart';

/// Grouped native rows with the same bordered surface as dashboard cards.
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.all(8),
    required this.children,
  });

  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry margin;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => CupertinoListSection.insetGrouped(
    header: header,
    footer: footer,
    margin: margin,
    backgroundColor: CupertinoColors.transparent,
    separatorColor: AppColors.separator(context),
    decoration: AppCard.container(context),
    children: [
      for (final child in children)
        SizedBox(width: double.infinity, child: child),
    ],
  );
}
