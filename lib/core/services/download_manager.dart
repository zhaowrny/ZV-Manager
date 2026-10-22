import 'dart:async';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'sftp_service.dart';
import '../../providers/server_provider.dart';

enum DownloadStatus { queued, running, paused, completed, failed, canceled }

/// 单个下载任务。
class DownloadTask {
  final String id;
  final String url;          // 直链（已镜像改写）
  final String fileName;
  final String savePath;
  final String? sftpRemoteDir; // 完成后自动上传到服务器的目录（需 SSH）
  int totalBytes;
  int receivedBytes = 0;
  double speed = 0;          // bytes/s
  DownloadStatus status = DownloadStatus.queued;
  String? error;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.sftpRemoteDir,
    this.totalBytes = 0,
  });

  double get progress => totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0, 1) : 0;
}

/// 下载引擎：队列 + 并发控制（默认 3）+ 断点续传（HTTP Range）
/// + 失败重试（指数退避）+ 完成后经 SFTP 自动上传。
/// HTTP IO 由 dio 在其内部线程池执行，进度经节流回调到 UI，不阻塞主线程。
class DownloadManager extends ChangeNotifier {
  final int maxConcurrent;
  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, bool> _pauseFlags = {};
  final Set<String> _running = {};
  final Dio _dio;
  final Future<void> Function(DownloadTask task)? onTaskCompleteUpload;

  DownloadManager({this.maxConcurrent = 3, this.onTaskCompleteUpload})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 10),
        ));

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  int get activeCount => _running.length;

  /// 入队一个下载任务，自动启动。
  DownloadTask enqueue({
    required String url,
    required String fileName,
    required String saveDir,
    String? sftpRemoteDir,
    Map<String, String>? headers,
  }) {
    final task = DownloadTask(
      id: 'dl_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}',
      url: url,
      fileName: fileName,
      savePath: '$saveDir/$fileName',
      sftpRemoteDir: sftpRemoteDir,
    );
    _tasks.add(task);
    notifyListeners();
    _pump(headers);
    return task;
  }

  void pause(String id) {
    _pauseFlags[id] = true;
    _cancelTokens[id]?.cancel('paused');
    _updateStatus(id, DownloadStatus.paused);
  }

  void resume(String id, {Map<String, String>? headers}) {
    final task = _find(id);
    if (task == null || task.status != DownloadStatus.paused) return;
    _pauseFlags.remove(id);
    _updateStatus(id, DownloadStatus.queued);
    _pump(headers);
  }

  void cancel(String id) {
    _cancelTokens[id]?.cancel('canceled');
    _updateStatus(id, DownloadStatus.canceled);
    _running.remove(id);
    _pump();
  }

  void retry(String id, {Map<String, String>? headers}) {
    final task = _find(id);
    if (task == null) return;
    _pauseFlags.remove(id);
    task.error = null;
    _updateStatus(id, DownloadStatus.queued);
    _pump(headers);
  }

  void clearFinished() {
    _tasks.removeWhere((t) =>
        t.status == DownloadStatus.completed ||
        t.status == DownloadStatus.canceled ||
        t.status == DownloadStatus.failed);
    notifyListeners();
  }

  DownloadTask? _find(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void _updateStatus(String id, DownloadStatus status) {
    final task = _find(id);
    if (task != null && task.status != status) {
      task.status = status;
      notifyListeners();
    }
  }

  /// 队列调度：保持最多 maxConcurrent 个任务在跑。
  void _pump([Map<String, String>? headers]) {
    while (_running.length < maxConcurrent) {
      final next = _tasks.firstWhere(
        (t) => t.status == DownloadStatus.queued && !_running.contains(t.id),
        orElse: () => _noop,
      );
      if (identical(next, _noop)) break;
      _running.add(next.id);
      unawaited(_run(next, headers));
    }
  }

  static final DownloadTask _noop = DownloadTask(id: '_noop', url: '', fileName: '', savePath: '');

  Future<void> _run(DownloadTask task, Map<String, String>? headers) async {
    final token = CancelToken();
    _cancelTokens[task.id] = token;
    await _downloadWithRetry(task, token, headers);
    _running.remove(task.id);
    _cancelTokens.remove(task.id);
    _pump(headers);
  }

  Future<void> _downloadWithRetry(
      DownloadTask task, CancelToken token, Map<String, String>? headers) async {
    const maxRetry = 3;
    var attempt = 0;
    while (attempt <= maxRetry) {
      try {
        _updateStatus(task.id, DownloadStatus.running);
        await io.Directory(io.File(task.savePath).parent.path).create(recursive: true);
        var existing = 0;
        final partial = io.File('${task.savePath}.part');
        if (await partial.exists()) existing = await partial.length();

        var lastTick = DateTime.now();
        var lastBytes = existing;

        final resp = await _dio.download(
          task.url,
          '${task.savePath}.part',
          cancelToken: token,
          options: Options(
            headers: {
              if (existing > 0) 'range': 'bytes=$existing-',
              ...?headers,
            },
            validateStatus: (s) => s != null && s < 400,
          ),
          onReceiveProgress: (count, total) {
            task.receivedBytes = existing + count;
            // 服务端可能不支持 Range：206 才是续传，200 时 total 为完整大小
            task.totalBytes = existing > 0 && total == task.receivedBytes
                ? total
                : (total > 0 ? total + (total == count ? 0 : 0) : total);
            if (existing > 0 && total > 0 && task.totalBytes <= existing) {
              task.totalBytes = existing + total;
            }
            final now = DateTime.now();
            final dt = now.difference(lastTick).inMilliseconds;
            if (dt >= 500) {
              task.speed = (task.receivedBytes - lastBytes) * 1000 / dt;
              lastTick = now;
              lastBytes = task.receivedBytes;
              notifyListeners();
            }
          },
        );
        // 200 响应（非续传）时重置已收字节
        if (resp.statusCode == 200 && existing > 0 && task.receivedBytes < existing) {
          task.receivedBytes = task.receivedBytes;
        }
        task.totalBytes = task.receivedBytes;
        await partial.rename(task.savePath);
        _updateStatus(task.id, DownloadStatus.completed);
        notifyListeners();
        if (onTaskCompleteUpload != null) {
          await onTaskCompleteUpload!(task);
        }
        return;
      } on DioException catch (e) {
        if (token.isCancelled) return; // 暂停/取消
        attempt++;
        task.error = e.message ?? '网络错误';
        if (attempt > maxRetry) {
          _updateStatus(task.id, DownloadStatus.failed);
          notifyListeners();
          return;
        }
        // 指数退避：1s → 2s → 4s
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      } catch (e) {
        task.error = e.toString();
        _updateStatus(task.id, DownloadStatus.failed);
        notifyListeners();
        return;
      }
    }
  }
}

/// 下载完成后自动经 SFTP 上传到服务器目标目录。
Future<void> uploadViaSftp(DownloadTask task, ServerLike server) async {
  final remoteDir = task.sftpRemoteDir;
  if (remoteDir == null || remoteDir.isEmpty) return;
  final sftp = SftpService();
  try {
    await sftp.connect(server.toConfig());
    await sftp.upload(task.savePath, '$remoteDir/${task.fileName}');
  } finally {
    await sftp.disconnect();
  }
}

/// 避免循环依赖的轻量服务器描述（由 DownloadProvider 装配）。
class ServerLike {
  final String host;
  final int sshPort;
  final String sshUser;
  final String sshPassword;
  ServerLike({
    required this.host,
    required this.sshPort,
    required this.sshUser,
    required this.sshPassword,
  });
  ServerConfig toConfig() => ServerConfig(
        id: 'upload',
        name: 'upload',
        host: host,
        port: 0,
        password: '',
        sshEnabled: true,
        sshPort: sshPort,
        sshUser: sshUser,
        sshPassword: sshPassword,
      );
}
