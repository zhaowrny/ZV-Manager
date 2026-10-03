import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/update_service.dart';
import 'core/widgets/background_widget.dart';
import 'core/widgets/user_agreement_dialog.dart';  //  新增
import 'features/server_list/server_list_page.dart';
import 'providers/theme_provider.dart';
import 'providers/server_provider.dart';

/// 全局导航 Key
final navigatorKey = GlobalKey<NavigatorState>();

class ZVManagerApp extends StatefulWidget {
  const ZVManagerApp({super.key});

  @override
  State<ZVManagerApp> createState() => ZVManagerAppState();
}

class ZVManagerAppState extends State<ZVManagerApp> {
  final GlobalKey<BackgroundWidgetState> _bgKey = GlobalKey();

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

  void refreshBackground() {
    _bgKey.currentState?.refreshBackground();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ServerProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'ZV Manager',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.flutterThemeMode,
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            home: const ServerListPage(),
            builder: (context, child) {
              return BackgroundWidget(
                key: _bgKey,
                child: Stack(
                  children: [
                    child!,
                    // 新增：用户守则弹窗
                    if (_isReady && _showAgreement)
                      Positioned.fill(
                        child: Container(
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