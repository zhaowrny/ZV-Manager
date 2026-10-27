import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallpaper_provider.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' show TerminalView;
import '../../core/services/ssh_shell_service.dart';

import '../../providers/server_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/empty_state_page.dart';


/// SSH 终端页：xterm 终端 + 快捷键栏 + 多服务器会话标签（M3）。
class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage>
    with AutomaticKeepAliveClientMixin {
  final Map<String, _Session> _sessions = {};
  String? _activeId;
  List<ServerConfig> _sshServers = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final servers = context.watch<ServerProvider>().servers.where((s) => s.hasSsh).toList();
    _sshServers = servers;
    if (servers.isNotEmpty && (_activeId == null || !_sessions.containsKey(_activeId))) {
      _openSession(servers.first);
    }
  }

  @override
  void dispose() {
    for (final s in _sessions.values) {
      s.service.disconnect();
      s.terminal.onOutput = null;
    }
    _sessions.clear();
    super.dispose();
  }

  Future<void> _openSession(ServerConfig server) async {
    if (_sessions.containsKey(server.id)) {
      setState(() => _activeId = server.id);
      return;
    }
    final session = _Session(server);
    _sessions[server.id] = session;
    setState(() => _activeId = server.id);
    _connect(session);
  }

  Future<void> _connect(_Session session) async {
    try {
      await session.service.connect(
        session.server,
        onOutput: (data) => session.terminal.write(data),
        onDisconnected: () {
          session.terminal.write('\r\n\x1b[31m[连接已断开]\x1b[0m\r\n');
        },
      );
    } catch (e) {
      session.terminal.write('\r\n\x1b[31m连接失败：$e\x1b[0m\r\n');
    }
  }

  void _sendKey(String data) {
    final s = _sessions[_activeId];
    if (s == null) return;
    s.service.write(data);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_sshServers.isEmpty) {
      return const EmptyStatePage(
        title: '终端',
        icon: Icons.terminal_outlined,
        message: '没有配置 SSH 的服务器。\n\n请在「服务器」页编辑服务器，开启 SSH 后即可使用终端。',
      );
    }
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final active = _sessions[_activeId];
    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: AppBar(
        title: T('终端'),
        actions: [
          PopupMenuButton<ServerConfig>(
            icon: const Icon(Icons.add),
            tooltip: S.t('新会话'),
            onSelected: _openSession,
            itemBuilder: (_) => _sshServers
                .map((s) => PopupMenuItem(value: s, child: Text(s.name)))
                .toList(),
          ),
        ],
        bottom: _sessions.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _sessions.values.map((s) {
                      final selected = s.server.id == _activeId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: ChoiceChip(
                          label: Text(s.server.name),
                          selected: selected,
                          onSelected: (_) => setState(() => _activeId = s.server.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
      ),
      body: active == null
          ? const Center(child: T('选择一台服务器开始会话'))
          : Column(
              children: [
                Expanded(
                  child: TerminalView(
                    active.terminal,
                    autofocus: true,
                  ),
                ),
                _buildQuickBar(),
              ],
            ),
    );
  }

  /// 快捷键栏：Tab / Ctrl+C / Ctrl+D / 上下历史 / 常用命令。
  ///
  /// 移动端软键盘没有这些键，因此用控制字符直接模拟：
  /// Ctrl+C = 0x03，Ctrl+D = 0x04，↑ = ESC[A，↓ = ESC[B。
  Widget _buildQuickBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _key('Tab', '\t'),
              _key('Ctrl+C', '\x03'),
              _key('Ctrl+D', '\x04'),
              _key('↑', '\x1b[A'),
              _key('↓', '\x1b[B'),
              _key('htop', 'htop\n'),
              _key('df -h', 'df -h\n'),
              _key('screen -r', 'screen -r\n'),
              _key('clear', 'clear\n'),
              _key('Esc', '\x1b'),
            ],
          ),
        ),
      ),
    );
  }

  /// 生成一个快捷按键按钮。
  /// [data] 是实际写入终端的字节（含控制字符或带换行的整条命令）。
  Widget _key(String label, String data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _sendKey(data),
      ),
    );
  }
}

/// 一个终端会话 = 一台服务器 + 终端缓冲 + SSH 服务。
///
/// 多服务器时每个会话独立保活（切页签不重连），
/// 缓冲上限 5000 行，足以回看滚动输出又不会吃太多内存。
class _Session {
  final ServerConfig server;
  final Terminal terminal = Terminal(maxLines: 5000);
  final SshShellService service = SshShellService();

  _Session(this.server) {
    terminal.onOutput = (data) => service.write(data);
  }
}
