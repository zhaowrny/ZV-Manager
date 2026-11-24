import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/update_service.dart';
import 'core/widgets/background_widget.dart';
import 'providers/wallpaper_provider.dart';
import 'core/widgets/user_agreement_dialog.dart';
import 'core/widgets/z_widgets.dart';
import 'features/shell/main_shell.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/download_provider.dart';
import 'providers/glass_provider.dart';
import 'providers/server_provider.dart';
import 'providers/rcon_provider.dart';
import 'core/services/server_monitor_service.dart';
import 'features/dashboard/server_picker_bar.dart';

/// 全局导航 Key
final navigatorKey = GlobalKey<NavigatorState>();

class ZVManagerApp extends StatefulWidget {
  /// 由 main() 传入已预加载的实例，避免在树里重建导致状态不同步。
  final WallpaperProvider wallpaperProvider;

  /// 启动数据是否已加载完成。未完成时不弹用户守则，
  /// 避免弹窗盖在一个还没数据的空列表上。
  final bool booted;

  const ZVManagerApp({
    super.key,
    required this.wallpaperProvider,
    this.booted = true,
  });

  @override
  State<ZVManagerApp> createState() => ZVManagerAppState();
}

class ZVManagerAppState extends State<ZVManagerApp> {
  bool _showAgreement = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _checkAgreement();
  }

  // 新增：检查是否已同意用户守则
  Future<void> _checkAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool('user_agreed') ?? false;
    setState(() {
      _showAgreement = !agreed;
      _isReady = true;
    });
    if (agreed) {
      _checkUpdateSilently();
    }
  }

  // 新增：同意后保存并进入
  Future<void> _onAgree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_agreed', true);
    setState(() {
      _showAgreement = false;
    });
    _checkUpdateSilently();
  }

  Future<void> _checkUpdateSilently() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final updateInfo =
          await UpdateService.fetchInfo(userAgent: packageInfo.version);
      if (!mounted || updateInfo == null) return;
      final navContext = navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      UpdateService.showUpdateDialog(
        navContext,
        updateInfo,
        packageInfo.version,
        silentOnNoUpdate: true,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // 注意：WallpaperProvider 只在 main() 里创建一次（.value 注入），
      // 不要在这里再 create 一个新的 —— 否则设置页与列表页会各持一份状态，
      // hasWallpaper 翻转不同步，切换壁纸时 AppBar 会跳一下色。
      providers: [
        // Theme/Server/Rcon 由 main.dart 的 Bootstrap 预加载后以 .value 注入，
        // 这里绝不能再 create 新实例 —— 否则会生成一个空的影子 Provider，
        // 导致更新后服务器列表"被清空"、添加时覆盖真实数据（v2.0 实测 bug）。
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        // 状态监控：复用 Bootstrap 里已预加载的 ServerProvider / RconProvider，
        // 在 create 里惰性启动，避免拖慢冷启动。
        ChangeNotifierProvider<ServerMonitorService>(
          create: (ctx) => ServerMonitorService(
            servers: ctx.read<ServerProvider>(),
            rcon: ctx.read<RconProvider>(),
          )..load(),
        ),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SelectedServerHolder()),
        // 液态玻璃：外观开关，持久化在本地
        ChangeNotifierProvider(create: (_) => GlassProvider()..load()),
        // 复用 main() 中预加载的实例，不能在这里 create 一个新的
        ChangeNotifierProvider<WallpaperProvider>.value(
          value: widget.wallpaperProvider,
        ),
      ],
      child: Consumer3<ThemeProvider, LanguageProvider, GlassProvider>(
        builder: (
          context,
          themeProvider,
          languageProvider,
          glassProvider,
          _,
        ) {
          // 全站强调色跟随当前主题配色（z_widgets 内组件共用同一个变量）
          kZAccent = themeProvider.themeColor.seed;
          // 液态玻璃开关同步给底层组件（ZPanel / ZAppBar 读这个全局）
          kZGlass = glassProvider.enabled;
          final lightTheme = AppTheme.lightThemeFor(themeProvider.themeColor);
          final darkTheme = AppTheme.darkThemeFor(themeProvider.themeColor);
          return MaterialApp(
            title: 'ZV Manager',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            // 玻璃模式下把所有页面底色让出来，否则不透明 Scaffold 会把
            // 后面的背景光/壁纸挡住，模糊也就无从谈起
            theme: kZGlass
                ? lightTheme.copyWith(
                    scaffoldBackgroundColor: Colors.transparent)
                : lightTheme,
            darkTheme: kZGlass
                ? darkTheme.copyWith(
                    scaffoldBackgroundColor: Colors.transparent)
                : darkTheme,
            themeMode: themeProvider.flutterThemeMode,
            locale: languageProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            home: const MainShell(),
            builder: (context, child) {
              child ??= const SizedBox.shrink();
              final hasWallpaper =
                  context.watch<WallpaperProvider>().hasWallpaper;
              return BackgroundWidget(
                key: backgroundWidgetKey,
                child: Stack(
                  children: [
                    // 液态玻璃 + 无壁纸时铺一层背景光：
                    // 没有它，BackdropFilter 磨的是一整块纯色，观感等于没开
                    if (kZGlass && !hasWallpaper)
                      const Positioned.fill(child: GlassBackdrop()),
                    child,
                    // 新增：用户守则弹窗
                    if (widget.booted && _isReady && _showAgreement)
                      Positioned.fill(
                        child: Container(
                          // withOpacity 在新版 Flutter 已废弃，统一用 withValues
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: UserAgreementDialog(onAgree: _onAgree),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 液态玻璃模式下的「背景光」。
///
/// 一层柔和的对角渐变 + 两团大半径色斑。它本身颜色很淡，作用只有一个：
/// 给面板背后的 BackdropFilter 提供「有内容可糊」的底子。
/// 纯色背景上的模糊是看不出来的 —— 这是把玻璃做实与否的分水岭。
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final seed = kZAccent;
    final top = Color.lerp(
      seed,
      dark ? Colors.black : Colors.white,
      dark ? 0.82 : 0.88,
    )!;
    final bottom = Color.lerp(
      seed,
      dark ? Colors.black : Colors.white,
      dark ? 0.94 : 0.97,
    )!;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bottom],
              ),
            ),
          ),
          Positioned(
            top: -140,
            left: -110,
            child: _blob(seed.withOpacity(dark ? 0.55 : 0.30), 340),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _blob(
              Color.lerp(seed, Colors.blue, 0.4)!
                  .withOpacity(dark ? 0.42 : 0.22),
              380,
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}
