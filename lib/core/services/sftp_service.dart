import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'dart:io' as io;
import '../../providers/server_provider.dart';
import '../../core/l10n/strings.dart';
import 'demo_server.dart';

/// 基于 dartssh2 的 SFTP 文件服务。
/// 一次连接同时支持列目录 / 上传 / 下载 / 删除 / 重命名，
/// 供模组管理（M1）与下载完成后自动上传（M2）复用。
///
/// 演示服务器（`ServerConfig.isDemo`）使用内存文件系统，
/// 不建立真实 SSH 连接，便于在无服务器环境下测试完整流程。
class SftpService {
  SSHClient? _client;
  SftpClient? _sftp;

  /// 当前连接绑定的服务器，用于判断能否复用已有连接
  ServerConfig? _bound;

  bool _demoConnected = false;
  final DemoFileSystem _demoFs = DemoFileSystem();

  bool get isConnected =>
      _demoConnected || (_client != null && !_client!.isClosed);

  /// 连接到指定服务器的 SSH。失败抛异常。
  ///
  /// 如果已经连到同一台服务器则直接复用，避免重复握手（SSH 握手较慢）。
  Future<void> connect(ServerConfig server) async {
    if (server.isDemo) {
      await disconnect();
      // 模拟握手耗时
      await Future<void>.delayed(const Duration(milliseconds: 180));
      _demoConnected = true;
      return;
    }
    if (isConnected && _bound?.id == server.id) return;
    await disconnect();
    final socket = await SSHSocket.connect(
      server.host,
      server.sshPort,
      timeout: const Duration(seconds: 10),
    );
    _client = SSHClient(
      socket,
      username: server.sshUser,
      // 目前仅支持密码认证；密钥认证需在设置里扩展
      onPasswordRequest: () => server.sshPassword,
    );
    _sftp = await _client!.sftp();
    _bound = server;
  }

  /// 列出目录内容。
  Future<List<SftpName>> listDir(String path) async {
    if (_demoConnected) return _demoFs.list(path);
    return _requireSftp().listdir(path);
  }

  /// 上传本地文件到远程路径。
  ///
  /// 采用 create + truncate 模式覆盖写入；流式读取本地文件，
  /// 大文件不会一次性读进内存。
  Future<void> upload(String localPath, String remotePath) async {
    if (_demoConnected) {
      await _demoFs.upload(localPath, remotePath);
      return;
    }
    final sftp = _requireSftp();
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );
    try {
      final local = io.File(localPath);

      final writer = file.write(
        local.openRead().map((chunk) => Uint8List.fromList(chunk)),
        onProgress: (_) {},
      );
      // 预读 stat.size 仅用于日志/进度；writer 自行完成
      await writer.done;
    } finally {
      await file.close();
    }
  }

  /// 下载远程文件到本地路径。
  ///
  /// [onProgress] 参数为 (已下载字节, 总字节)；总字节未知时为 0。
  Future<void> download(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) async {
    if (_demoConnected) {
      await _demoFs.download(remotePath, localPath, onProgress: onProgress);
      return;
    }
    final sftp = _requireSftp();
    final stat = await sftp.stat(remotePath);
    final total = stat.size ?? 0;
    final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    try {
      final sink = io.File(localPath).openWrite();
      var received = 0;
      await for (final chunk in file.read(onProgress: null)) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
    } finally {
      await file.close();
    }
  }

  /// 读取远程文件文本内容（保留末尾 maxBytes 字节，适合大日志文件）。
  ///
  /// 服务器日志动辄上百 MB，全量读取会撑爆内存且价值不大，
  /// 因此超限时只保留尾部——排查崩溃时真正关心的是最后那段堆栈。
  /// 截断位置会向前对齐到 UTF-8 字符边界，避免出现乱码。
  Future<String> readString(
    String remotePath, {
    int maxBytes = 2 * 1024 * 1024,
  }) async {
    if (_demoConnected) {
      return _demoFs.readString(remotePath, maxBytes: maxBytes);
    }
    final sftp = _requireSftp();
    final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    try {
      final buf = BytesBuilder();
      await for (final chunk in file.read()) {
        buf.add(chunk);
      }
      final bytes = buf.takeBytes();
      if (bytes.length <= maxBytes) {
        return utf8.decode(bytes, allowMalformed: true);
      }
      // 只保留末尾 maxBytes，并跳过半个字符
      var start = bytes.length - maxBytes;
      while (start < bytes.length && (bytes[start] & 0xC0) == 0x80) {
        start++;
      }
      return utf8.decode(bytes.sublist(start), allowMalformed: true);
    } finally {
      await file.close();
    }
  }

  Future<void> delete(String remotePath) async {
    if (_demoConnected) {
      _demoFs.delete(remotePath);
      return;
    }
    await _requireSftp().remove(remotePath);
  }

  Future<void> rename(String remotePath, String newName) async {
    if (_demoConnected) {
      _demoFs.rename(remotePath, newName);
      return;
    }
    final sftp = _requireSftp();
    final parent = remotePath.substring(0, remotePath.lastIndexOf('/') + 1);
    await sftp.rename(remotePath, '$parent$newName');
  }

  Future<void> mkdir(String remotePath) async {
    if (_demoConnected) {
      _demoFs.mkdir(remotePath);
      return;
    }
    try {
      await _requireSftp().mkdir(remotePath);
    } catch (_) {
      // 已存在时忽略
    }
  }

  SftpClient _requireSftp() {
    final sftp = _sftp;
    if (sftp == null || !isConnected) {
      throw StateError(S.t('SFTP 未连接，请先调用 connect()'));
    }
    return sftp;
  }

  Future<void> disconnect() async {
    _demoConnected = false;
    _sftp = null;
    _client?.close();
    _client = null;
    _bound = null;
  }
}
