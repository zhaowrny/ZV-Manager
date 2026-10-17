import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/background_service.dart';

/// 壁纸描述。可比较，便于 `ValueNotifier` 去重。
@immutable
class BackgroundSpec {
  final String? type; // 'image' | 'video' | null
  final String? path;

  const BackgroundSpec({this.type, this.path});

  const BackgroundSpec.none()
      : type = null,
        path = null;

  bool get isEmpty => path == null;

  @override
  bool operator ==(Object other) =>
      other is BackgroundSpec && other.type == type && other.path == path;

  @override
  int get hashCode => Object.hash(type, path);
}

/// 已解析、可绘制的背景层。
class _Layer {
  final ImageProvider? image;
  final VideoPlayerController? video;

  const _Layer.image(ImageProvider this.image) : video = null;
  const _Layer.video(VideoPlayerController this.video) : image = null;

  bool get isVideo => video != null;

  Future<void> dispose() async => video?.dispose();
}

/// 全局壁纸背景。
///
/// 原实现切壁纸会闪屏，原因有三条，这里逐一解决：
///
/// 1. `_isLoading` 为 true 时直接返回 child —— 加载期间背景整棵树被换掉，
///    露出主题底色。现在改为「新图层叠在旧图层上」，加载期间旧壁纸照常显示。
/// 2. 切换时先清空 `_cachedImage` / 关掉视频，再异步初始化新资源；
///    中间任何一次 setState 都已经丢掉了画面。现在旧图层保持存活，
///    直到新图层首帧绘制完成才淡出并释放。
/// 3. 图片未 `precacheImage`，`Image` 首帧为空 —— 即使有旧图层叠加，
///    叠上来的也是一个透明空帧。现在解码完成才参与合成。
class BackgroundWidget extends StatefulWidget {
  final Widget child;

  const BackgroundWidget({super.key, required this.child});

  /// 当前壁纸值。由 `main.dart` 在启动时用 Provider 预加载结果写入，
  /// 避免「首帧无壁纸、次帧才出现」的启动闪烁。
  static final ValueNotifier<BackgroundSpec> spec =
      ValueNotifier<BackgroundSpec>(const BackgroundSpec.none());

  @override
  State<BackgroundWidget> createState() => BackgroundWidgetState();
}

class BackgroundWidgetState extends State<BackgroundWidget>
    with WidgetsBindingObserver {
  static const Duration _fadeDuration = Duration(milliseconds: 300);

  /// 已生效的图层。
  _Layer? _active;
  String? _activeKey;

  /// 正在淡入的图层。
  _Layer? _incoming;
  String? _incomingKey;

  /// 进行中的请求序号，用于丢弃过期结果。
  int _requestSeq = 0;

  bool _isInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply(BackgroundWidget.spec.value, animate: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isInForeground = false;
      _active?.video?.pause();
      _incoming?.video?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      final v = _active?.video;
      if (v != null && v.value.isInitialized) v.play();
    }
  }

  /// 外部入口：按 `spec` 最新值切换壁纸。
  void refreshBackground() => _apply(BackgroundWidget.spec.value, animate: true);

  static String _keyOf(BackgroundSpec s) => s.isEmpty ? 'none' : '${s.type}:${s.path}';

  Future<_Layer?> _buildLayer(BackgroundSpec spec) async {
    if (spec.isEmpty) return null;
    final file = File(spec.path!);
    if (!file.existsSync()) return null;

    if (spec.type == 'video') {
      final sound = await BackgroundService.getVideoSound();
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize().timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('壁纸视频初始化失败: $e');
        await controller.dispose();
        return null;
      }
      await controller.setLooping(true);
      await controller.setVolume(sound ? 1.0 : 0.0);
      // 停在首帧：淡入完成后再统一播放，避免声音早于画面
      await controller.seekTo(Duration.zero);
      return _Layer.video(controller);
    }

    if (spec.type == 'image') {
      final provider = FileImage(file);
      try {
        // 解码进图片缓存，保证合成上去的第一帧就是完整画面
        await precacheImage(provider, context);
      } catch (e) {
        debugPrint('壁纸图片预加载失败: $e');
        return null;
      }
      return _Layer.image(provider);
    }

    return null;
  }

  Future<void> _apply(BackgroundSpec spec, {required bool animate}) async {
    final key = _keyOf(spec);
    // 同一张壁纸重复设置：忽略，避免无意义的淡入
    if (key == _activeKey && _incoming == null) return;

    final seq = ++_requestSeq;
    final layer = await _buildLayer(spec);

    if (!mounted || seq != _requestSeq) {
      await layer?.dispose();
      return;
    }

    // 加载失败（文件丢失、解码失败）：保持当前画面不动，不要退回主题底色。
    // 唯一例外是用户主动清除壁纸（spec 为空），那本来就该回到无背景。
    if (layer == null && !spec.isEmpty) {
      debugPrint('壁纸加载失败，保持当前背景: $key');
      return;
    }

    if (!animate) {
      final old = _active;
      setState(() {
        _active = layer;
        _activeKey = key;
        _incoming = null;
        _incomingKey = null;
      });
      await old?.dispose();
      _startActivePlayback();
      return;
    }

    setState(() {
      _incoming = layer;
      _incomingKey = key;
    });

    // 等新图层真正上屏再开始计时
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(_fadeDuration, () async {
        if (!mounted || seq != _requestSeq) return;
        final old = _active;
        setState(() {
          _active = layer;
          _activeKey = key;
          _incoming = null;
          _incomingKey = null;
        });
        _startActivePlayback();
        // 淡出动画走完再释放旧控制器，避免正在播放的视频被提前销毁
        await Future<void>.delayed(_fadeDuration);
        await old?.dispose();
      });
    });
  }

  void _startActivePlayback() {
    final v = _active?.video;
    if (v != null && v.value.isInitialized && _isInForeground) {
      v.play();
    }
  }

  @override
  void dispose() {
    _requestSeq++; // 让在途请求失效
    WidgetsBinding.instance.removeObserver(this);
    _active?.dispose();
    _incoming?.dispose();
    super.dispose();
  }

  Widget _buildLayerWidget(_Layer layer) {
    final v = layer.video;
    if (v != null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: v.value.size.width,
          height: v.value.size.height,
          child: VideoPlayer(v),
        ),
      );
    }
    return Image(
      image: layer.image!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final incoming = _incoming;

    if (active == null && incoming == null) {
      return widget.child;
    }

    final showingVideo = (incoming ?? active)!.isVideo;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 与主题一致的底色，视频有黑边或加载中也不会露白
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),

        // 旧图层常驻，新图层叠上去做交叉淡入
        if (active != null) _buildLayerWidget(active),
        if (incoming != null)
          _FadeIn(
            key: ValueKey(_incomingKey),
            duration: _fadeDuration,
            child: _buildLayerWidget(incoming),
          ),

        if (showingVideo)
          IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.3))),

        _wrapWithTransparentTheme(widget.child),
      ],
    );
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

/// 从上到下淡入的子层。
///
/// 注意：不能直接用 `AnimatedOpacity(opacity: 1)` —— 它只在 opacity 属性
/// 变化时动画，首次构建即 1 是不会有任何过渡的。这里用显式控制器，
/// 在首帧后把 0 → 1，保证新壁纸是「渐渐出现」而不是「啪一下替换」。
class _FadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _FadeIn({
    super.key,
    required this.child,
    required this.duration,
  });

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
