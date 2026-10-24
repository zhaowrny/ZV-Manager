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
import 'core/widgets/user_agreement_dialog.dart';  //  新增
import 'features/shell/main_shell.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/download_provider.dart';
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
      final updateInfo = await UpdateService.fetchInfo(userAgent: packageInfo.version);
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
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SelectedServerHolder()),
        // 复用 main() 中预加载的实例，不能在这里 create 一个新的
        ChangeNotifierProvider<WallpaperProvider>.value(
          value: widget.wallpaperProvider,
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            title: 'ZV Manager',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
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
              return BackgroundWidget(
                key: backgroundWidgetKey,
                child: Stack(
                  children: [
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