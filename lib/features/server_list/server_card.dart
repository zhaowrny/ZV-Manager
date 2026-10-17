import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// 服务器卡片的数据状态。
enum ServerCardState {
  /// 尚未完成首次探测。
  loading,

  /// 在线。
  online,

  /// 离线（不可达或鉴权失败）。
  offline,
}

/// 卡片式服务器列表项。
///
/// 设计要点：
/// - 固定高度，横向排版，信息分三层：标题 / 地址 / 指标；
/// - 在线态用品牌色描边 + 柔和高光，离线态降饱和但仍保持可读；
/// - 操作（编辑 / 删除）收进 `PopupMenuButton`，避免两个 IconButton
///   在窄屏上挤压内容（原实现小屏下地址会被大面积截断）。
class ServerCard extends StatelessWidget {
  final String name;
  final String host;
  final int port;
  final ServerCardState state;
  final int? playerCount;
  final int? maxPlayers;
  final int? latencyMs;
  final double? tps;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ServerCard({
    super.key,
    required this.name,
    required this.host,
    required this.port,
    required this.state,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.playerCount,
    this.maxPlayers,
    this.latencyMs,
    this.tps,
  });

  static const double _radius = 20;

  /// TPS 分档着色：≥16 流畅，≥10 偏低，否则卡顿。
  static Color tpsColor(double tps) {
    if (tps >= 16) return const Color(0xFF34D399);
    if (tps >= 10) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  Color get _statusColor {
    switch (state) {
      case ServerCardState.online:
        return const Color(0xFF34D399);
      case ServerCardState.offline:
        return const Color(0xFFF87171);
      case ServerCardState.loading:
        return const Color(0xFF94A3B8);
    }
  }

  String get _statusLabel {
    switch (state) {
      case ServerCardState.online:
        return '在线';
      case ServerCardState.offline:
        return '离线';
      case ServerCardState.loading:
        return '检测中';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final online = state == ServerCardState.online;

    // 卡片底色跟随主题表面色，浮一层极淡的品牌色，避免纯白/纯黑显得生硬。
    final Color base = Color.alphaBlend(
      scheme.primary.withValues(alpha: online ? 0.06 : 0.02),
      scheme.surface,
    );

    return Semantics(
      button: true,
      label: '$name，$_statusLabel',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            color: base,
            border: Border.all(
              color: online
                  ? scheme.primary.withValues(alpha: 0.38)
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              width: online ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: online ? 0.08 : 0.04),
                blurRadius: online ? 18 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, scheme, online),
                  const SizedBox(height: 10),
                  _buildAddress(context, scheme),
                  const SizedBox(height: 12),
                  _buildMetrics(context, scheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme, bool online) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _StatusDot(color: _statusColor, pulsing: online),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        // 状态胶囊
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _statusColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (online && latencyMs != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${latencyMs}ms',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _statusColor.withValues(alpha: 0.75),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildMenu(context, scheme),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, ColorScheme scheme) {
    return PopupMenuButton<String>(
      tooltip: '更多操作',
      icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          height: 44,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 19),
              SizedBox(width: 12),
              Text('编辑'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 44,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 19, color: scheme.error),
              const SizedBox(width: 12),
              Text('删除', style: TextStyle(color: scheme.error)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
    );
  }

  Widget _buildAddress(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        Icon(Icons.dns_outlined, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$host:$port',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context, ColorScheme scheme) {
    final online = state == ServerCardState.online;

    if (state == ServerCardState.loading) {
      return _pillRow(context, [
        const _Pill(
          icon: Icons.autorenew_rounded,
          label: '正在获取状态',
          color: Color(0xFF94A3B8),
        ),
      ]);
    }

    if (!online) {
      return Row(
        children: [
          const Flexible(
            child: _Pill(
              icon: Icons.cloud_off_outlined,
              label: '无法连接',
              color: Color(0xFFF87171),
            ),
          ),
          const Spacer(),
          Text(
            '点击重试',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.refresh_rounded, size: 15, color: scheme.onSurfaceVariant),
        ],
      );
    }

    final pills = <Widget>[
      _Pill(
        icon: Icons.people_alt_outlined,
        label: maxPlayers != null
            ? '${playerCount ?? 0}/$maxPlayers'
            : '${playerCount ?? 0} 人',
        color: scheme.primary,
        emphasized: true,
      ),
    ];

    final tpsValue = tps;
    if (tpsValue != null) {
      pills.add(_Pill(
        icon: Icons.speed_rounded,
        label: 'TPS ${tpsValue.toStringAsFixed(1)}',
        color: tpsColor(tpsValue),
      ));
    }

    return _pillRow(
      context,
      pills,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '进入控制台',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: scheme.primary),
        ],
      ),
    );
  }

  Widget _pillRow(BuildContext context, List<Widget> pills, {Widget? trailing}) {
    return Row(
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Flexible(child: pills[i]),
        ],
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }
}

/// 状态圆点：在线时带柔和呼吸光晕。
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _StatusDot({required this.color, required this.pulsing});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulsing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final glow = widget.pulsing ? 0.18 + 0.16 * _ctrl.value : 0.0;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glow),
                blurRadius: 10,
                spreadRadius: 3,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 指标胶囊。
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = emphasized
        ? color.withValues(alpha: 0.14)
        : color.withValues(alpha: 0.08);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );

    return content;
  }
}
