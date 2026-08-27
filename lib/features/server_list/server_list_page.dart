import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/rcon_client.dart';
import '../../providers/rcon_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../console/console_page.dart';
import '../settings/settings_page.dart';
import 'server_form_dialog.dart';

class ServerListPage extends StatefulWidget {
  const ServerListPage({super.key});

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  Timer? _pollTimer;
  final Map<String, ServerStatus> _statusCache = {};

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
    for (final server in servers) {
      if (!mounted) return;
      unawaited(_checkStatus(server));
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkStatus(ServerConfig server) async {
    final status = await context.read<RconProvider>().checkStatus(server);
    if (!mounted) return;
    setState(() => _statusCache[server.id] = status);
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

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServerProvider>().servers;
    final theme = Theme.of(context);
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MCServer Manager'),
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
          ? Center(child: Text('暂无服务器，点击 + 添加', style: theme.textTheme.bodyLarge))
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: servers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ServerCard(
                  server: servers[i],
                  status: _statusCache[servers[i].id],
                  onTap: () => _openConsole(servers[i]),
                  onEdit: () async {
                    final updated = await showDialog<ServerConfig>(
                      context: context,
                      builder: (_) => ServerFormDialog(existingServer: servers[i]),
                    );
                    if (updated != null && context.mounted) {
                      await context.read<ServerProvider>().updateServer(updated);
                    }
                  },
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('确定要删除服务器「${servers[i].name}」吗？'),
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
                    if (confirmed == true && context.mounted) {
                      final id = servers[i].id;
                      final rconProvider = context.read<RconProvider>();
                      await context.read<ServerProvider>().removeServer(id);
                      rconProvider.disposeServer(id);
                    }
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final server = await showDialog<ServerConfig>(
            context: context,
            builder: (_) => const ServerFormDialog(),
          );
          if (server != null && context.mounted) {
            await context.read<ServerProvider>().addServer(server);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- 以下内部类保持不变 ---

class _ServerCard extends StatelessWidget {
  final ServerConfig server;
  final ServerStatus? status;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerCard({
    required this.server,
    required this.status,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  /// 根据 TPS 值返回状态颜色：≥16 流畅（绿），≥10 略低（橙），否则卡顿（红）。
  static Color _tpsColor(double tps) {
    if (tps >= 16) return Colors.green;
    if (tps >= 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = status?.online ?? false;

    return Card(
      elevation: isOnline ? 2 : 0.5,
      color: isOnline ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.greenAccent : Colors.redAccent,
                  boxShadow: isOnline
                      ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.4), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${server.host}:${server.port}', style: theme.textTheme.bodySmall),
                    if (isOnline && status != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('${status!.latencyMs}ms',
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.green)),
                          if (status!.tps != null) ...[
                            const SizedBox(width: 8),
                            Text('TPS ${status!.tps!.toStringAsFixed(1)}',
                                style: theme.textTheme.labelSmall?.copyWith(color: _tpsColor(status!.tps!))),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isOnline)
                Chip(
                  label: Text('在线${status?.playerCount ?? 0}人'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else
                Chip(
                  label: const Text('离线'),
                  backgroundColor: theme.colorScheme.errorContainer,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                tooltip: '编辑服务器',
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                tooltip: '删除服务器',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
