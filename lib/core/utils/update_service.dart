import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 软件更新信息，由 Gitee 发布接口的 tag_name 与 assets 解析而来
class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String apkName;
  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.apkName,
  });
}

/// 更新检查与安装服务：负责从 Gitee 拉取发布信息、下载并调起系统安装器。
class UpdateService {
  const UpdateService._();

  /// Gitee 仓库最新发布信息地址
  static const _updateInfoUrl =
      'https://gitee.com/api/v5/repos/driftinblock/zvmanager/releases/latest';

  /// Android 原生下载安装通道
  static const _channel = MethodChannel('mc_server_manager/update');

  /// 下载进度事件通道（原生推送）
  static const _progressChannel =
      EventChannel('mc_server_manager/down_progress');

  /// 是否正在下载，用于防止重复触发并发下载到同一文件。
  static bool _downloading = false;

  /// 从 Gitee 拉取最新发布信息；接口异常返回 null（调用方决定是否静默处理）。
  static Future<UpdateInfo?> fetchInfo({String userAgent = ''}) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(_updateInfoUrl))
          .timeout(const Duration(seconds: 8));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ZVManager${userAgent.isEmpty ? '' : '/$userAgent'}',
      );
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      // Gitee 发布接口的 tag_name 形如 "v1.3.0"，去掉开头的 "v" 用于版本号对比
      final tag = json['tag_name'] as String? ?? '';
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;

      // 从 assets 中筛选 APK 安装包，取其直链与文件名
      String downloadUrl = '';
      String apkName = '';
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final item in assets) {
        final name = (item as Map<String, dynamic>)['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = (item['browser_download_url'] as String? ??
              item['download_url'] as String? ??
              '');
          apkName = name;
          break;
        }
      }

      return UpdateInfo(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        apkName: apkName,
      );
    } finally {
      client.close();
    }
  }

  /// 展示版本对比结果弹窗；`hasUpdate` 为 false 时若无更新且 `silentOnNoUpdate` 为 true 则直接静默返回。
  static void showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
    String currentVersion, {
    bool silentOnNoUpdate = false,
  }) {
    final hasUpdate = info.latestVersion != currentVersion;
    if (!hasUpdate && silentOnNoUpdate) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(hasUpdate ? '发现新版本' : '已是最新'),
        content: Text(hasUpdate
            ? '最新版本: ${info.latestVersion}\n当前版本: $currentVersion'
            : '当前版本 $currentVersion 已是最新'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          if (hasUpdate)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                downloadAndInstall(context, info);
              },
              child: const Text('立即更新'),
            ),
        ],
      ),
    );
  }

  /// 调用 Android 原生下载 APK 并调起系统安装器；下载期间展示不可关闭的进度弹窗，失败提示错误。
  static Future<void> downloadAndInstall(
      BuildContext context, UpdateInfo info) async {
    if (_downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在下载，请稍候…')),
      );
      return;
    }
    if (info.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到可下载的安装包')),
      );
      return;
    }
    if (!context.mounted) return;

    _downloading = true;
    // 进度值，范围为 0~1；原生推送前为 null，显示不确定进度条转圈。
    final progress = ValueNotifier<double?>(null);
    StreamSubscription<dynamic>? progressSub;

    try {
      progressSub = _progressChannel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final percent = event['percent'];
          if (percent is num) {
            progress.value = percent.clamp(0.0, 1.0).toDouble();
          }
        }
      });

      final navigator = Navigator.of(context, rootNavigator: true);
      // 展示不可关闭的进度弹窗（不阻塞，下载完成后关闭）
      // ignore: unawaited_futures
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('正在下载更新'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (context, value, _) {
                final percent = value == null ? null : (value * 100).round();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(value: value),
                    const SizedBox(height: 16),
                    Text(
                      percent == null ? '正在下载安装包…' : '下载中：$percent%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      try {
        await _channel.invokeMethod<void>(
          'downloadAndInstall',
          {'url': info.downloadUrl, 'filename': info.apkName},
        );
      } on PlatformException catch (e) {
        final message = e.message?.toString() ?? e.code;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败：$message')),
          );
        }
      } finally {
        // 下载/触发安装器结束后关闭进度弹窗
        if (context.mounted) {
          navigator.pop();
        }
      }
    } finally {
      await progressSub?.cancel();
      progress.dispose();
      _downloading = false;
    }
  }
}
