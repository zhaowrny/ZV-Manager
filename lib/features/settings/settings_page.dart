import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/background_service.dart';
import '../../core/widgets/background_widget.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wallpaper_provider.dart';
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
                        trailing: provider.mode == m
                            ? Icon(Icons.check_circle_rounded, color: kZAccent, size: 22)
                            : Icon(Icons.circle_outlined, color: st.subColor, size: 22),
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

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null) return;

    final filePath = result.files.single.path;
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

  // ==================== build ====================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final scheme = Theme.of(context).colorScheme;
    final st = ZStyle(hasWallpaper: hasWallpaper, scheme: scheme);

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
            // ---------- 外观主题 ----------
            ZRow(
              title: '外观主题',
              subtitle: '亮色、暗色或跟随系统',
              style: st,
              trailing: ZSegmentedCircles<AppThemeMode>(
                value: themeProvider.themeMode,
                onChanged: (m) => themeProvider.setThemeMode(m),
                onSurface: st.titleColor,
                options: const [
                  ZCircleOption(value: AppThemeMode.light, icon: Icons.light_mode),
                  ZCircleOption(value: AppThemeMode.dark, icon: Icons.dark_mode),
                  ZCircleOption(
                      value: AppThemeMode.system, icon: Icons.brightness_auto),
                ],
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
                trailing: ZToggle(
                  value: _videoSoundEnabled,
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
          ]),
        ],
      ),
    );
  }
}
