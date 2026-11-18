import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../app.dart' show navigatorKey;
import '../../providers/rcon_provider.dart';
import '../../providers/server_provider.dart';
import '../server_list/server_form_dialog.dart';
import '../download/download_page.dart';
import '../mod_manager/mod_list_page.dart';
import '../terminal/terminal_page.dart';
import 'server_picker_bar.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';

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

  /// 刷新所有服务器的在线状态。
  ///
  /// 串行逐个查询（而非并发），避免同时向多台服务器发起 RCON 握手；
  /// [alertOnDrop] 为 true 时（即定时轮询），会对比上一轮状态，
  /// 发现"由在线转为离线"就弹提醒——这是最核心的告警能力。
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
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: const Text('ZV Manager'),
        backgroundColor: hasWallpaper ? Colors.transparent : null,
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
      floatingActionButton: servers.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _addServer,
              tooltip: S.t('添加服务器'),
              child: const Icon(Icons.add),
            ),
      body: servers.isEmpty
          ? _EmptyDashboard(onAdd: _addServer, style: st)
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                children: [
                  // ---------- 当前服务器 ----------
                  if (selected != null)
                    _CurrentServerPanel(
                      server: selected,
                      status: status,
                      servers: servers,
                      style: st,
                      onSelect: (s) {
                        holder.select(s);
                        setState(() {});
                      },
                    ),
                  const SizedBox(height: 16),
                  _label(S.t('运行状态'), st),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.95,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      _statusTile(
                        style: st,
                        icon: status?.online == true
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        color: status?.online == true
                            ? kZAccent
                            : const Color(0xFFEF5350),
                        label: status?.online == true ? '在线' : '离线',
                        sub: status == null ? '—' : '${status.latencyMs}ms',
                      ),
                      _statusTile(
                        style: st,
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF42A5F5),
                        label: S.t('在线人数'),
                        sub: '${status?.playerCount ?? 0}',
                      ),
                      _statusTile(
                        style: st,
                        icon: Icons.speed_rounded,
                        color: const Color(0xFFFFA726),
                        label: 'TPS',
                        sub: status?.tps?.toStringAsFixed(1) ?? '—',
                      ),
                      _statusTile(
                        style: st,
                        icon: Icons.storage_rounded,
                        color: const Color(0xFFAB47BC),
                        label: S.t('磁盘'),
                        sub: S.t('需 SSH 终端'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _label(S.t('服务器'), st),
                  ZPanel(style: st, children: [
                    for (var i = 0; i < servers.length; i++) ...[
                      if (i > 0) ZDivider(style: st),
                      _serverRow(servers[i], selected, st),
                    ],
                  ]),
                  const SizedBox(height: 20),
                  _label(S.t('快捷入口'), st),
                  ZPanel(style: st, children: [
                    ZRow(
                      title: '下载中心',
                      subtitle: '搜索 Modrinth 模组，镜像加速下载',
                      style: st,
                      leading: _entryIcon(Icons.download_rounded,
                          const Color(0xFF42A5F5)),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DownloadPage())),
                    ),
                    ZDivider(style: st),
                    ZRow(
                      title: '远程终端',
                      subtitle: '通过 SSH 执行任意命令',
                      style: st,
                      leading: _entryIcon(
                          Icons.terminal_rounded, const Color(0xFFFF7043)),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TerminalPage())),
                    ),
                    ZDivider(style: st),
                    ZRow(
                      title: '模组管理',
                      subtitle: '上传、删除、查看依赖',
                      style: st,
                      leading: _entryIcon(
                          Icons.extension_rounded, const Color(0xFFAB47BC)),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ModListPage())),
                    ),
                  ]),
                ],
              ),
            ),
    );
  }

  /// 面板外的小分组标题。
  Widget _label(String text, ZStyle st) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: st.subColor,
        ),
      ),
    );
  }

  /// 快捷入口左侧的圆角图标块。
  Widget _entryIcon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  /// 服务器列表行（点击切换当前服务器，右侧菜单可编辑/删除）。
  Widget _serverRow(ServerConfig s, ServerConfig? selected, ZStyle st) {
    final online = _status[s.id]?.online == true;
    final isSel = selected?.id == s.id;
    final dotColor = online ? kZAccent : const Color(0xFFEF5350);
    return ZRow(
      style: st,
      title: s.name,
      subtitle: '${s.host}:${s.port}',
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dotColor.withOpacity(0.16),
        ),
        child: Icon(Icons.dns_rounded, size: 17, color: dotColor),
      ),
      onTap: () => context.read<SelectedServerHolder>().select(s),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSel) ...[
            ZBadge(label: S.t('当前'), color: kZAccent),
            const SizedBox(width: 2),
          ],
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: st.subColor),
            tooltip: S.t('更多操作'),
            onSelected: (a) => _onServerAction(context, s, a),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: T('编辑')),
              PopupMenuItem(value: 'delete', child: T('删除')),
            ],
          ),
        ],
      ),
    );
  }

  /// 顶部「当前服务器」面板：名称 + 地址 + 运行指标 + 切换入口。
  Widget _statusTile({
    required ZStyle style,
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: style.panelColor,
        borderRadius: BorderRadius.circular(kZRadius),
        border: Border.all(color: style.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: style.subColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              sub,
              maxLines: 1,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: style.titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前服务器概览面板：名称/地址/状态 + 切换下拉。
class _CurrentServerPanel extends StatelessWidget {
  final ServerConfig server;
  final ServerStatus? status;
  final List<ServerConfig> servers;
  final ZStyle style;
  final ValueChanged<ServerConfig> onSelect;

  const _CurrentServerPanel({
    required this.server,
    required this.status,
    required this.servers,
    required this.style,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final online = status?.online == true;
    final color = online ? kZAccent : const Color(0xFFEF5350);
    return ZPanel(style: style, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.dns_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: style.titleColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${server.host}:${server.port}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: style.subColor),
                  ),
                ],
              ),
            ),
            if (servers.length > 1)
              PopupMenuButton<ServerConfig>(
                tooltip: S.t('切换'),
                icon: Icon(Icons.swap_horiz_rounded,
                    size: 20, color: style.subColor),
                onSelected: onSelect,
                itemBuilder: (_) => [
                  for (final s in servers)
                    PopupMenuItem(
                      value: s,
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontWeight:
                              s.id == server.id ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                ],
              ),
            ZBadge(label: online ? S.t('在线') : S.t('离线'), color: color),
          ],
        ),
      ),
    ]);
  }
}

/// 无服务器时的引导页。
class _EmptyDashboard extends StatelessWidget {
  final VoidCallback onAdd;
  final ZStyle style;
  const _EmptyDashboard({required this.onAdd, required this.style});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: kZAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(Icons.dns_rounded, size: 38, color: kZAccent),
            ),
            const SizedBox(height: 18),
            Text(
              S.t('还没有添加服务器'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: style.titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.t('填入主机地址与 RCON 密码，即可在手机上管理'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: style.subColor),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: T('添加服务器'),
            ),
          ],
        ),
      ),
    );
  }
}
