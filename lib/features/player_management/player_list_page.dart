import 'package:flutter/material.dart';
import '../../core/utils/rcon_client.dart';
import 'player_service.dart';

/// 玩家管理页：展示当前在线玩家的完整列表（含 UUID）。
class PlayerListPage extends StatefulWidget {
  final RconClient rconClient;
  const PlayerListPage({super.key, required this.rconClient});

  @override
  State<PlayerListPage> createState() => _PlayerListPageState();
}

class _PlayerListPageState extends State<PlayerListPage> {
  late final PlayerService _service;
  List<PlayerInfo>? _players;
  bool _loading = true;
  String? _error;
  bool _selecting = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _service = PlayerService(widget.rconClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final players = await _service.getOnlinePlayers();
      if (!mounted) return;
      setState(() {
        _players = players;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _performAction(String actionName, Future<String?> Function() action) async {
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$actionName：${stripMinecraftCodes(result ?? '无响应')}'), duration: const Duration(seconds: 2)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$actionName失败：$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleAction(PlayerInfo p, String action) async {
    switch (action) {
      case 'op':
        await _performAction('给予 OP', () => _service.opPlayer(p.name));
      case 'deop':
        await _performAction('取消 OP', () => _service.deopPlayer(p.name));
      case 'kick':
        final kickReason = await _showReasonDialog('踢出', p.name);
        if (kickReason == null) break;
        await _performAction('踢出', () => _service.kickPlayer(p.name, reason: kickReason));
      case 'ban':
        final banReason = await _showReasonDialog('封禁', p.name);
        if (banReason == null) break;
        await _performAction('封禁', () => _service.banPlayer(p.name, reason: banReason));
    }
  }

  /// 进入批量选择模式。
  void _enterSelection() {
    setState(() {
      _selecting = true;
      _selected.clear();
    });
  }

  /// 退出批量选择模式。
  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// 在批量选择模式下勾选/取消某个玩家。
  void _toggleSelect(String name) {
    setState(() {
      if (!_selected.add(name)) _selected.remove(name);
    });
  }

  static const _actionLabels = {
    'op': '给予OP',
    'deop': '取消OP',
    'kick': '踢出',
    'ban': '封禁',
  };

  /// 对选中的所有玩家执行批量操作。
  Future<void> _handleBatch(String action) async {
    final names = (_players ?? [])
        .where((p) => _selected.contains(p.name))
        .map((p) => p.name)
        .toList();
    if (names.isEmpty) return;

    String? reason;
    if (action == 'kick' || action == 'ban') {
      reason = await _showReasonDialog(_actionLabels[action]!, '${names.length}名玩家');
      if (reason == null) return; // 用户取消
    }

    var success = 0;
    var fail = 0;
    for (final name in names) {
      try {
        switch (action) {
          case 'op':
            await _service.opPlayer(name);
          case 'deop':
            await _service.deopPlayer(name);
          case 'kick':
            await _service.kickPlayer(name, reason: reason ?? '');
          case 'ban':
            await _service.banPlayer(name, reason: reason ?? '');
        }
        success++;
      } catch (_) {
        fail++;
      }
    }
    if (!mounted) return;
    final label = _actionLabels[action]!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label完成：成功 $success 人${fail > 0 ? '，失败 $fail 人' : ''}'),
      duration: const Duration(seconds: 2),
    ));
    await _load();
    if (mounted) setState(() => _selected.clear());
  }

  /// 展示操作确认框并允许填写原因，返回原因字符串；取消则返回 null。
  Future<String?> _showReasonDialog(String actionLabel, String player) async {
    final controller = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(actionLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将对「$player」执行该操作'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: '原因（可选）'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      final reason = controller.text.trim();
      return confirmed == true ? reason : null;
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: '退出选择',
                onPressed: _exitSelection,
              )
            : null,
        title: Text(_selecting ? '已选 ${_selected.length} 人' : '玩家管理'),
        actions: [
          if (_selecting) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: '全选',
              onPressed: () {
                setState(() => _selected
                  ..clear()
                  ..addAll((_players ?? []).map((p) => p.name)));
              },
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: '批量操作',
              onPressed: _loading ? null : _enterSelection,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(theme),
      bottomNavigationBar: _selecting ? _buildBatchBar(theme) : null,
    );
  }

  /// 批量操作底部工具栏。
  Widget _buildBatchBar(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBatchButton('op', Icons.admin_panel_settings_outlined, '给予OP', Colors.green),
            _buildBatchButton('deop', Icons.remove_moderator_outlined, '取消OP', Colors.orange),
            _buildBatchButton('kick', Icons.logout, '踢出', Colors.blue),
            _buildBatchButton('ban', Icons.block, '封禁', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchButton(String action, IconData icon, String label, Color color) {
    final disabled = _selected.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          color: disabled ? null : color,
          tooltip: label,
          onPressed: disabled ? null : () => _handleBatch(action),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: disabled ? null : color),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败：$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final players = _players ?? [];
    if (players.isEmpty) {
      return Center(child: Text('暂无在线玩家', style: theme.textTheme.bodyLarge));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = players[i];
          final selected = _selected.contains(p.name);
          return ListTile(
            leading: _selecting
                ? Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSelect(p.name),
                  )
                : CircleAvatar(
                    child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                  ),
            title: Text(p.name, style: theme.textTheme.titleMedium),
            subtitle: p.uuid.isEmpty ? null : Text(p.uuid, style: theme.textTheme.bodySmall),
            selected: selected,
            onTap: _selecting ? () => _toggleSelect(p.name) : null,
            trailing: _selecting
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.isOp)
                        Chip(
                          label: const Text('OP'),
                          visualDensity: VisualDensity.compact,
                        ),
                      PopupMenuButton<String>(
                        tooltip: '操作',
                        onSelected: (action) => _handleAction(p, action),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'op', child: Text('给予 OP')),
                          const PopupMenuItem(value: 'deop', child: Text('取消 OP')),
                          const PopupMenuItem(value: 'kick', child: Text('踢出')),
                          const PopupMenuItem(value: 'ban', child: Text('封禁')),
                        ],
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}