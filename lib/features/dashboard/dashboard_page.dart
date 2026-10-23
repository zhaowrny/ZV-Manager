import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart' show navigatorKey;
import '../../providers/rcon_provider.dart';
import '../../providers/server_provider.dart';
import '../download/download_page.dart';
import '../mod_manager/mod_list_page.dart';
import '../terminal/terminal_page.dart';
import 'server_picker_bar.dart';

/// 服务器 Dashboard：卡片式布局展示选中服务器的
/// 在线状态 / 延迟 / 在线人数 / TPS / 磁盘（后续 Shell 采集）+ 快捷入口（M4）。
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, ServerStatus> _status = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    // 每 5 秒轮询一次，用于断线提醒
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshAll(alertOnDrop: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll({bool alertOnDrop = false}) async {
    final rcon = context.read<RconProvider>();
    final servers = context.read<ServerProvider>().servers;
    final map = <String, ServerStatus>{};
    for (final s in servers) {
      map[s.id] = await rcon.checkStatus(s);
      if (!mounted) return;
    }
    // 断线检测：上一轮在线、这一轮离线 → 弹出提醒
    if (alertOnDrop) {
      for (final s in servers) {
        final prev = _status[s.id];
        final now = map[s.id];
        if ((prev?.online ?? false) && !(now?.online ?? false)) {
          _showDisconnectAlert(s.name);
        }
      }
    }
    if (!mounted) return;
    setState(() => _status = map);
  }

  /// 断线提醒：页面内 SnackBar + 顶部全局提示。
  void _showDisconnectAlert(String serverName) {
    final nav = navigatorKey.currentContext;
    if (nav == null) return;
    final messenger = ScaffoldMessenger.maybeOf(nav);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.red.shade700,
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('⚠️ 服务器「$serverName」已断开连接！')),
          ],
        ),
        action: SnackBarAction(
          label: '知道了',
          textColor: Colors.white,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServerProvider>().servers;
    final holder = context.watch<SelectedServerHolder>();
    final selected = holder.server ?? (servers.isNotEmpty ? servers.first : null);
    final status = selected != null ? _status[selected.id] : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ZV Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新状态',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: servers.isEmpty
          ? const Center(child: Text('还没有服务器，去「服务器」页添加吧'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 服务器选择器
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.dns),
                    title: Text(selected?.name ?? '未选择'),
                    subtitle: Text('${selected?.host ?? '-'}:${selected?.port ?? '-'}'),
                    trailing: DropdownButton<ServerConfig>(
                      underline: const SizedBox.shrink(),
                      hint: const Text('切换'),
                      items: servers
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                          .toList(),
                      onChanged: (s) {
                        holder.select(s);
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 状态卡片
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _statusCard(
                      icon: status?.online == true ? Icons.circle : Icons.circle_outlined,
                      color: status?.online == true ? Colors.green : Colors.red,
                      label: status?.online == true ? '在线' : '离线',
                      sub: status == null ? '—' : '${status.latencyMs}ms',
                    ),
                    _statusCard(
                      icon: Icons.person,
                      color: Colors.blue,
                      label: '在线人数',
                      sub: '${status?.playerCount ?? 0}',
                    ),
                    _statusCard(
                      icon: Icons.speed,
                      color: Colors.orange,
                      label: 'TPS',
                      sub: status?.tps?.toStringAsFixed(1) ?? '—',
                    ),
                    _statusCard(
                      icon: Icons.storage,
                      color: Colors.purple,
                      label: '磁盘',
                      sub: '需 SSH 终端',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 服务器卡片列表（点击选中）
                Text('服务器', style: Theme.of(context).textTheme.titleMedium),
                ...servers.map((s) {
                  final st = _status[s.id];
                  final isSel = selected?.id == s.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      selected: isSel,
                      leading: Icon(
                        st?.online == true ? Icons.circle : Icons.circle_outlined,
                        color: st?.online == true ? Colors.green : Colors.red,
                      ),
                      title: Text(s.name),
                      subtitle: Text(
                        st?.online == true
                            ? '在线 · ${st!.latencyMs}ms · ${st.playerCount} 人'
                                '${st.tps != null ? " · TPS ${st.tps!.toStringAsFixed(1)}" : ""}'
                            : '离线',
                      ),
                      trailing: isSel ? const Icon(Icons.check) : null,
                      onTap: () {
                        holder.select(s);
                        setState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
                // 快捷入口
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download_outlined),
                        title: const Text('下载中心'),
                        subtitle: const Text('Modrinth 搜索 · 镜像加速'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DownloadPage()),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.terminal),
                        title: const Text('远程终端'),
                        subtitle: const Text('SSH Shell'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TerminalPage()),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.extension_outlined),
                        title: const Text('模组管理'),
                        subtitle: const Text('上传 / 删除 / 查看依赖'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModListPage()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ]),
            const SizedBox(height: 6),
            Text(sub, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
