import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/widgets/background_widget.dart';
import 'providers/rcon_provider.dart';
import 'providers/server_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/wallpaper_provider.dart';

void main() {
  // 只做最少的事：绑定引擎 -> 立刻 runApp。
  //
  // 原实现是 `main() async` 里串行 await 三个 Provider 的加载，
  // 只要其中任何一个卡住（安全存储首次初始化、SharedPreferences 读盘），
  // runApp 就永远不会执行 —— 用户看到的就是一直白屏。
  // 现在把所有 I/O 挪进 App 内部的启动流程，并带超时保护。
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

/// 启动壳。
///
/// 职责：并行加载各 Provider，最多等待 [bootTimeout]；无论成功失败，
/// 都会进入主界面，绝不让用户卡在启动画面上。
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  static const Duration bootTimeout = Duration(seconds: 6);

  final ServerProvider _server = ServerProvider();
  final ThemeProvider _theme = ThemeProvider();
  final RconProvider _rcon = RconProvider();
  final WallpaperProvider _wallpaper = WallpaperProvider();

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final tasks = <Future<void>>[
      _guard('服务器列表', _server.loadServers()),
      _guard('主题', _theme.loadThemeMode()),
      _guard('壁纸', _wallpaper.loadWallpaper()),
    ];

    try {
      // 超时兜底：即使某个插件在低端机上迟迟不返回，也不阻断启动
      await Future.wait(tasks).timeout(bootTimeout);
    } catch (e) {
      debugPrint('启动初始化超时或异常，继续进入主界面: $e');
    }

    // 把预加载结果交给背景层，让首帧就带壁纸
    _syncWallpaperSpec();
    _wallpaper.addListener(_syncWallpaperSpec);

    if (!mounted) return;
    setState(() => _ready = true);
  }

  /// 单个加载任务失败不应拖垮整体启动。
  Future<void> _guard(String name, Future<void> future) async {
    try {
      await future;
    } catch (e) {
      debugPrint('加载$name失败: $e');
    }
  }

  void _syncWallpaperSpec() {
    try {
      BackgroundWidget.spec.value = BackgroundSpec(
        type: _wallpaper.wallpaperType,
        path: _wallpaper.wallpaperPath,
      );
    } catch (e) {
      debugPrint('同步壁纸配置失败: $e');
    }
  }

  @override
  void dispose() {
    _wallpaper.removeListener(_syncWallpaperSpec);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _server),
        ChangeNotifierProvider.value(value: _theme),
        ChangeNotifierProvider.value(value: _rcon),
        ChangeNotifierProvider.value(value: _wallpaper),
      ],
      // 加载期间也照常构建主界面：Provider 已有默认值，
      // 数据到位后自动刷新，用户不会看到空白屏。
      child: ZVManagerApp(wallpaperProvider: _wallpaper, booted: _ready),
    );
  }
}
