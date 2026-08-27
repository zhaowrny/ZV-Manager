import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/rcon_provider.dart';
import 'providers/server_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/wallpaper_provider.dart'; // 新增

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final serverProvider = ServerProvider();
  await serverProvider.loadServers();

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeMode();

  // 预加载壁纸设置
  final wallpaperProvider = WallpaperProvider(); //  新增
  await wallpaperProvider.loadWallpaper(); //  新增

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serverProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => RconProvider()),
        ChangeNotifierProvider.value(value: wallpaperProvider), // 新增
      ],
      child: const ZVManagerApp(), // 改成 ZVManagerApp
    ),
  );
}
