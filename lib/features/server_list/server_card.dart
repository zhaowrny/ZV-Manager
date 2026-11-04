import 'package:flutter/material.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';

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
        return S.t('检测中');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final online = state == ServerCardState.online;

    // 在线态用品牌色描边强调，离线态退成中性描边，避免整屏红框太吵
    final borderColor = online
        ? kZAccent.withOpacity(0.45)
        : scheme.outlineVariant.withOpacity(0.7);

    return Semantics(
      button: true,
      label: '$name，$_statusLabel',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kZRadius),
            color: scheme.surfaceContainerLow,
            border: Border.all(color: borderColor, width: online ? 1.4 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(kZRadius),
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
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        // 状态胶囊（与 ZL2 的标签样式统一）
        ZBadge(
          label: online && latencyMs != null
              ? '$_statusLabel · ${latencyMs}ms'
              : _statusLabel,
          color: _statusColor,
        ),
        _buildMenu(context, scheme),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, ColorScheme scheme) {
    return PopupMenuButton<String>(
      tooltip: S.t('更多操作'),
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
              T('编辑'),
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
              T('删除', style: TextStyle(color: scheme.error)),
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
                  fontSize: 12,
                  letterSpacing: 0.1,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context, ColorScheme scheme) {
    final theme = Theme.of(context);
    final online = state == ServerCardState.online;

    if (state == ServerCardState.loading) {
      return _pillRow(context, [
        _Pill(
          icon: Icons.autorenew_rounded,
          label: S.t('正在获取状态'),
          color: const Color(0xFF94A3B8),
        ),
      ]);
    }

    if (!online) {
      return Row(
        children: [
          Flexible(
            child: _Pill(
              icon: Icons.cloud_off_outlined,
              label: S.t('无法连接'),
              color: const Color(0xFFF87171),
            ),
          ),
          const Spacer(),
          Text(
            S.t('点击重试'),
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
            : S.f('{0} 人', [playerCount ?? 0]),
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
            S.t('进入控制台'),
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
                color: widget.color.withOpacity(glow),
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
        ? color.withOpacity(0.14)
        : color.withOpacity(0.08);

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
