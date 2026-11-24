import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../../core/widgets/z_widgets.dart';

/// 悬浮胶囊底部导航。
///
/// 整条是带阴影的圆角胶囊，选中项展开为主色胶囊并淡入文字，其余项只留图标。
/// 无壁纸走主题色；有壁纸/液态玻璃时半透明深底 + 白色内容，保持沉浸感。
class PillNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final List<IconData> selectedIcons;
  final List<IconData> unselectedIcons;
  final ValueChanged<int> onSelected;
  final bool hasWallpaper;

  const PillNavBar({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.selectedIcons,
    required this.unselectedIcons,
    required this.onSelected,
    required this.hasWallpaper,
  });

  // 基准尺寸；窄屏/分屏时统一乘以缩放系数，避免页签溢出。
  static const _iconSize = 22.0;
  static const _gap = 6.0;
  static const _fontSize = 12.5;
  static const _padIdle = 6.0;
  static const _padActive = 12.0;
  static const _innerPad = 6.0;
  static const _height = 64.0;
  static const _itemHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color pillColor;
    final Color activeBg;
    final Color activeFg;
    final Color idleFg;
    if (hasWallpaper) {
      pillColor = Colors.black.withOpacity(kZGlass ? 0.30 : 0.38);
      activeBg = Colors.white.withOpacity(0.20);
      activeFg = Colors.white;
      idleFg = Colors.white.withOpacity(0.62);
    } else if (kZGlass) {
      pillColor = scheme.surface.withOpacity(0.62);
      activeBg = kZAccent.withOpacity(0.16);
      activeFg = scheme.onSurface;
      idleFg = scheme.onSurfaceVariant;
    } else {
      pillColor = scheme.surfaceContainerHighest;
      activeBg = scheme.primary;
      activeFg = scheme.onPrimary;
      idleFg = scheme.onSurfaceVariant;
    }

    final radius = BorderRadius.circular(_height / 2);
    final hPad = MediaQuery.sizeOf(context).width < 380 ? 12.0 : 16.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale =
                    _navScaleFor(context, labels, constraints.maxWidth);
                final items = SizedBox(
                  height: _height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _innerPad),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          _NavPillItem(
                            icon: selectedIndex == i
                                ? selectedIcons[i]
                                : unselectedIcons[i],
                            label: labels[i],
                            selected: selectedIndex == i,
                            scale: scale,
                            activeBg: activeBg,
                            activeFg: activeFg,
                            idleFg: idleFg,
                            onTap: () => onSelected(i),
                          ),
                      ],
                    ),
                  ),
                );
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          hasWallpaper ? 0.22 : (isDark ? 0.38 : 0.14),
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: kZGlass
                        ? BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: kZGlassBlur,
                              sigmaY: kZGlassBlur,
                            ),
                            child: ColoredBox(color: pillColor, child: items),
                          )
                        : ColoredBox(color: pillColor, child: items),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 计算统一缩放系数：把「未选中图标项 + 选中展开项」的自然宽度
  /// 与胶囊可用宽度比较，超出时整体等比收缩。
  double _navScaleFor(
      BuildContext context, List<String> labels, double available) {
    const style = TextStyle(
      fontSize: _fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var total = 0.0;
    for (var i = 0; i < labels.length; i++) {
      total += _iconSize + _padIdle * 2;
      if (i == selectedIndex) {
        final painter = TextPainter(
          text: TextSpan(text: labels[i], style: style),
          maxLines: 1,
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        total += (_padActive - _padIdle) * 2 + _gap + painter.width;
        painter.dispose();
      }
    }
    final inner = available - _innerPad * 2;
    if (total <= inner || total <= 0) return 1;
    return (inner / total).clamp(0.0, 1.0);
  }
}

/// 单个导航项：选中时胶囊底色 + 图标 + 淡入并水平展开的文字，未选中只留图标。
class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final double scale;
  final Color activeBg;
  final Color activeFg;
  final Color idleFg;
  final VoidCallback onTap;

  const _NavPillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.scale,
    required this.activeBg,
    required this.activeFg,
    required this.idleFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: selected ? 1.0 : 0.0,
          end: selected ? 1.0 : 0.0,
        ),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          final fg = Color.lerp(idleFg, activeFg, t)!;
          final bg = Color.lerp(Colors.transparent, activeBg, t)!;
          return Material(
            color: bg,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: SizedBox(
                height: PillNavBar._itemHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: lerpDouble(
                          PillNavBar._padIdle,
                          PillNavBar._padActive,
                          t,
                        )! *
                        scale,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: PillNavBar._iconSize * scale,
                        color: fg,
                      ),
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: t,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: PillNavBar._gap * scale,
                            ),
                            child: Opacity(
                              opacity: t,
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontSize: PillNavBar._fontSize * scale,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
