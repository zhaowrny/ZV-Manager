import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'dart:io' as io;
import '../../providers/server_provider.dart';
import '../../core/l10n/strings.dart';

/// 基于 dartssh2 的 SFTP 文件服务。
/// 一次连接同时支持列目录 / 上传 / 下载 / 删除 / 重命名，
/// 供模组管理（M1）与下载完成后自动上传（M2）复用。
class SftpService {
  SSHClient? _client;
  SftpClient? _sftp;
  ServerConfig? _bound;

  bool get isConnected => _client != null && !_client!.isClosed;

  /// 连接到指定服务器的 SSH。失败抛异常。
  Future<void> connect(ServerConfig server) async {
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
      onPasswordRequest: () => server.sshPassword,
    );
    _sftp = await _client!.sftp();
    _bound = server;
  }

  /// 列出目录内容。
  Future<List<SftpName>> listDir(String path) async {
    return _requireSftp().listdir(path);
  }

  /// 上传本地文件到远程路径。
  Future<void> upload(String localPath, String remotePath) async {
    final sftp = _requireSftp();
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
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
  Future<void> download(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) async {
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
  Future<String> readString(
    String remotePath, {
    int maxBytes = 2 * 1024 * 1024,
  }) async {
    final sftp = _requireSftp();
    final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    try {
      final buf = BytesBuilder();
      await for (final chunk in file.read()) {
        buf.add(chunk);
      }
      final bytes = buf.takeBytes();
      if (bytes.length <= maxBytes) return utf8.decode(bytes, allowMalformed: true);
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
    await _requireSftp().remove(remotePath);
  }

  Future<void> rename(String remotePath, String newName) async {
    final sftp = _requireSftp();
    final parent = remotePath.substring(0, remotePath.lastIndexOf('/') + 1);
    await sftp.rename(remotePath, '$parent$newName');
  }

  Future<void> mkdir(String remotePath) async {
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
    _sftp = null;
    _client?.close();
    _client = null;
    _bound = null;
  }
}
