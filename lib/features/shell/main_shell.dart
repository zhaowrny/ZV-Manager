import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../core/utils/rcon_client.dart';
import '../../providers/rcon_provider.dart';
import '../../providers/language_provider.dart';
import '../console/console_page.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/server_picker_bar.dart';
import '../mod_manager/mod_list_page.dart';
import '../player_management/player_list_page.dart';
import '../settings/settings_page.dart';
import '../terminal/terminal_page.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';
import 'pill_nav_bar.dart';

/// 主导航壳：底部悬浮胶囊导航「服务器 · 控制台 · 玩家 · 模组 · 我的」（M4）。
///
/// 「控制台」页签内合并了 RCON 控制台与 SSH 终端，通过页内分段切换。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _selectedIcons = [
    Icons.dns,
    Icons.terminal,
    Icons.group,
    Icons.extension,
    Icons.settings,
  ];

  static const _unselectedIcons = [
    Icons.dns_outlined,
    Icons.terminal_outlined,
    Icons.group_outlined,
    Icons.extension_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final en = context.watch<LanguageProvider>().isEnglish;
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final labels = en
        ? ['Servers', 'Console', 'Players', 'Mods', 'Me']
        : ['服务器', '控制台', '玩家', '模组', '我的'];
    final pages = [
      const DashboardPage(),
      const _ConsoleTab(),
      const _PlayerTab(),
      const ModListPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: PillNavBar(
        selectedIndex: _index,
        labels: labels,
        selectedIcons: _selectedIcons,
        unselectedIcons: _unselectedIcons,
        onSelected: (i) => setState(() => _index = i),
        hasWallpaper: hasWallpaper,
      ),
    );
  }
}

/// 页签通用骨架：带标题 AppBar（无服务器选中时副标题为空）。
class _TabScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final PreferredSizeWidget? bottom;

  const _TabScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: subtitle == null || subtitle!.isEmpty
            ? Text(title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title),
                  Text(subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).hintColor)),
                ],
              ),
        bottom: bottom,
      ),
      body: child,
    );
  }
}

/// 控制台页签：RCON 控制台与 SSH 终端合并为同一个页签。
///
/// 顶部用分段控件切换两种模式；两者用 IndexedStack 保活，
/// 来回切换不会丢失控制台输出或终端会话。
class _ConsoleTab extends StatefulWidget {
  const _ConsoleTab();

  @override
  State<_ConsoleTab> createState() => _ConsoleTabState();
}

class _ConsoleTabState extends State<_ConsoleTab> {
  /// 0 = RCON 控制台，1 = SSH 终端
  int _mode = 0;

  PreferredSizeWidget _switch() => _ConsoleModeSwitch(
        value: _mode,
        onChanged: (v) => setState(() => _mode = v),
      );

  @override
  Widget build(BuildContext context) {
    final holder = context.watch<SelectedServerHolder>();
    final rcon = context.read<RconProvider>();
    final server = holder.server;

    Widget consoleTab;
    if (server == null) {
      consoleTab = _TabScaffold(
        title: S.t('控制台'),
        bottom: _switch(),
        child: const _NeedServerHint(),
      );
    } else {
      consoleTab = FutureBuilder<RconClient>(
        future: rcon.getClient(server),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _TabScaffold(
              title: S.t('控制台'),
              subtitle: server.name,
              bottom: _switch(),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _TabScaffold(
              title: S.t('控制台'),
              subtitle: server.name,
              bottom: _switch(),
              child: Center(
                  child: Text(S.f('RCON 连接失败：{0}', [snap.error.toString()]))),
            );
          }
          return ConsolePage(rconClient: snap.data!, bottom: _switch());
        },
      );
    }

    return IndexedStack(
      index: _mode,
      children: [
        consoleTab,
        TerminalPage(bottom: _switch()),
      ],
    );
  }
}

/// 「控制台 / 终端」分段切换条，放在 AppBar 的 bottom 槽位。
class _ConsoleModeSwitch extends StatelessWidget
    implements PreferredSizeWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ConsoleModeSwitch({required this.value, required this.onChanged});

  static const double _height = 52;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Center(
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: T('控制台')),
            ButtonSegment(value: 1, label: T('终端')),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
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
      return _TabScaffold(title: S.t('玩家'), child: const _NeedServerHint());
    }
    return FutureBuilder<RconClient>(
      future: rcon.getClient(server),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _TabScaffold(
            title: S.t('玩家'),
            subtitle: server.name,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _TabScaffold(
            title: S.t('玩家'),
            subtitle: server.name,
            child: Center(
                child: Text(S.f('RCON 连接失败：{0}', [snap.error.toString()]))),
          );
        }
        return PlayerListPage(rconClient: snap.data!); // 自带 AppBar
      },
    );
  }
}

class _NeedServerHint extends StatelessWidget {
  const _NeedServerHint();

  @override
  Widget build(BuildContext context) {
    return const Center(child: T('请先在「服务器」页选择一台服务器'));
  }
}
