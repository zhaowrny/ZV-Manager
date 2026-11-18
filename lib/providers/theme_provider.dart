import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

/// 主题状态：亮/暗/跟随系统 + 配色，选择结果持久化到本地。
///
/// 设置页用两个开关表达明暗：
/// - 跟随系统 = 开 → AppThemeMode.system（深色模式开关置灰，显示系统当前亮度）
/// - 跟随系统 = 关 → 深色模式 ? dark : light
class ThemeProvider extends ChangeNotifier {
  static const _keyMode = 'app_theme_mode';
  static const _keyColor = 'app_theme_color';

  AppThemeMode _themeMode = AppThemeMode.system;
  AppThemeColor _themeColor = AppThemeColor.zl2Green;

  AppThemeMode get themeMode => _themeMode;
  AppThemeColor get themeColor => _themeColor;

  /// 转成 MaterialApp 需要的 ThemeMode
  ThemeMode get flutterThemeMode => AppTheme.toFlutterThemeMode(_themeMode);

  /// 开关 1：是否跟随系统
  bool get followSystem => _themeMode == AppThemeMode.system;

  /// 开关 2：深色模式。跟随系统时反映系统亮度（由 UI 传入 [systemIsDark]）。
  bool darkMode({bool systemIsDark = false}) =>
      followSystem ? systemIsDark : _themeMode == AppThemeMode.dark;

  /// 启动时读取上次保存的明暗与配色；读不到或值非法时回退默认值。
  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = AppThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_keyMode),
      orElse: () => AppThemeMode.system,
    );
    _themeColor = AppThemeColor.values.firstWhere(
      (c) => c.name == prefs.getString(_keyColor),
      orElse: () => AppThemeColor.zl2Green,
    );
    notifyListeners();
  }

  /// 切换明暗：先刷新 UI 再异步落盘，避免点击后有明显延迟感。
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
  }

  /// 切换主题配色。
  Future<void> setThemeColor(AppThemeColor color) async {
    if (_themeColor == color) return;
    _themeColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyColor, color.name);
  }

  /// 开关 1：跟随系统。关闭时沿用当前显示的明暗，避免开关跳变。
  Future<void> setFollowSystem(bool value, {bool systemIsDark = false}) =>
      setThemeMode(value
          ? AppThemeMode.system
          : (darkMode(systemIsDark: systemIsDark)
              ? AppThemeMode.dark
              : AppThemeMode.light));

  /// 开关 2：深色模式。在跟随系统下操作会自动切回手动模式。
  Future<void> setDarkMode(bool value) =>
      setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
}
