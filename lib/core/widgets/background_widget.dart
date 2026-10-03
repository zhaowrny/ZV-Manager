import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/background_service.dart';

class BackgroundWidget extends StatefulWidget {
  final Widget child;

  const BackgroundWidget({super.key, required this.child});

  @override
  State<BackgroundWidget> createState() => BackgroundWidgetState();
}

class BackgroundWidgetState extends State<BackgroundWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  FileImage? _cachedImage;
  String? _currentType;
  String? _currentPath;
  bool _isLoading = true;
  bool _isInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBackground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台时暂停视频，省电 + 减少卡顿
    if (state == AppLifecycleState.paused) {
      _isInForeground = false;
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.play();
      }
    }
  }

  Future<void> _loadBackground() async {
    final data = await BackgroundService.getBackground();
    final type = data['type'];
    final path = data['path'];

    // 路径没变，不重新加载
    if (_currentType == type && _currentPath == path && _controller != null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 释放旧视频
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    _currentType = type;
    _currentPath = path;
    _cachedImage = null;

    // ===== 视频背景 =====
    if (type == 'video' && path != null) {
      try {
        final file = File(path);
        if (!file.existsSync()) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        final videoSound = await BackgroundService.getVideoSound();
        final controller = VideoPlayerController.file(file);

        // 超时保护，避免卡住
        await controller.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('视频初始化超时');
          },
        );

        controller.setLooping(true);
        controller.setVolume(videoSound ? 1.0 : 0.0);
        if (_isInForeground) controller.play();

        if (mounted) {
          setState(() {
            _controller = controller;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('视频加载失败: $e');
      }
    }

    // ===== 图片背景 =====
    if (type == 'image' && path != null) {
      final file = File(path);
      if (file.existsSync()) {
        _cachedImage = FileImage(file);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// 供外部调用刷新壁纸
  void refreshBackground() {
    _loadBackground();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 还在加载，直接显示子组件
    if (_isLoading) return widget.child;

    // ===== 视频背景 =====
    if (_controller != null && _controller!.value.isInitialized) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            Container(color: Colors.black.withOpacity(0.3)),
            _wrapWithTransparentTheme(widget.child),
          ],
        ),
      );
    }

    // ===== 图片背景 =====
    if (_cachedImage != null) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: _cachedImage!,
              fit: BoxFit.cover,
              gaplessPlayback: true, // 避免切换时闪白
            ),
            _wrapWithTransparentTheme(widget.child),
          ],
        ),
      );
    }

    // ===== 无背景 =====
    return widget.child;
  }

  Widget _wrapWithTransparentTheme(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      child: child,
    );
  }
}