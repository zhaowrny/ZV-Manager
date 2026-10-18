import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/update_service.dart';
import '../../core/utils/background_service.dart';
import '../../core/widgets/background_widget.dart';
import '../../providers/theme_provider.dart';
import '../../providers/wallpaper_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _currentVersion = '';
  bool _checkingUpdate = false;
  String? _currentBgType;
  String? _currentBgPath;
  bool _videoSoundEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadCurrentBg();
    _loadVideoSound();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
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

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final updateInfo = await UpdateService.fetchInfo(userAgent: _currentVersion);
      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (updateInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取更新信息失败')),
        );
        return;
      }

      UpdateService.showUpdateDialog(context, updateInfo, _currentVersion);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$e')),
      );
    }
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
              title: const Text('选择图片'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.green),
              title: const Text('选择视频'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo();
              },
            ),
            if (_currentBgPath != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('清除背景', style: TextStyle(color: Colors.red)),
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

  Future<void> _pickVideo() async {
    final result = await FilePicker.pickFile(type: FileType.video);
    if (result == null) return;

    final filePath = result.path;
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
          const SnackBar(content: Text('壁纸设置保存失败，请重试')),
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
          const SnackBar(content: Text('保存失败，请重试')),
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
          content: Text(_currentBgPath == null ? '已清除背景' : '背景已更新 ✅'),
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
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ---------- 外观主题 ----------
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('外观主题'),
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
            title: const Text('应用背景'),
            subtitle: Text(
              _currentBgPath == null 
                  ? '未设置' 
                  : '已设置 ${_currentBgType == 'video' ? ' 视频' : ' 图片'}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showBackgroundPicker,
          ),
          // ---------- 视频声音开关 ----------
          if (_currentBgType == 'video') ...[
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: const Text('视频声音'),
              subtitle: const Text('开启后背景视频将播放声音'),
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

          // ---------- 检查更新 ----------
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('检查更新'),
            subtitle: Text('当前版本: $_currentVersion'),
            trailing: _checkingUpdate
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : _checkUpdate,
          ),
          const Divider(),

          // ---------- 关于 ----------
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('开发者：Z有3笔，协作者：venti1112'),
          ),
          const Divider(),

          // ---------- 开源许可 ----------
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('开源许可'),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }
}