import 'package:shared_preferences/shared_preferences.dart';

class BackgroundService {
  static const String _keyType = 'background_type'; // 'image' 或 'video'
  static const String _keyPath = 'background_path';
  static const String _keyVideoSound = 'background_video_sound';

  // 保存背景（图片或视频）
  static Future<void> setBackground(String type, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyType, type);
    await prefs.setString(_keyPath, path);
  }

  // 获取背景
  static Future<Map<String, String?>> getBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString(_keyType);
    final path = prefs.getString(_keyPath);
    return {'type': type, 'path': path};
  }

  // 清除背景
  static Future<void> clearBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyType);
    await prefs.remove(_keyPath);
  }

  // 视频声音开关
  static Future<bool> getVideoSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVideoSound) ?? false;
  }

  static Future<void> setVideoSound(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVideoSound, enabled);
  }
}