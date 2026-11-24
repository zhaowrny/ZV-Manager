import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 液态玻璃（Liquid Glass）外观开关。
///
/// 开启后全站分组面板、顶栏、底部导航切换为「背后内容模糊 + 高光描边」的
/// 玻璃质感；没有自定义壁纸时会自动铺一层柔和背景光，让模糊有东西可糊 ——
/// 否则 BackdropFilter 只会把纯色再糊成纯色，开关点了等于没点。
class GlassProvider extends ChangeNotifier {
  static const String _key = 'glass_enabled';

  bool _enabled = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_key) ?? false;
    } catch (e) {
      debugPrint('读取液态玻璃设置失败: $e');
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      debugPrint('保存液态玻璃设置失败: $e');
    }
  }
}
