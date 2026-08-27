import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/wallpaper_provider.dart';
import '../../app.dart';

class WallpaperSettings extends StatelessWidget {
  const WallpaperSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WallpaperProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('壁纸设置'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 预览区域
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[200],
              image: provider.wallpaperPath != null
                  ? DecorationImage(
                      image: FileImage(File(provider.wallpaperPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: provider.wallpaperPath == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wallpaper, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('当前为默认壁纸', style: TextStyle(color: Colors.grey)),
                        Text('点击下方「选择图片」自定义', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('自定义壁纸已应用', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // 选择图片
          const Text('选择壁纸', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('从相册选择图片作为应用背景', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final picker = ImagePicker();
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null && context.mounted) {
                final savedPath = await _saveFileToAssets(context, image.path);
                if (savedPath != null && context.mounted) {
                  await provider.setCustomWallpaper(savedPath);
                  if (context.mounted) {
                    _refreshBackground(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('壁纸已更新'), backgroundColor: Colors.green),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('选择图片'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // 重置
          const Text('重置壁纸', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('恢复默认壁纸', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _showResetDialog(context, provider);
            },
            icon: const Icon(Icons.restore),
            label: const Text('恢复默认'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _saveFileToAssets(BuildContext context, String sourcePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = sourcePath.split('.').last;
      final fileName = 'background_image_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destPath = '${dir.path}/$fileName';

      final file = File(sourcePath);
      await file.copy(destPath);

      return destPath;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
      return null;
    }
  }

  void _refreshBackground(BuildContext context) {
    final appState = context.findAncestorStateOfType<ZVManagerAppState>();
    appState?.refreshBackground();
  }

  void _showResetDialog(BuildContext context, WallpaperProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('确定要恢复默认壁纸吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await provider.resetWallpaper();
              if (context.mounted) {
                _refreshBackground(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复默认壁纸'), backgroundColor: Colors.green),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}
