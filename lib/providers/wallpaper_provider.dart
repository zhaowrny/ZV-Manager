import 'package:flutter/material.dart';
import '../core/utils/background_service.dart';

class WallpaperProvider extends ChangeNotifier {
  String? _wallpaperPath;
  String? _wallpaperType;

  String? get wallpaperPath => _wallpaperPath;
  String? get wallpaperType => _wallpaperType;

  WallpaperProvider();

  Future<void> loadWallpaper() async {
    final data = await BackgroundService.getBackground();
    _wallpaperType = data['type'];
    _wallpaperPath = data['path'];
    notifyListeners();
  }

  Future<void> setCustomWallpaper(String path, {String type = 'image'}) async {
    await BackgroundService.setBackground(type, path);
    _wallpaperType = type;
    _wallpaperPath = path;
    notifyListeners();
  }

  Future<void> resetWallpaper() async {
    await BackgroundService.clearBackground();
    _wallpaperType = null;
    _wallpaperPath = null;
    notifyListeners();
  }

  bool get hasWallpaper => _wallpaperPath != null;
}
