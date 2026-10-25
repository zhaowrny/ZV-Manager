import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../app.dart' show navigatorKey;
import '../../core/theme/app_theme.dart';
import '../../providers/rcon_provider.dart';
import '../../providers/server_provider.dart';
import '../server_list/server_form_dialog.dart';
import '../download/download_page.dart';
import '../mod_manager/mod_list_page.dart';
import '../terminal/terminal_page.dart';
import 'server_picker_bar.dart';
import '../../core/l10n/strings.dart';

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

  /// 添加服务器：弹出服务器表单，保存后自动选中。
  Future<void> _addServer() async {
    // 在 await 前捕获 Provider，避免跨 async 使用 BuildContext
    final serverProvider = context.read<ServerProvider>();
    final holder = context.read<SelectedServerHolder>();
    final server = await showDialog<ServerConfig>(
      context: context,
      builder: (_) => const ServerFormDialog(),
    );
    if (server == null || !mounted) return;
    await serverProvider.addServer(server);
    holder.select(server);
    _refreshAll();
  }

  /// 服务器卡片菜单：编辑 / 删除。
  Future<void> _onServerAction(BuildContext context, ServerConfig s, String action) async {
    final serverProvider = context.read<ServerProvider>();
    final rconProvider = context.read<RconProvider>();
    final holder = context.read<SelectedServerHolder>();
    if (action == 'edit') {
      final updated = await showDialog<ServerConfig>(
        context: context,
        builder: (_) => ServerFormDialog(existingServer: s),
      );
      if (updated == null || !mounted) return;
      await serverProvider.updateServer(updated);
      // 若编辑的是当前选中服务器，刷新选中引用
      if (holder.server?.id == updated.id) holder.select(updated);
      _refreshAll();
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: T('删除服务器'),
          content: Text(S.f('确定要删除「{0}」吗？仅删除本应用中的连接配置，不影响服务器本身。', [s.name])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: T('取消')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: T('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await serverProvider.removeServer(s.id);
      rconProvider.disposeServer(s.id);
      if (holder.server?.id == s.id) holder.select(null);
      setState(() => _status.remove(s.id));
    }
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
            Expanded(child: Text(S.f('服务器「{0}」已断开连接！', [serverName]))),
          ],
        ),
        action: SnackBarAction(
          label: S.t('知道了'),
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
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final status = selected != null ? _status[selected.id] : null;

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: AppBar(
        title: const Text('ZV Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: S.t('刷新状态'),
            onPressed: _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: S.t('添加服务器'),
            onPressed: _addServer,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addServer,
        tooltip: S.t('添加服务器'),
        child: const Icon(Icons.add),
      ),
      body: servers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  T('还没有服务器，点击下方按钮添加吧'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: T('添加服务器'),
                    onPressed: _addServer,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // 服务器选择器
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.dns),
                    title: Text(selected?.name ?? '未选择'),
                    subtitle: Text('${selected?.host ?? '-'}:${selected?.port ?? '-'}'),
                    trailing: DropdownButton<ServerConfig>(
                      underline: const SizedBox.shrink(),
                      hint: T('切换'),
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
                  childAspectRatio: 1.9,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
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
                      label: S.t('在线人数'),
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
                      label: S.t('磁盘'),
                      sub: '需 SSH 终端',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 服务器卡片列表（点击选中）
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: T('服务器', style: Theme.of(context).textTheme.titleMedium),
                ),
                ...servers.map((s) {
                  final st = _status[s.id];
                  final isSel = selected?.id == s.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      side: isSel
                          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6)
                          : BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.06)),
                    ),
                    color: isSel
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                        : null,
                    child: ListTile(
                      selected: isSel,
                      selectedTileColor: Colors.transparent,
                      leading: Icon(
                        st?.online == true ? Icons.circle : Icons.circle_outlined,
                        color: st?.online == true ? Colors.green : Colors.red,
                      ),
                      title: Text(s.name),
                      subtitle: Text(
                        st?.online == true
                            ? S.f('在线 · {0}ms · {1} 人', [st!.latencyMs, st.playerCount]) + (st.tps != null ? ' · TPS ${st.tps!.toStringAsFixed(1)}' : '')
                            : S.t('离线'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSel) const Icon(Icons.check, color: Colors.green),
                          PopupMenuButton<String>(
                            onSelected: (a) => _onServerAction(context, s, a),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: T('编辑')),
                              PopupMenuItem(value: 'delete', child: T('删除')),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        holder.select(s);
                        setState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
                // 快捷入口
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: T('快捷入口', style: Theme.of(context).textTheme.titleMedium),
                ),
                Row(
                  children: [
                    _quickEntry(
                      icon: Icons.download_outlined,
                      color: Colors.blue,
                      label: S.t('下载中心'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DownloadPage()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _quickEntry(
                      icon: Icons.terminal,
                      color: Colors.deepOrange,
                      label: S.t('远程终端'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TerminalPage()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _quickEntry(
                      icon: Icons.extension_outlined,
                      color: Colors.purple,
                      label: S.t('模组管理'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ModListPage()),
                      ),
                    ),
                  ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sub,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF222222),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 快捷入口：彩色图标 + 标题的方块按钮。
  Widget _quickEntry({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B1E24)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
