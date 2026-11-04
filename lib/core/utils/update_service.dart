import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../widgets/update_dialog.dart';
import 'update_info.dart';

export 'update_info.dart';

/// 更新检查与安装服务：负责从 Gitee 拉取发布信息、下载并调起系统安装器。
class UpdateService {
  const UpdateService._();

  /// Gitee 仓库地址
  static const _repoUrl = 'https://gitee.com/driftinblock/zvmanager';

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

  /// 调用系统浏览器打开外部链接。
  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

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
      final latestVersion =
          tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty) return null;

      // 从 assets 中筛选 APK 安装包，取其直链与文件名
      String downloadUrl = '';
      String apkName = '';
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final item in assets) {
        final asset = item as Map<String, dynamic>;
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = (asset['browser_download_url'] as String? ??
              asset['download_url'] as String? ??
              '');
          apkName = name;
          break;
        }
      }

      final htmlUrl = json['html_url'] as String? ?? '';
      final releasePageUrl = htmlUrl.isNotEmpty
          ? htmlUrl
          : (tag.isEmpty
              ? '$_repoUrl/releases'
              : '$_repoUrl/releases/tag/${Uri.encodeComponent(tag)}');

      return UpdateInfo(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        apkName: apkName,
        releaseNotes: json['body'] as String? ?? '',
        releasedAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        releasePageUrl: releasePageUrl,
      );
    } finally {
      client.close();
    }
  }

  /// 判断 [latest] 是否比 [current] 新。只有新版本更高时才返回 true，
  /// 避免当前版本高于 Gitee 发布版本时误提示更新并引导降级。
  static bool isNewerVersion(String latest, String current) {
    if (latest.trim().isEmpty) return false;

    final latestParts = _parseVersion(latest);
    final currentParts = _parseVersion(current);
    if (latestParts == null || currentParts == null) {
      return latest.trim() != current.trim();
    }

    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;
    for (var i = 0; i < length; i++) {
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestPart != currentPart) return latestPart > currentPart;
    }
    return false;
  }

  /// 把 "v2.0.3+16" 解析成 [2, 0, 3]，忽略 v 前缀、后缀和构建号。
  static List<int>? _parseVersion(String version) {
    var value = version.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }

    final suffixIndex = value.indexOf(RegExp(r'[-+]'));
    if (suffixIndex >= 0) value = value.substring(0, suffixIndex);

    final parts = value.split('.');
    final numbers = <int>[];
    for (final part in parts) {
      final match = RegExp(r'^\d+').firstMatch(part);
      if (match == null) return null;
      numbers.add(int.parse(match.group(0)!));
    }
    return numbers.isEmpty ? null : numbers;
  }

  /// 展示版本对比结果弹窗；`hasUpdate` 为 false 时若无更新且 `silentOnNoUpdate` 为 true 则直接静默返回。
  static void showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
    String currentVersion, {
    bool silentOnNoUpdate = false,
  }) {
    final hasUpdate = isNewerVersion(info.latestVersion, currentVersion);
    if (!hasUpdate && silentOnNoUpdate) return;

    if (!hasUpdate) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.t('已是最新')),
          content: Text(S.f('当前版本 {0} 已是最新', [currentVersion])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: T('关闭'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(
        info: info,
        currentVersion: currentVersion,
        onUpdate: () => downloadAndInstall(context, info),
        onOpenUrl: openUrl,
      ),
    );
  }

  /// 调用 Android 原生下载 APK 并调起系统安装器；下载期间展示不可关闭的进度弹窗，失败提示错误。
  static Future<void> downloadAndInstall(
      BuildContext context, UpdateInfo info) async {
    if (_downloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: T('正在下载，请稍候…')),
      );
      return;
    }
    if (info.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: T('未找到可下载的安装包')),
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
            title: T('正在下载更新'),
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
                      percent == null
                          ? S.t('正在下载安装包…')
                          : S.f('下载中：{0}%', [percent]),
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
            SnackBar(content: Text(S.f('更新失败：{0}', [message]))),
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
