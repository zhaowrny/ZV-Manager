import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/rcon_client.dart';
import '../../providers/rcon_provider.dart';

import '../console/console_page.dart';
import '../dashboard/dashboard_page.dart';
import '../mod_manager/mod_list_page.dart';
import '../player_management/player_list_page.dart';
import '../settings/settings_page.dart';
import '../terminal/terminal_page.dart';
import '../dashboard/server_picker_bar.dart';

/// 主导航壳：底部导航「服务器 · 控制台 · 玩家 · 模组 · 终端 · 我的」（M4）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const _ConsoleTab(),
      const _PlayerTab(),
      const ModListPage(),
      const TerminalPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: '服务器'),
          NavigationDestination(icon: Icon(Icons.terminal_outlined), selectedIcon: Icon(Icons.terminal), label: '控制台'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: '玩家'),
          NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension), label: '模组'),
          NavigationDestination(icon: Icon(Icons.terminal), selectedIcon: Icon(Icons.terminal), label: '终端'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '我的'),
        ],
      ),
    );
  }
}

/// 控制台页签：选中服务器后通过 RconProvider 拿连接。
class _ConsoleTab extends StatelessWidget {
  const _ConsoleTab();

  @override
  Widget build(BuildContext context) {
    final holder = context.watch<SelectedServerHolder>();
    final rcon = context.read<RconProvider>();
    final server = holder.server;
    if (server == null) {
      return const _NeedServerHint();
    }
    return FutureBuilder<RconClient>(
      future: rcon.getClient(server),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('RCON 连接失败：${snap.error}'));
        }
        return ConsolePage(rconClient: snap.data!);
      },
    );
  }
}

/// 玩家页签。
class _PlayerTab extends StatelessWidget {
  const _PlayerTab();

  @override
  Widget build(BuildContext context) {
    final holder = context.watch<SelectedServerHolder>();
    final rcon = context.read<RconProvider>();
    final server = holder.server;
    if (server == null) {
      return const _NeedServerHint();
    }
    return FutureBuilder<RconClient>(
      future: rcon.getClient(server),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('RCON 连接失败：${snap.error}'));
        }
        return PlayerListPage(rconClient: snap.data!);
      },
    );
  }
}

class _NeedServerHint extends StatelessWidget {
  const _NeedServerHint();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('请先在「服务器」页选择一台服务器'));
  }
}
