import 'dart:async';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'sftp_service.dart';
import '../../providers/server_provider.dart';
import '../../core/l10n/strings.dart';

enum DownloadStatus { queued, running, paused, completed, failed, canceled }

/// 单个下载任务。
///
/// 进度语义：进度以 `.part` 临时文件为基础，
/// [receivedBytes] 始终表示"该文件已落盘的字节数"（含续传前已存在的部分），
/// [totalBytes] 表示文件完整大小（未知时为 0）。
class DownloadTask {
  final String id;

  /// 直链（已按当前镜像线路改写）
  final String url;
  final String fileName;
  final String savePath;

  /// 完成后自动上传到服务器的目录（需 SSH；为空则不上传）
  final String? sftpRemoteDir;
  int totalBytes;
  int receivedBytes = 0;

  /// 实时速度，单位 bytes/s，由 500ms 采样窗口计算
  double speed = 0;
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
  int maxConcurrent;
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

  /// 修改并发数（设置页可调），立即生效。
  void setConcurrency(int n) {
    if (n < 1 || n > 6) return;
    maxConcurrent = n;
    _pump();
  }

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

        await _dio.download(
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
            // 断点续传时 dio 的 total 只统计「本次请求」的剩余字节，
            // 因此需加上已有的 existing；不支持 Range 时服务端返回 200，
            // 此时 total 已是完整文件大小，直接用即可。
            if (total > 0) {
              task.totalBytes = existing > 0 && count <= total
                  ? existing + total
                  : total;
            }
            // 兜底：若推算出的总量反而小于已收字节，说明服务端行为异常，
            // 直接把已收量当作总量，避免进度条超过 100%。
            if (task.totalBytes > 0 && task.totalBytes < task.receivedBytes) {
              task.totalBytes = task.receivedBytes;
            }
            // 节流：每 500ms 采样一次速度并刷新 UI，避免高频 notify 卡顿
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
        // 全部下载完成后把 .part 改名为正式文件（原子操作，避免半成品被当成完整文件）
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
        task.error = e.message ?? S.t('网络错误');
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
