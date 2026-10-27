import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../../providers/server_provider.dart';

/// SSH Shell（PTY）会话服务，与 SFTP 复用同一套 SSH 凭据。
/// 支持 resize、keepalive、断线自动重连（最多 3 次）。
class SshShellService {
  SSHClient? _client;
  SSHSocket? _socket;
  SSHSession? _session;
  int _failedReconnects = 0;

  bool get isConnected => _client != null && !_client!.isClosed;

  /// 建立 PTY 会话。输出通过 [onOutput] 回调（UTF-8 解码后）。
  ///
  /// - [keepAliveInterval]：15 秒发一次 keepalive，防止移动网络 NAT 超时踢掉空闲连接；
  /// - PTY 类型固定 xterm-256color，让服务端程序输出彩色与全屏界面（如 htop）。
  Future<void> connect(
    ServerConfig server, {
    required void Function(String) onOutput,
    void Function()? onDisconnected,
    int cols = 80,
    int rows = 24,
  }) async {
    await disconnect();
    _socket = await SSHSocket.connect(
      server.host,
      server.sshPort,
      timeout: const Duration(seconds: 10),
    );
    _client = SSHClient(
      _socket!,
      username: server.sshUser,
      onPasswordRequest: () => server.sshPassword,
      keepAliveInterval: const Duration(seconds: 15),
    );
    _failedReconnects = 0;

    final shell = await _client!.shell(
      pty: SSHPtyConfig(type: 'xterm-256color', width: cols, height: rows),
    );
    _session = shell;

    // stdout 正常输出；连接结束（onDone）时触发自动重连
    shell.stdout.listen(
      (data) => onOutput(utf8.decode(data, allowMalformed: true)),
      onDone: () {
        onDisconnected?.call();
        _tryReconnect(server, onOutput: onOutput, onDisconnected: onDisconnected);
      },
      onError: (_) => onDisconnected?.call(),
    );
    // stderr 与 stdout 合并到同一个终端缓冲区，符合真实终端表现
    shell.stderr.listen((data) => onOutput(utf8.decode(data, allowMalformed: true)));
  }

  /// 自动重连：最多 3 次，间隔 2s → 4s → 6s 递增。
  Future<void> _tryReconnect(
    ServerConfig server, {
    required void Function(String) onOutput,
    void Function()? onDisconnected,
  }) async {
    if (_failedReconnects >= 3) return;
    _failedReconnects++;
    await Future<void>.delayed(Duration(seconds: 2 * _failedReconnects));
    try {
      await connect(server, onOutput: onOutput, onDisconnected: onDisconnected);
      onOutput('\r\n\x1b[32m[已自动重连]\x1b[0m\r\n');
    } catch (_) {
      onDisconnected?.call();
    }
  }

  /// 写入用户输入（按键、粘贴内容）。
  void write(String input) =>
      _session?.write(Uint8List.fromList(utf8.encode(input)));

  /// 终端窗口尺寸变化（软键盘弹出、横竖屏切换时调用）。
  void resize(int cols, int rows) => _session?.resizeTerminal(cols, rows);

  Future<void> disconnect() async {
    _session?.close();
    _session = null;
    _client?.close();
    _client = null;
    _socket?.destroy();
    _socket = null;
  }
}
