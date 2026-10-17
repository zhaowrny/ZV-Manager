import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/rcon_client.dart';
import '../../providers/rcon_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../console/console_page.dart';
import '../settings/settings_page.dart';
import 'server_card.dart';
import 'server_form_dialog.dart';

class ServerListPage extends StatefulWidget {
  const ServerListPage({super.key});

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  Timer? _pollTimer;
  final Map<String, ServerStatus> _statusCache = {};
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshAll());
    _refreshAll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final servers = context.read<ServerProvider>().servers;
    await Future.wait(servers.map(_checkStatus));
  }

  /// 查询单台服务器状态。
  ///
  /// 只在「首次查询」时进入 loading 态；后续轮询静默替换结果，
  /// 避免每 5 秒整列表闪一下 loading。
  Future<void> _checkStatus(ServerConfig server) async {
    final id = server.id;
    if (_pending.contains(id)) return;

    // 首次查询才显示 loading；已有结果时静默刷新，不打断阅读
    if (!_statusCache.containsKey(id) && mounted) {
      setState(() => _pending.add(id));
    } else {
      _pending.add(id);
    }

    try {
      final status = await context.read<RconProvider>().checkStatus(server);
      if (!mounted) return;
      setState(() {
        _statusCache[id] = status;
        _pending.remove(id);
      });
    } catch (_) {
      // checkStatus 内部已捕获异常，这里兜底，保证卡片不会永远停在 loading
      if (!mounted) return;
      setState(() {
        _statusCache[id] = ServerStatus(online: false);
        _pending.remove(id);
      });
    }
  }

  /// 打开控制台：已连接直接进入；否则展示「正在连接」，失败则提示连接失败。
  Future<void> _openConsole(ServerConfig server) async {
    final rconProvider = context.read<RconProvider>();

    // 已连接：直接进入
    final existing = rconProvider.clientFor(server.id);
    if (existing != null && existing.isConnected) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConsolePage(rconClient: existing)),
      );
      return;
    }

    // 未连接：展示「正在连接」进度框
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在连接...'),
              ],
            ),
          ),
        ),
      ),
    );

    RconClient? client;
    String? error;
    try {
      client = await rconProvider.getClient(server);
    } catch (e) {
      error = '$e';
    }

    if (!mounted) return;
    Navigator.pop(context); // 关闭进度框

    final enteredClient = client;
    if (enteredClient != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConsolePage(rconClient: enteredClient)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败：$error')),
      );
    }
  }


  /// 计算卡片状态：无缓存且未在请求中 -> loading；有缓存 -> online/offline。
  ServerCardState _cardStateOf(String id, ServerStatus? status) {
    if (_pending.contains(id)) return ServerCardState.loading;
    if (status == null) return ServerCardState.loading;
    return status.online ? ServerCardState.online : ServerCardState.offline;
  }

  Future<void> _addServer() async {
    final server = await showDialog<ServerConfig>(
      context: context,
      builder: (_) => const ServerFormDialog(),
    );
    if (server == null || !mounted) return;
    await context.read<ServerProvider>().addServer(server);
    if (mounted) unawaited(_checkStatus(server));
  }

  Future<void> _editServer(ServerConfig server) async {
    final updated = await showDialog<ServerConfig>(
      context: context,
      builder: (_) => ServerFormDialog(existingServer: server),
    );
    if (updated == null || !mounted) return;
    await context.read<ServerProvider>().updateServer(updated);
    if (mounted) unawaited(_checkStatus(updated));
  }

  Future<void> _deleteServer(ServerConfig server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除服务器「${server.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final rconProvider = context.read<RconProvider>();
    await context.read<ServerProvider>().removeServer(server.id);
    rconProvider.disposeServer(server.id);
  }

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServerProvider>().servers;
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZV Manager'),
        backgroundColor: hasWallpaper ? Colors.transparent : null,
        elevation: hasWallpaper ? 0 : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: servers.isEmpty
          ? _EmptyState(onAdd: _addServer)
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                itemCount: servers.length,
                itemBuilder: (_, i) {
                  final server = servers[i];
                  final status = _statusCache[server.id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ServerCard(
                      // key 绑定服务器 id：增删改后卡片状态不会错位到别的服务器
                      key: ValueKey(server.id),
                      name: server.name,
                      host: server.host,
                      port: server.port,
                      state: _cardStateOf(server.id, status),
                      playerCount: status?.playerCount,
                      latencyMs: status?.latencyMs,
                      tps: status?.tps,
                      onTap: () => _openConsole(server),
                      onEdit: () => _editServer(server),
                      onDelete: () => _deleteServer(server),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addServer,
        icon: const Icon(Icons.add),
        label: const Text('添加服务器'),
      ),
    );
  }
}

/// 空列表引导。
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(Icons.dns_outlined, size: 36, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              '还没有添加服务器',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '填入主机地址与 RCON 密码，即可在手机上管理',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加服务器'),
            ),
          ],
        ),
      ),
    );
  }
}
