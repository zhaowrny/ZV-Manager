import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/background_service.dart';
import '../../core/utils/app_links.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/server_monitor_service.dart';
import '../../core/widgets/background_widget.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/glass_provider.dart';
import 'help_page.dart';
import 'server_log_page.dart';
import 'about_page.dart';
import '../../core/widgets/user_agreement_dialog.dart';
import 'download_settings_page.dart';
import '../../providers/language_provider.dart';
import '../../core/l10n/strings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _currentBgType;
  String? _currentBgPath;
  bool _videoSoundEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBg();
    _loadVideoSound();
  }

  Future<void> _loadCurrentBg() async {
    final data = await BackgroundService.getBackground();
    if (mounted) {
      setState(() {
        _currentBgType = data['type'];
        _currentBgPath = data['path'];
      });
    }
  }

  Future<void> _loadVideoSound() async {
    final enabled = await BackgroundService.getVideoSound();
    if (mounted) setState(() => _videoSoundEnabled = enabled);
  }

  // ==================== 背景相关方法 ====================

  void _showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final st = ZStyle.of(ctx, hasWallpaper: false);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ZPanel(
              style: st,
              children: [
                ZSheetRow(
                  icon: Icons.photo,
                  iconColor: Colors.blue,
                  title: '选择图片',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                ZDivider(style: st),
                ZSheetRow(
                  icon: Icons.videocam,
                  title: '选择视频',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
                if (_currentBgPath != null) ...[
                  ZDivider(style: st),
                  ZSheetRow(
                    icon: Icons.delete,
                    danger: true,
                    title: '清除背景',
                    onTap: () {
                      Navigator.pop(ctx);
                      _clearBackground();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result == null) return;

    final path = await _saveFileToAssets(result.path, 'image');
    if (path == null) return;

    if (!mounted) return;
    // 通过 Provider 落盘并通知，背景层随之交叉淡入
    if (await _applyWallpaper(path, 'image')) _refreshUI();
  }

  String _languageName(LanguageMode m) => switch (m) {
        LanguageMode.system => '跟随系统 / System',
        LanguageMode.zh => '简体中文',
        LanguageMode.en => 'English',
      };

  Future<void> _pickLanguage() async {
    final provider = context.read<LanguageProvider>();
    final mode = await showDialog<LanguageMode>(
      context: context,
      builder: (ctx) {
        final st = ZStyle.of(ctx, hasWallpaper: false);
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: T('语言 / Language', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                ZPanel(
                  style: st,
                  children: [
                    for (final m in LanguageMode.values) ...[
                      if (m != LanguageMode.values.first) ZDivider(style: st),
                      ZSheetRow(
                        icon: Icons.language,
                        title: _languageName(m),
                        trailing: ZCheck(
                          value: provider.mode == m,
                          size: 22,
                          borderColor: st.subColor,
                          onChanged: (_) => Navigator.pop(ctx, m),
                        ),
                        onTap: () => Navigator.pop(ctx, m),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mode != null) await provider.setMode(mode);
  }

  /// 主题配色选择：5 套种子色，选项以开关呈现。
  Future<void> _pickThemeColor() async {
    final provider = context.read<ThemeProvider>();
    final color = await showDialog<AppThemeColor>(
      context: context,
      builder: (ctx) {
        final st = ZStyle.of(ctx, hasWallpaper: false);
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: T('主题配色', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                ZPanel(
                  style: st,
                  children: [
                    for (final c in AppThemeColor.values) ...[
                      if (c != AppThemeColor.values.first) ZDivider(style: st),
                      ZSheetRow(
                        icon: Icons.palette_outlined,
                        iconColor: c.seed,
                        title: S.t(c.label),
                        trailing: ZCheck(
                          value: provider.themeColor == c,
                          size: 22,
                          borderColor: st.subColor,
                          onChanged: (_) => Navigator.pop(ctx, c),
                        ),
                        onTap: () => Navigator.pop(ctx, c),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (color != null) await provider.setThemeColor(color);
  }

  Future<void> _pickVideo() async {
    final picked = await FilePicker.pickFile(type: FileType.video);
    final filePath = picked?.path;
    if (filePath == null) return;

    final path = await _saveFileToAssets(filePath, 'video');
    if (path == null) return;

    if (!mounted) return;
    if (await _applyWallpaper(path, 'video')) _refreshUI();
  }

  /// 落盘壁纸设置。失败时给出可见提示，避免「点了没反应」式的静默失败
  /// （例如 release 包把插件方法混淆掉、SharedPreferences 整体不可用时）。
  Future<bool> _applyWallpaper(String path, String type) async {
    try {
      await context.read<WallpaperProvider>().setCustomWallpaper(path, type: type);
      return true;
    } catch (e) {
      debugPrint('保存壁纸设置失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: T('壁纸设置保存失败，请重试')),
        );
      }
      return false;
    }
  }

  Future<String?> _saveFileToAssets(String sourcePath, String type) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = sourcePath.split('.').last;
      final fileName = 'background_${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destPath = '${dir.path}/$fileName';

      final file = File(sourcePath);
      await file.copy(destPath);

      // 换壁纸时清掉上一份（图片与视频都清），否则应用目录会无限膨胀
      await _cleanupOldBackgrounds(dir.path, keep: destPath);

      return destPath;
    } catch (e) {
      debugPrint('保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: T('保存失败，请重试')),
        );
      }
      return null;
    }
  }

  /// 删除应用目录下除 [keep] 之外的旧壁纸文件。
  Future<void> _cleanupOldBackgrounds(String dirPath, {required String keep}) async {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!name.startsWith('background_')) continue;
        if (entity.path == keep) continue;
        await entity.delete();
      }
    } catch (_) {
      // 清理失败不影响主流程
    }
  }

  Future<void> _clearBackground() async {
    await context.read<WallpaperProvider>().resetWallpaper();
    _refreshUI();
  }

  void _refreshUI() {
    _loadCurrentBg();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentBgPath == null ? S.t('已清除背景') : S.t('背景已更新')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ==================== 状态监控 ====================

  /// 开启监控前先要通知权限：Android 13+ 没权限时通知会被系统直接丢掉，
  /// 用户只会觉得「开了但没反应」，所以这里先要权限、拿不到就明说。
  Future<void> _toggleMonitor(bool value) async {
    final monitor = context.read<ServerMonitorService>();
    if (value) {
      final granted = await NotificationService.instance.ensurePermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: T('未获得通知权限，提醒可能无法显示，请到系统设置中允许通知')),
        );
      }
    }
    await monitor.setEnabled(value);
  }

  /// 轮询间隔选择：30 秒 / 1 分钟 / 2 分钟 / 5 分钟。
  Future<void> _pickMonitorInterval() async {
    final monitor = context.read<ServerMonitorService>();
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final st = ZStyle.of(ctx, hasWallpaper: false);
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: T('检查间隔', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                ZPanel(
                  style: st,
                  children: [
                    for (final seconds
                        in ServerMonitorService.intervalOptions) ...[
                      if (seconds !=
                          ServerMonitorService.intervalOptions.first)
                        ZDivider(style: st),
                      ZSheetRow(
                        icon: Icons.schedule,
                        title: ServerMonitorService.labelForInterval(seconds),
                        trailing: ZCheck(
                          value: monitor.intervalSec == seconds,
                          size: 22,
                          borderColor: st.subColor,
                          onChanged: (_) => Navigator.pop(ctx, seconds),
                        ),
                        onTap: () => Navigator.pop(ctx, seconds),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) await monitor.setInterval(selected);
  }

  /// 手动跑一轮检查，验证 RCON 配置是否正确。
  Future<void> _runMonitorCheck() async {
    final monitor = context.read<ServerMonitorService>();
    await monitor.checkNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          S.f('检查完成：{0} 台服务器在线', <Object>[monitor.onlineCount]),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 最近检查时间的展示文案。
  String _lastCheckText(DateTime? at) {
    if (at == null) return S.t('尚未检查');
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return S.f('{0}:{1}', <Object>[hh, mm]);
  }

  // ==================== build ====================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final monitor = context.watch<ServerMonitorService>();
    final glass = context.watch<GlassProvider>();
    final scheme = Theme.of(context).colorScheme;
    final st = ZStyle(hasWallpaper: hasWallpaper, scheme: scheme);
    final systemIsDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      // 透明 AppBar，让壁纸延伸到顶
      appBar: ZAppBar(
        title: T('设置'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ZPanel(style: st, children: [
            // ---------- 外观：双开关 + 配色 ----------
            ZRow(
              title: '深色模式',
              subtitle: themeProvider.followSystem
                  ? '跟随系统开启时由系统决定，关闭后可手动切换'
                  : '开启后使用暗色界面',
              style: st,
              trailing: ZCheck(
                value: themeProvider.darkMode(systemIsDark: systemIsDark),
                enabled: !themeProvider.followSystem,
                size: 26,
                borderColor: st.subColor,
                onChanged: (v) => themeProvider.setDarkMode(v),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '跟随系统',
              subtitle: '随系统的深色 / 浅色设置自动切换',
              style: st,
              trailing: ZCheck(
                value: themeProvider.followSystem,
                size: 26,
                borderColor: st.subColor,
                onChanged: (v) =>
                    themeProvider.setFollowSystem(v, systemIsDark: systemIsDark),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '主题配色',
              subtitle: '切换全站强调色与界面色调',
              style: st,
              value: S.t(themeProvider.themeColor.label),
              onTap: _pickThemeColor,
            ),
            ZDivider(style: st),
            ZRow(
              title: '液态玻璃',
              subtitle: glass.enabled
                  ? '已开启：面板、顶栏、底栏均为毛玻璃质感'
                  : '半透明毛玻璃面板 + 高光描边，开启后全站生效',
              style: st,
              trailing: ZCheck(
                value: glass.enabled,
                size: 26,
                borderColor: st.subColor,
                onChanged: (v) => context.read<GlassProvider>().setEnabled(v),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '应用背景',
              subtitle: '选择一张图片或一段视频作为应用背景',
              style: st,
              value: _currentBgPath == null
                  ? S.t('未设置')
                  : S.f('{0}',
                      [_currentBgType == 'video' ? S.t('视频') : S.t('图片')]),
              onTap: _showBackgroundPicker,
            ),
            if (_currentBgType == 'video') ...[
              ZDivider(style: st),
              ZRow(
                title: '视频声音',
                subtitle: '开启后背景视频将播放声音',
                style: st,
                trailing: ZCheck(
                  value: _videoSoundEnabled,
                  size: 26,
                  borderColor: st.subColor,
                  onChanged: (value) async {
                    await BackgroundService.setVideoSound(value);
                    setState(() => _videoSoundEnabled = value);
                    // 立即应用到正在播放的背景视频，无需重建图层
                    backgroundWidgetKey.currentState?.applyVideoSound(value);
                  },
                ),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          ZPanel(style: st, children: [
            // ---------- 语言 ----------
            ZRow(
              title: '语言 / Language',
              subtitle: '界面显示语言',
              style: st,
              value: _languageName(context.watch<LanguageProvider>().mode),
              onTap: _pickLanguage,
            ),
            ZDivider(style: st),
            ZRow(
              title: '下载与镜像设置',
              subtitle: '镜像线路、测速选线、同时下载任务数',
              style: st,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadSettingsPage()),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '服务器日志',
              subtitle: '通过 SSH 查看服务器 logs 目录日志输出',
              style: st,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServerLogPage()),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ZPanel(style: st, children: [
            // ---------- 状态监控与通知 ----------
            ZRow(
              title: '状态监控',
              subtitle: monitor.enabled
                  ? S.f('每 {0}检查一次 · 最近 {1}', <Object>[
                      monitor.intervalLabel,
                      _lastCheckText(monitor.lastCheckAt),
                    ])
                  : '开启后定时检查服务器状态，并在变化时推送通知',
              style: st,
              trailing: ZCheck(
                value: monitor.enabled,
                size: 26,
                borderColor: st.subColor,
                onChanged: _toggleMonitor,
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '服务器离线提醒',
              subtitle: '服务器掉线时推送系统通知',
              style: st,
              trailing: ZCheck(
                value: monitor.notifyOffline,
                enabled: monitor.enabled,
                size: 26,
                borderColor: st.subColor,
                onChanged: monitor.setNotifyOffline,
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '服务器恢复提醒',
              subtitle: '服务器重新上线时推送通知',
              style: st,
              trailing: ZCheck(
                value: monitor.notifyRecovered,
                enabled: monitor.enabled,
                size: 26,
                borderColor: st.subColor,
                onChanged: monitor.setNotifyRecovered,
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '玩家上线提醒',
              subtitle: '有新玩家进入服务器时推送通知',
              style: st,
              trailing: ZCheck(
                value: monitor.notifyJoin,
                enabled: monitor.enabled,
                size: 26,
                borderColor: st.subColor,
                onChanged: monitor.setNotifyJoin,
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '检查间隔',
              subtitle: '间隔越短发现越快，对服务器的轮询压力也越大',
              style: st,
              value: monitor.intervalLabel,
              onTap: monitor.enabled ? _pickMonitorInterval : null,
            ),
            ZDivider(style: st),
            ZRow(
              title: monitor.isChecking ? '正在检查…' : '立即检查一次',
              subtitle: '手动跑一轮检查，用来确认 RCON 配置是否可用',
              style: st,
              onTap: monitor.isChecking ? null : _runMonitorCheck,
            ),
          ]),
          const SizedBox(height: 14),
          ZPanel(style: st, children: [
            ZRow(
              title: '使用教程',
              subtitle: '如何开启 RCON / SSH、模组管理、下载与终端',
              style: st,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '用户须知',
              subtitle: '查看用户守则全部条款',
              style: st,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => UserAgreementDialog.readView(),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '关于软件',
              subtitle: '版本、检查更新、创造者与开源许可',
              style: st,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              ),
            ),
            ZDivider(style: st),
            ZRow(
              title: '支持作者 · 爱发电',
              subtitle: '通过爱发电支持项目开发',
              style: st,
              onTap: () => openAfdian(context),
            ),
            ZDivider(style: st),
            ZRow(
              title: '加入官方 QQ 群',
              subtitle: '与开发者和其他用户交流',
              style: st,
              onTap: () => joinQQGroup(context),
            ),
          ]),
        ],
      ),
    );
  }
}
