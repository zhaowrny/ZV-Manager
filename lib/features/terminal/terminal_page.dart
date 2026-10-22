import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' show TerminalView;
import '../../core/services/ssh_shell_service.dart';

import '../../providers/server_provider.dart';


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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('没有配置 SSH 的服务器。\n\n请在「服务器」页编辑服务器，开启 SSH 后即可使用终端。',
              textAlign: TextAlign.center),
        ),
      );
    }
    final active = _sessions[_activeId];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('终端'),
        actions: [
          PopupMenuButton<ServerConfig>(
            icon: const Icon(Icons.add),
            tooltip: '新会话',
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
          ? const Center(child: Text('选择一台服务器开始会话'))
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
class _Session {
  final ServerConfig server;
  final Terminal terminal = Terminal(maxLines: 5000);
  final SshShellService service = SshShellService();

  _Session(this.server) {
    terminal.onOutput = (data) => service.write(data);
  }
}
