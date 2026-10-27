import 'package:flutter/material.dart';
import '../core/utils/background_service.dart';

/// 自定义背景（壁纸）状态。
///
/// 壁纸由原生侧（MethodChannel）负责读写，这里只做内存缓存 + 通知刷新，
/// 避免每次 build 都跨平台调用。
class WallpaperProvider extends ChangeNotifier {
  String? _wallpaperPath;

  /// 壁纸类型：'image' / 'video'（视频壁纸由原生层渲染）
  String? _wallpaperType;

  String? get wallpaperPath => _wallpaperPath;
  String? get wallpaperType => _wallpaperType;

  WallpaperProvider();

  /// 启动时从原生侧读取已设置的壁纸。
  Future<void> loadWallpaper() async {
    final data = await BackgroundService.getBackground();
    _wallpaperType = data['type'];
    _wallpaperPath = data['path'];
    notifyListeners();
  }

  /// 设置自定义壁纸，同时写入原生侧持久存储。
  Future<void> setCustomWallpaper(String path, {String type = 'image'}) async {
    await BackgroundService.setBackground(type, path);
    _wallpaperType = type;
    _wallpaperPath = path;
    notifyListeners();
  }

  /// 恢复默认背景。
  Future<void> resetWallpaper() async {
    await BackgroundService.clearBackground();
    _wallpaperType = null;
    _wallpaperPath = null;
    notifyListeners();
  }

  /// 是否设置了自定义壁纸——页面据此决定要不要把 Scaffold 背景设为透明，
  /// 以便露出底层的壁纸图层。
  bool get hasWallpaper => _wallpaperPath != null;
}
