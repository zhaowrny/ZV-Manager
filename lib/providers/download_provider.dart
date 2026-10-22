import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/modrinth_api.dart';
import '../../core/services/mirror_service.dart';
import '../../providers/server_provider.dart';

/// 下载中心状态：镜像源选择 + Modrinth 搜索 + 下载队列暴露。
class DownloadProvider extends ChangeNotifier {
  final MirrorService mirror = MirrorService();
  late final ModrinthApi api = ModrinthApi(mirror);
  late final DownloadManager manager = DownloadManager(
    maxConcurrent: 3,
    onTaskCompleteUpload: _autoUpload,
  );

  ServerConfig? uploadTarget; // 下载完成后自动上传到的服务器

  Future<void> init() async {
    await mirror.load();
  }

  /// 搜索 Modrinth。
  Future<List<ModrinthSearchResult>> search(
      String query, {String? mcVersion, String? loader, String projectType = 'mod', int limit = 20}) {
    return api.search(
      query: query,
      mcVersion: mcVersion,
      loader: loader,
      projectType: projectType,
      limit: limit,
    );
  }

  /// 获取某项目的版本列表。
  Future<List<ModrinthVersion>> versions(String projectId) => api.versions(projectId);

  /// 入队下载：保存到应用下载目录；若配置了 uploadTarget 且其有 SSH，
  /// 完成后自动上传到 mods/plugins 目录。
  Future<DownloadTask> download({
    required String url,
    required String fileName,
    required String projectType, // mod | plugin
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final saveDir = '${base.path}/downloads';
    await Directory(saveDir).create(recursive: true);
    String? remoteDir;
    final target = uploadTarget;
    if (target != null && target.hasSsh) {
      final home = target.sshUser == 'root' ? '/root' : '/home/${target.sshUser}';
      remoteDir = '$home/${projectType == 'plugin' ? 'plugins' : 'mods'}';
    }
    return manager.enqueue(
      url: mirror.rewrite(url),
      fileName: fileName,
      saveDir: saveDir,
      sftpRemoteDir: remoteDir,
    );
  }

  Future<void> _autoUpload(DownloadTask task) async {
    final target = uploadTarget;
    if (target == null || !target.hasSsh || task.sftpRemoteDir == null) return;
    try {
      await uploadViaSftp(
        task,
        ServerLike(
          host: target.host,
          sshPort: target.sshPort,
          sshUser: target.sshUser,
          sshPassword: target.sshPassword,
        ),
      );
    } catch (_) {
      // 上传失败不影响下载状态，用户可在下载记录里手动重试
    }
  }

  @override
  void dispose() {
    manager.dispose();
    mirror.dispose();
    super.dispose();
  }
}
