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

  // ---------- 演示模式状态（不建立真实 SSH 连接） ----------
  bool _demoConnected = false;

  /// 每次连接/断开自增，用来作废仍在延时输出的模拟命令
  int _demoGeneration = 0;
  void Function(String)? _demoOutput;
  String _demoLine = '';
  String _demoCwd = '~';

  bool get isConnected =>
      _demoConnected || (_client != null && !_client!.isClosed);

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
    if (server.isDemo) {
      await _startDemoSession(onOutput: onOutput);
      return;
    }
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
        _tryReconnect(server,
            onOutput: onOutput, onDisconnected: onDisconnected);
      },
      onError: (_) => onDisconnected?.call(),
    );
    // stderr 与 stdout 合并到同一个终端缓冲区，符合真实终端表现
    shell.stderr
        .listen((data) => onOutput(utf8.decode(data, allowMalformed: true)));
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
  void write(String input) {
    if (_demoConnected) {
      final out = _demoOutput;
      if (out != null) _demoHandleInput(input, out);
      return;
    }
    _session?.write(Uint8List.fromList(utf8.encode(input)));
  }

  /// 终端窗口尺寸变化（软键盘弹出、横竖屏切换时调用）。
  void resize(int cols, int rows) => _session?.resizeTerminal(cols, rows);

  Future<void> disconnect() async {
    _demoConnected = false;
    _demoGeneration++;
    _demoOutput = null;
    _session?.close();
    _session = null;
    _client?.close();
    _client = null;
    _socket?.destroy();
    _socket = null;
  }

  // ==================== 演示模式 ====================

  Future<void> _startDemoSession(
      {required void Function(String) onOutput}) async {
    await disconnect();
    _demoOutput = onOutput;
    _demoLine = '';
    _demoCwd = '~';
    // 模拟 SSH 握手耗时
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _demoConnected = true;
    onOutput('\x1b[32m✔ 已连接演示服务器 SSH 终端（模拟会话）\x1b[0m\r\n');
    onOutput('\x1b[90m输入 help 查看可用命令\x1b[0m\r\n\r\n');
    onOutput(_demoPrompt);
  }

  String get _demoPrompt =>
      '\x1b[32mdemo@zvmanager-demo\x1b[0m:\x1b[34m$_demoCwd\x1b[0m\$ ';

  /// 模拟 PTY 的输入回显与行编辑（真实终端里这些由服务端完成）。
  void _demoHandleInput(String input, void Function(String) out) {
    var i = 0;
    while (i < input.length && _demoConnected) {
      final ch = input[i];
      // 跳过方向键等 ANSI 转义序列（ESC [ X）
      if (ch == '\x1b') {
        i++;
        if (i < input.length && input[i] == '[') {
          i++;
          while (i < input.length && !RegExp(r'[A-Za-z~]').hasMatch(input[i])) {
            i++;
          }
          i++;
        }
        continue;
      }
      if (ch == '\r' || ch == '\n') {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        i++;
        out('\r\n');
        final line = _demoLine;
        _demoLine = '';
        _demoRun(line, out);
        continue;
      }
      if (ch == '\x7f' || ch == '\b') {
        if (_demoLine.isNotEmpty) {
          _demoLine = _demoLine.substring(0, _demoLine.length - 1);
          out('\b \b');
        }
        i++;
        continue;
      }
      if (ch == '\x03') {
        _demoLine = '';
        out('^C\r\n$_demoPrompt');
        i++;
        continue;
      }
      if (ch.codeUnitAt(0) < 0x20) {
        i++;
        continue;
      }
      _demoLine += ch;
      out(ch);
      i++;
    }
  }

  void _demoRun(String raw, void Function(String) out) {
    final cmd = raw.trim();
    if (cmd.isEmpty) {
      out(_demoPrompt);
      return;
    }
    final lower = cmd.toLowerCase();

    if (lower == 'clear') {
      out('\x1b[2J\x1b[H$_demoPrompt');
      return;
    }
    if (lower == 'exit' || lower == 'logout') {
      out('logout\r\n');
      _demoConnected = false;
      final gen = ++_demoGeneration;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (gen != _demoGeneration || _demoOutput == null) return;
        _demoConnected = true;
        _demoOutput!('\x1b[32m[已自动重连]\x1b[0m\r\n\r\n$_demoPrompt');
      });
      return;
    }
    if (lower == './start.sh' ||
        lower == 'start.sh' ||
        lower == 'java -jar server.jar') {
      _demoPrintLines([
        '[Server thread/INFO]: Starting minecraft server version 1.20.1',
        '[Server thread/INFO]: Loading properties',
        '[Server thread/INFO]: Preparing level "world"',
        '[Server thread/INFO]: Done (3.512s)! For help, type "help"',
      ], out);
      return;
    }
    if (lower == 'htop' || lower == 'top') {
      out('\x1b[36m  1  [|||||            25.0%]\x1b[0m   Tasks: 42, 128 thr; 1 running\r\n'
          '\x1b[36m  Mem[|||||||     1.24G/8.00G]\x1b[0m   Load average: 0.42 0.35 0.28\r\n'
          '\x1b[36m  Swp[                 0K/2.00G]\x1b[0m\r\n\r\n'
          '  PID USER      PRI  NI  VIRT   RES  S CPU% MEM%   TIME+  Command\r\n'
          '  812 demo       20   0 4.2G 1.1G  S 12.0  6.1  1:23.45 java -jar server.jar\r\n'
          '  901 demo       20   0 102M  12M  S  0.3  0.1  0:01.20 bash\r\n'
          '\x1b[90m（演示数据）\x1b[0m\r\n$_demoPrompt');
      return;
    }
    if (lower == 'help') {
      out('\x1b[1m演示终端可用命令:\x1b[0m\r\n'
          '  help             显示此帮助\r\n'
          '  ls / pwd / cd    浏览模拟目录\r\n'
          '  cat <文件>        查看模拟文件（server.properties、eula.txt、logs/latest.log）\r\n'
          '  htop / top       进程与资源占用\r\n'
          '  free -h / df -h / uptime / date\r\n'
          '  java -version / whoami / uname -a\r\n'
          '  ./start.sh       模拟启动服务端并输出日志\r\n'
          '  clear / exit     清屏 / 退出（2 秒后自动重连）\r\n'
          '其余命令返回 command not found\r\n$_demoPrompt');
      return;
    }
    if (lower == 'ls' || lower.startsWith('ls ') || lower == 'll') {
      out('\x1b[34mlogs\x1b[0m  \x1b[34mmods\x1b[0m  \x1b[34mplugins\x1b[0m  '
          '\x1b[34mworld\x1b[0m  eula.txt  server.jar  server.properties  start.sh  '
          'whitelist.json\r\n$_demoPrompt');
      return;
    }
    if (lower == 'pwd') {
      out('${_demoCwd == '~' ? '/home/demo' : _demoCwd}\r\n$_demoPrompt');
      return;
    }
    if (lower == 'cd' || lower.startsWith('cd ')) {
      final target = cmd.length > 2 ? cmd.substring(2).trim() : '~';
      if (target.isEmpty || target == '~' || target == '..') {
        _demoCwd = '~';
      } else if (target.startsWith('/')) {
        _demoCwd = target;
      } else {
        _demoCwd = '~/$target';
      }
      out(_demoPrompt);
      return;
    }
    if (lower.startsWith('cat ')) {
      final file = cmd.substring(4).trim();
      switch (file) {
        case 'eula.txt':
          out('eula=true\r\n$_demoPrompt');
          return;
        case 'server.properties':
          out('#Minecraft server properties\r\n'
              'level-name=world\r\n'
              'max-players=20\r\n'
              'online-mode=true\r\n'
              'motd=ZV Manager 演示服务器\r\n'
              'server-port=25565\r\n'
              'rcon.port=25575\r\n'
              'enable-rcon=true\r\n'
              '$_demoPrompt');
          return;
        case 'whitelist.json':
          out('[\r\n]\r\n$_demoPrompt');
          return;
        case 'logs/latest.log':
          _demoPrintLines([
            '[12:00:01] [Server thread/INFO]: Starting minecraft server version 1.20.1',
            '[12:00:05] [Server thread/INFO]: Done (3.512s)! For help, type "help"',
            '[12:00:10] [Server thread/INFO]: Steve joined the game',
            '[12:00:12] [Server thread/INFO]: Alex joined the game',
            '[12:00:15] [Server thread/INFO]: Notch joined the game',
          ], out);
          return;
        default:
          out('cat: $file: No such file or directory\r\n$_demoPrompt');
          return;
      }
    }
    if (lower == 'whoami') {
      out('demo\r\n$_demoPrompt');
      return;
    }
    if (lower == 'hostname') {
      out('zvmanager-demo\r\n$_demoPrompt');
      return;
    }
    if (lower.startsWith('uname')) {
      out('Linux zvmanager-demo 6.8.0-demo #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux\r\n'
          '$_demoPrompt');
      return;
    }
    if (lower == 'date') {
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      out('${now.year}-${two(now.month)}-${two(now.day)} '
          '${two(now.hour)}:${two(now.minute)}:${two(now.second)} ${now.timeZoneName}\r\n'
          '$_demoPrompt');
      return;
    }
    if (lower == 'free' || lower == 'free -h') {
      out('               total        used        free      shared  buff/cache   available\r\n'
          'Mem:           7.7Gi       1.2Gi       4.9Gi        64Mi       1.6Gi       6.3Gi\r\n'
          'Swap:          2.0Gi          0B       2.0Gi\r\n$_demoPrompt');
      return;
    }
    if (lower == 'df' || lower == 'df -h') {
      out('Filesystem      Size  Used Avail Use% Mounted on\r\n'
          '/dev/nvme0n1p1   64G   28G   36G  44% /\r\n'
          'tmpfs           3.9G     0  3.9G   0% /dev/shm\r\n$_demoPrompt');
      return;
    }
    if (lower == 'uptime') {
      out(' 12:34:56 up 3 days,  2:10,  1 user,  load average: 0.42, 0.35, 0.28\r\n'
          '$_demoPrompt');
      return;
    }
    if (lower.startsWith('java -version')) {
      out('openjdk version "17.0.10" 2024-01-16 LTS\r\n'
          'OpenJDK Runtime Environment Temurin-17.0.10+7 (build 17.0.10+7-LTS)\r\n'
          'OpenJDK 64-Bit Server VM Temurin-17.0.10+7 (build 17.0.10+7-LTS, mixed mode)\r\n'
          '$_demoPrompt');
      return;
    }

    out('bash: $cmd: command not found\r\n'
        '\x1b[90m输入 help 查看可用命令\x1b[0m\r\n$_demoPrompt');
  }

  /// 模拟命令输出逐行打印（仅演示模式使用）。
  void _demoPrintLines(List<String> lines, void Function(String) out) {
    final gen = _demoGeneration;
    Future<void>(() async {
      for (final line in lines) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (gen != _demoGeneration || !_demoConnected) return;
        out('$line\r\n');
      }
      out(_demoPrompt);
    });
  }
}
