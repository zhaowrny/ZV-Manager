import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

/// 主题模式状态：亮色 / 暗色 / 跟随系统，选择结果持久化到本地。
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';

  AppThemeMode _themeMode = AppThemeMode.system;
  AppThemeMode get themeMode => _themeMode;

  /// 转成 MaterialApp 需要的 ThemeMode
  ThemeMode get flutterThemeMode => AppTheme.toFlutterThemeMode(_themeMode);

  /// 启动时读取上次保存的主题模式。
  /// 读不到或值非法（如版本升级后枚举重命名）时回退到「跟随系统」。
  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => AppThemeMode.system,
      );
      notifyListeners();
    }
  }

  /// 切换主题模式：先刷新 UI 再异步落盘，避免点击后有明显延迟感。
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    }
  }
}
