import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/background_service.dart';
import '../../core/widgets/background_widget.dart';
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
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: T('选择图片'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.green),
              title: T('选择视频'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo();
              },
            ),
            if (_currentBgPath != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: T('清除背景', style: TextStyle(color: Colors.red)),
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
      builder: (_) => SimpleDialog(
        title: T('语言 / Language'),
        children: [
          for (final m in LanguageMode.values)
            RadioListTile<LanguageMode>(
              title: Text(_languageName(m)),
              value: m,
              groupValue: provider.mode,
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
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

    return Scaffold(
      appBar: AppBar(title: T('设置')),
      body: ListView(
        children: [
          // ---------- 外观主题 ----------
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: T('外观主题'),
            trailing: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (v) => themeProvider.setThemeMode(v.first),
              style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
          const Divider(),

          // ---------- 应用背景（新增） ----------
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: T('应用背景'),
            subtitle: Text(
              _currentBgPath == null 
                  ? '未设置' 
                  : S.f('已设置 {0}', [_currentBgType == 'video' ? S.t('视频') : S.t('图片')]),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showBackgroundPicker,
          ),
          // ---------- 视频声音开关 ----------
          if (_currentBgType == 'video') ...[
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: T('视频声音'),
              subtitle: T('开启后背景视频将播放声音'),
              value: _videoSoundEnabled,
              onChanged: (value) async {
                await BackgroundService.setVideoSound(value);
                setState(() => _videoSoundEnabled = value);
                // 立即应用到正在播放的背景视频，无需重建图层
                backgroundWidgetKey.currentState?.applyVideoSound(value);
              },
            ),
          ],
          const Divider(),

          // ---------- 语言 ----------
          ListTile(
            leading: const Icon(Icons.language),
            title: T('语言 / Language'),
            subtitle: Text(_languageName(context.watch<LanguageProvider>().mode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(),
          ),
          const Divider(),

          // ---------- 下载与镜像 ----------
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: T('下载与镜像设置'),
            subtitle: T('镜像线路、测速选线、同时下载任务数'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadSettingsPage()),
            ),
          ),
          const Divider(),

          // ---------- 服务器日志 ----------
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: T('服务器日志'),
            subtitle: T('通过 SSH 查看服务器 logs 目录日志输出'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerLogPage()),
            ),
          ),
          const Divider(),

          // ---------- 使用教程 ----------
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: T('使用教程'),
            subtitle: T('如何开启 RCON / SSH、模组管理、下载与终端'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
          const Divider(),

          // ---------- 用户须知 ----------
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: T('用户须知'),
            subtitle: T('查看用户守则全部条款'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => UserAgreementDialog.readView(),
            ),
          ),
          const Divider(),

          // ---------- 关于软件（检查更新 + 创造者 + 开源许可） ----------
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: T('关于软件'),
            subtitle: T('版本、检查更新、创造者与开源许可'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
    );
  }
}