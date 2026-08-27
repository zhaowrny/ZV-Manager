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

// 导出 State 供外部调用
class BackgroundWidgetState extends State<BackgroundWidget> {
  VideoPlayerController? _controller;
  String? _currentType;
  String? _currentPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    final data = await BackgroundService.getBackground();
    final type = data['type'];
    final path = data['path'];

    // 如果没变化就不重新加载
    if (_currentType == type && _currentPath == path && _controller != null) {
      setState(() => _isLoading = false);
      return;
    }

    // 释放旧视频
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    _currentType = type;
    _currentPath = path;

    if (type == 'video' && path != null) {
      try {
        final videoSound = await BackgroundService.getVideoSound();
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        controller.setLooping(true);
        controller.setVolume(videoSound ? 1.0 : 0.0);
        controller.play();
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
        return;
      } catch (e) {
        print('视频加载失败: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  // 供外部调用的刷新方法
  void refreshBackground() {
    _loadBackground();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.child;
    }

    // 有视频背景
    if (_controller != null && _controller!.value.isInitialized) {
      return Stack(
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
      );
    }

    // 有图片背景
    if (_currentType == 'image' && _currentPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_currentPath!), fit: BoxFit.cover),
          _wrapWithTransparentTheme(widget.child),
        ],
      );
    }

    // 无背景
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