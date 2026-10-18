import 'package:flutter/cupertino.dart';

import '../utils/app_colors.dart';

/// Opaque, lightweight page toolbar shared by module pages and editors.
class AppNavigationBar extends CupertinoNavigationBar {
  const AppNavigationBar({
    super.key,
    super.leading,
    super.middle,
    super.trailing,
    super.automaticallyImplyLeading,
    super.previousPageTitle,
  }) : super(
         backgroundColor: AppColors.background,
         border: const Border(bottom: BorderSide(color: AppColors.outline)),
         automaticBackgroundVisibility: false,
         enableBackgroundFilterBlur: false,
         transitionBetweenRoutes: false,
       );
}
