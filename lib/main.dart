import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/widgets/background_widget.dart';
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
  final wallpaperProvider = WallpaperProvider();
  await wallpaperProvider.loadWallpaper();

  // 把预加载结果直接交给 BackgroundWidget，让首帧就带上壁纸。
  // 若交给组件自己异步读 SharedPreferences，会出现「无背景一帧」的启动闪屏。
  BackgroundWidget.spec.value = BackgroundSpec(
    type: wallpaperProvider.wallpaperType,
    path: wallpaperProvider.wallpaperPath,
  );

  // 之后所有壁纸变更都通过 spec 通知背景层，组件内部完成交叉淡入
  wallpaperProvider.addListener(() {
    BackgroundWidget.spec.value = BackgroundSpec(
      type: wallpaperProvider.wallpaperType,
      path: wallpaperProvider.wallpaperPath,
    );
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serverProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => RconProvider()),
        ChangeNotifierProvider.value(value: wallpaperProvider), // 新增
      ],
      child: ZVManagerApp(wallpaperProvider: wallpaperProvider),
    ),
  );
}
