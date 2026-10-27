import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, system }

/// Material 3 主题（参考 ZalithLauncher 的 M3 实现风格）：
/// - 用种子色生成完整 tonal palette，强调 colorScheme 的 surface container 层级
/// - 形状体系改用 M3 标准圆角（8 / 12 / 16 / 28），容器类用 16-28 的大圆角
/// - 卡片/列表靠 surfaceContainer 区分层次，弱化描边、不用阴影
class AppTheme {
  static const _primaryColor = Color(0xFF4CAF50);

  /// 形状体系（对齐 M3 shape scale）
  static const radiusXS = 8.0; // 小控件 / chip
  static const radiusS = 12.0; // 输入框 / 按钮
  static const radiusM = 16.0; // 卡片 / 列表容器
  static const radiusL = 28.0; // 弹窗 / 底部面板 / FAB

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: brightness,
      // 让主色更饱和、更接近 ZL2 那种"绿色主色调穿透整个界面"的效果
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      surface: isDark ? const Color(0xFF101410) : const Color(0xFFF7FAF5),
      surfaceContainerLowest: isDark ? const Color(0xFF0B0E0B) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF161A16) : const Color(0xFFF1F5EE),
      surfaceContainer: isDark ? const Color(0xFF1B201B) : const Color(0xFFEBF0E8),
      surfaceContainerHigh: isDark ? const Color(0xFF232823) : const Color(0xFFE3E9E0),
      surfaceContainerHighest: isDark ? const Color(0xFF2C322C) : const Color(0xFFDCE3D9),
    );

    final cardColor = isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest;
    final outline = isDark ? const Color(0xFF2E352E) : const Color(0xFFDDE4DA);

    final shapeXS = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXS));
    final shapeS = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS));
    final shapeM = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM));
    final shapeL = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // M3 强调排版层级：标题加粗收紧字距，正文行高放宽
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          )
          .copyWith(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: scheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: scheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
          side: BorderSide(color: outline, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shapeS,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shapeS,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shapeXS),
      ),
      // M3 的 FAB 是大圆角容器（16），extended 用 16 胶囊
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        elevation: 1,
        highlightElevation: 1,
      ),
      dialogTheme: DialogThemeData(
        shape: shapeL,
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shapeXS,
        insetPadding: const EdgeInsets.all(16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 6,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      chipTheme: ChipThemeData(
        shape: shapeXS,
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        labelStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: scheme.outlineVariant,
      ),
      listTileTheme: ListTileThemeData(
        shape: shapeM,
        iconColor: scheme.onSurfaceVariant,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: shapeM,
        elevation: 2,
        color: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: shapeM,
        collapsedShape: shapeM,
        iconColor: scheme.onSurfaceVariant,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: scheme.primary),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusS)),
            ),
          ),
          side: WidgetStateProperty.all(BorderSide(color: outline)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
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
