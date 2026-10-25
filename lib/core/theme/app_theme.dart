import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, system }

class AppTheme {
  static const _primaryColor = Color(0xFF4CAF50);

  /// 全局圆角体系
  static const radiusS = 10.0; // chips / 小元素
  static const radiusM = 14.0; // 输入框 / 按钮
  static const radiusL = 18.0; // 卡片 / 弹窗

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF111318) : const Color(0xFFF7F8FA),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? const Color(0xFF111318) : const Color(0xFFF7F8FA),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isDark ? const Color(0xFF1B1E24) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
          side: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          minimumSize: const Size(0, 46),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
        backgroundColor: isDark ? const Color(0xFF1B1E24) : Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF16191F) : Colors.white,
        indicatorColor: scheme.primary.withOpacity(0.15),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.primary.withOpacity(0.15),
        linearMinHeight: 8,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
        side: BorderSide.none,
        backgroundColor: scheme.primary.withOpacity(0.08),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        elevation: 4,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      tabBarTheme: const TabBarTheme(dividerColor: Colors.transparent),
    );
  }

  static ThemeData get lightTheme => _base(Brightness.light);

  static ThemeData get darkTheme => _base(Brightness.dark);

  static ThemeMode toFlutterThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
