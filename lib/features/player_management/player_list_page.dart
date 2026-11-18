import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/rcon_client.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/wallpaper_provider.dart';
import 'player_service.dart';
import '../../core/l10n/strings.dart';

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
          .showSnackBar(SnackBar(content: Text(S.f('{0}：{1}', [actionName, stripMinecraftCodes(result ?? S.t('无响应'))])), duration: const Duration(seconds: 2)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.f('{0}失败：{1}', [actionName, e.toString()])), backgroundColor: Colors.red));
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

  static Map<String, String> get _actionLabels => {
    'op': S.t('给予OP'),
    'deop': S.t('取消OP'),
    'kick': S.t('踢出'),
    'ban': S.t('封禁'),
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
      reason = await _showReasonDialog(_actionLabels[action]!, S.f('{0} 名玩家', [names.length]));
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
      content: Text(S.f('{0}完成：成功 {1} 人', [label, success]) + (fail > 0 ? S.f('，失败 {0} 人', [fail]) : '')),
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
              Text(S.f('将对「{0}」执行该操作', [player])),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: S.t('原因（可选）')),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: T('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: T('确认', style: TextStyle(color: Colors.red)),
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
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        backgroundColor: hasWallpaper ? Colors.transparent : null,
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: S.t('退出选择'),
                onPressed: _exitSelection,
              )
            : null,
        title: Text(_selecting ? S.f('已选 {0} 人', [_selected.length]) : S.t('玩家管理')),
        actions: [
          if (_selecting) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: S.t('全选'),
              onPressed: () {
                setState(() => _selected
                  ..clear()
                  ..addAll((_players ?? []).map((p) => p.name)));
              },
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: S.t('批量操作'),
              onPressed: _loading ? null : _enterSelection,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: S.t('刷新'),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(theme, hasWallpaper),
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
            _buildBatchButton('op', Icons.admin_panel_settings_outlined, S.t('给予OP'), Colors.green),
            _buildBatchButton('deop', Icons.remove_moderator_outlined, S.t('取消OP'), Colors.orange),
            _buildBatchButton('kick', Icons.logout, S.t('踢出'), Colors.blue),
            _buildBatchButton('ban', Icons.block, S.t('封禁'), Colors.red),
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

  Widget _buildBody(ThemeData theme, bool hasWallpaper) {
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: st.subColor),
              const SizedBox(height: 14),
              Text(
                S.f('加载失败：{0}', [_error.toString()]),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: st.subColor),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _load, child: T('重试')),
            ],
          ),
        ),
      );
    }
    final players = _players ?? [];
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 40, color: st.subColor),
            const SizedBox(height: 12),
            Text(S.t('暂无在线玩家'),
                style: TextStyle(fontSize: 13, color: st.subColor)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: T('刷新')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          // 顶部统计条
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 6),
            child: Row(
              children: [
                Text(
                  S.f('在线玩家 {0} 人', [players.length]),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: st.subColor,
                  ),
                ),
                const Spacer(),
                if (_selecting)
                  Text(
                    S.f('已选 {0} 人', [_selected.length]),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kZAccent,
                    ),
                  ),
              ],
            ),
          ),
          // 玩家列表：整块圆角面板，行内用勾选钮表达选中状态
          ZPanel(style: st, children: [
            for (var i = 0; i < players.length; i++) ...[
              if (i > 0) ZDivider(style: st),
              _PlayerRow(
                style: st,
                player: players[i],
                selecting: _selecting,
                selected: _selected.contains(players[i].name),
                onToggle: () => _toggleSelect(players[i].name),
                onAction: (a) => _handleAction(players[i], a),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

/// 单个玩家行：头像/勾选钮 + 名字 + UUID + OP 标记 / 操作菜单。
class _PlayerRow extends StatelessWidget {
  final ZStyle style;
  final PlayerInfo player;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<String> onAction;

  const _PlayerRow({
    required this.style,
    required this.player,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: style.scheme.primary.withOpacity(0.16),
      ),
      alignment: Alignment.center,
      child: Text(
        player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: style.scheme.primary,
        ),
      ),
    );

    return ZRow(
      style: style,
      title: player.name,
      subtitle: player.uuid.isEmpty ? null : player.uuid,
      leading: selecting
          ? ZSwitch(
              value: selected,
              size: 34,
              borderColor: style.subColor,
              onChanged: (_) => onToggle(),
            )
          : avatar,
      onTap: selecting ? onToggle : null,
      trailing: selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.isOp) ...[
                  ZBadge(label: 'OP', color: kZAccent),
                  const SizedBox(width: 2),
                ],
                PopupMenuButton<String>(
                  tooltip: S.t('操作'),
                  icon: Icon(Icons.more_vert,
                      size: 20, color: style.subColor),
                  onSelected: onAction,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'op', child: T('给予 OP')),
                    PopupMenuItem(value: 'deop', child: T('取消 OP')),
                    PopupMenuItem(value: 'kick', child: T('踢出')),
                    PopupMenuItem(value: 'ban', child: T('封禁')),
                  ],
                ),
              ],
            ),
    );
  }
}
