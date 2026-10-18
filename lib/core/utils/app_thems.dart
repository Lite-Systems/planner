import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Base font family used across the app.
const _fontFamily = AppText.family;

/// Creates a TextStyle with `inherit: false` (required by CupertinoTextThemeData)
/// so Flutter can interpolate between light/dark theme styles without crashing.
TextStyle _t({
  required Color color,
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w400,
}) => TextStyle(
  fontFamily: _fontFamily,
  inherit: false,
  color: color,
  fontSize: fontSize,
  fontWeight: fontWeight,
  decoration: TextDecoration.none,
  textBaseline: TextBaseline.alphabetic,
);

class AppThems {
  static CupertinoThemeData lightTheme() {
    return CupertinoThemeData(
      textTheme: CupertinoTextThemeData(
        textStyle: _t(color: const Color(0xFF111827)),
        dateTimePickerTextStyle: _t(
          color: const Color(0xFF111827),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        pickerTextStyle: _t(
          color: const Color(0xFF111827),
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
        navTitleTextStyle: _t(
          color: const Color(0xFF111827),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        navActionTextStyle: _t(
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        actionTextStyle: _t(
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        tabLabelTextStyle: _t(color: const Color(0xFF6B7280), fontSize: 10),
      ),
      primaryColor: AppColors.primaryColor,
      primaryContrastingColor: Colors.white,
      barBackgroundColor: AppColors.surfaceAlt,
      scaffoldBackgroundColor: AppColors.surfaceAlt,
      brightness: Brightness.light,
      applyThemeToAll: true,
    );
  }

  static CupertinoThemeData darkTheme() {
    return CupertinoThemeData(
      textTheme: CupertinoTextThemeData(
        textStyle: _t(color: const Color(0xFFF5F5F7)),
        dateTimePickerTextStyle: _t(
          color: const Color(0xFFF5F5F7),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        pickerTextStyle: _t(
          color: const Color(0xFFF5F5F7),
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
        navTitleTextStyle: _t(
          color: const Color(0xFFF5F5F7),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        navActionTextStyle: _t(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        actionTextStyle: _t(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        tabLabelTextStyle: _t(color: const Color(0xFF8E8E93), fontSize: 10),
      ),
      primaryColor: AppColors.primaryColor,
      primaryContrastingColor: Colors.white,
      barBackgroundColor: AppColors.surfaceDark,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      brightness: Brightness.dark,
      applyThemeToAll: true,
    );
  }
}
