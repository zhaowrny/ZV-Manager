import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../../providers/wallpaper_provider.dart';

/// ZL2 风格的通用视觉组件集合。
///
/// 设计要点（与 ZalithLauncher 保持一致的观感）：
/// - **分组圆角面板**：一组相关设置包在 18px 圆角容器里，行与行之间用极细
///   分隔线，而不是每行一张 Card。这样竖屏下信息密度更高、层级更清晰。
/// - **两行行样式**：左侧「粗标题 + 小字灰色说明」，右侧「当前值 / 控件 / 箭头」。
///   说明文字用较小字号 + 降低不透明度，形成明确的视觉主次。
/// - **圆形勾选钮**：开关不用 Material Switch，而用 46px 圆形按钮，
///   选中时绿底白勾（ZL2 的标志性元素）。
///
/// 所有组件都接受 [hasWallpaper]，在有自定义壁纸时自动切换为半透明深色
/// 浮层 + 白色文字，保证文字在任意背景下都能读清。

/// 全站强调色：开关/选中态/徽章统一使用。
/// 由 ThemeProvider 在切换主题配色时同步赋值，所有引用点自动跟随，无需逐处传参。
Color kZAccent = const Color(0xFF4CAF50);

/// ZL2 圆角：分组面板与内部行的圆角。
const double kZRadius = 18.0;

/// 分组面板的着色与文字色工具。
///
/// 把「有壁纸 / 无壁纸」两套配色集中在这里，避免每个页面各写一遍
/// `Colors.black.withOpacity(0.45)` 之类的魔数。
class ZStyle {
  final bool hasWallpaper;
  final ColorScheme scheme;

  const ZStyle({required this.hasWallpaper, required this.scheme});

  /// 从 BuildContext 推导（需要外部传入 hasWallpaper）。
  factory ZStyle.of(BuildContext context, {required bool hasWallpaper}) =>
      ZStyle(hasWallpaper: hasWallpaper, scheme: Theme.of(context).colorScheme);

  /// 面板底色：有壁纸时半透明黑浮层，否则用主题的低层容器色。
  Color get panelColor =>
      hasWallpaper ? Colors.black.withOpacity(0.45) : scheme.surfaceContainerLow;

  /// 主文字色。
  Color get titleColor => hasWallpaper ? Colors.white : scheme.onSurface;

  /// 次要说明文字色。
  Color get subColor =>
      hasWallpaper ? Colors.white.withOpacity(0.62) : scheme.onSurfaceVariant;

  /// 分隔线色。
  Color get dividerColor =>
      hasWallpaper ? Colors.white.withOpacity(0.10) : scheme.outlineVariant;

  /// 面板描边色（浅色主题下几乎不可见，仅用于在深色壁纸上勾出边界）。
  Color get borderColor => Colors.white.withOpacity(0.08);
}

/// 分组面板：圆角容器 + 子行纵向排列。
///
/// 用法：把若干 [ZRow] 之间用 [ZDivider] 隔开后放进 children。
class ZPanel extends StatelessWidget {
  final List<Widget> children;
  final ZStyle style;

  const ZPanel({super.key, required this.style, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: style.panelColor,
        borderRadius: BorderRadius.circular(kZRadius),
        border: Border.all(color: style.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// 面板内的行分隔线（左右各留 16 的缩进）。
class ZDivider extends StatelessWidget {
  final ZStyle style;
  const ZDivider({super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 1, color: style.dividerColor),
    );
  }
}

/// 两行式设置行：粗标题 + 灰色说明 + 右侧值/控件/箭头。
///
/// - [onTap] 为空时整行不可点击（纯展示行），也不显示右侧箭头；
/// - [trailing] 与 [value] 可同时存在；都没有且 [onTap] 不为空时显示 chevron。
/// - [leading] 可选，用于在标题左侧放一个小图标（如日志文件行）。
class ZRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ZStyle style;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;

  /// 标题用主题色的强调样式（如危险操作变红）。
  final Color? titleOverride;

  const ZRow({
    super.key,
    required this.title,
    required this.style,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.titleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final showChevron = trailing == null && onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kZRadius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.t(title),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: titleOverride ?? style.titleColor,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      S.t(subtitle!),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: style.subColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: style.subColor),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ] else if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: style.subColor),
            ],
          ],
        ),
      ),
    );
  }
}

/// ZL2 式圆形勾选开关：选中为绿底白勾，未选中为描边空心圆。
/// 胶囊开关：关闭时灰色轨道 + 白色圆滑块，开启时轨道变为当前主题强调色。
///
/// 参数与原 ZToggle 兼容（[size] 作为轨道高度基准、[borderColor] 作为关闭态
/// 轨道色），便于全站平滑替换。[enabled] 为 false 时置灰且不可点击，用于
/// 「跟随系统」开启时联动禁用「深色模式」。
class ZSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;
  final Color? borderColor;
  final bool enabled;

  const ZSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 46,
    this.borderColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final trackH = (size * 0.7).clamp(22.0, 32.0).toDouble();
    final trackW = trackH * 1.7;
    final thumb = trackH - 6.0;
    final offTrack = (borderColor ??
            Theme.of(context).colorScheme.outlineVariant)
        .withOpacity(0.32);
    final onTrack = enabled ? kZAccent : kZAccent.withOpacity(0.4);

    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: trackW,
        height: trackH,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(trackH / 2),
          color: value ? onTrack : offTrack,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆形打勾标记：选中为实心圆底白勾，未选中为描边空心圆。
///
/// 与 [ZSwitch] 的滑块开关不同，它表达「选中 / 未选中」的标记语义，
/// 适用于二值状态、单选列表与多选列表。参数与 [ZSwitch] 兼容，
/// 便于直接替换；[enabled] 为 false 时置灰且不响应点击。
class ZCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final Color? borderColor;
  final bool enabled;

  const ZCheck({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 26,
    this.borderColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dim = (borderColor ??
            Theme.of(context).colorScheme.outlineVariant)
        .withOpacity(0.55);
    final accent = enabled ? kZAccent : kZAccent.withOpacity(0.4);
    return GestureDetector(
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? accent : Colors.transparent,
          border: Border.all(color: value ? accent : dim, width: 2),
        ),
        child: value
            ? Icon(Icons.check, size: size * 0.62, color: Colors.white)
            : null,
      ),
    );
  }
}

/// 圆形选择钮组：一组互斥选项，选中项显示绿底白勾，未选中显示图标。
///
/// 用于「亮色 / 暗色 / 跟随系统」这类三选一，也可复用到镜像线路等单选场景。
class ZSegmentedCircles<T> extends StatelessWidget {
  final List<ZCircleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color onSurface;
  final double size;

  const ZSegmentedCircles({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.onSurface,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onChanged(o.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value == o.value ? kZAccent : Colors.transparent,
                border: Border.all(
                  color: value == o.value
                      ? kZAccent
                      : onSurface.withOpacity(0.35),
                  width: 2,
                ),
              ),
              child: Icon(
                value == o.value ? Icons.check : o.icon,
                size: size * 0.53,
                color: value == o.value
                    ? Colors.white
                    : onSurface.withOpacity(0.7),
              ),
            ),
          ),
      ],
    );
  }
}

/// [ZSegmentedCircles] 的单个选项描述。
class ZCircleOption<T> {
  final T value;
  final IconData icon;
  const ZCircleOption({required this.value, required this.icon});
}

/// 小块状态胶囊（在线/离线、下载状态等），比 Chip 更紧凑。
class ZBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  const ZBadge({
    super.key,
    required this.label,
    required this.color,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: color.withOpacity(0.28)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// ZL2 风格的弹层/列表行：左侧彩色图标块 + 粗标题 + 可选说明 + 右侧控件/箭头。
///
/// 用于替换旧式 [ListTile]（底部弹层、对话框、详情页头部、依赖列表等）：
/// - [icon] + [iconColor] 决定左侧圆角图标块（默认绿色，危险操作用红色）；
/// - [subtitleMono] 让说明文字用等宽字体（如命令、文件名）；
/// - 有 [onTap] 且无 [trailing] 时显示右侧 chevron；[danger] 让标题与图标变红。
class ZSheetRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool subtitleMono;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const ZSheetRow({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleMono = false,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? Colors.red : (iconColor ?? kZAccent);
    final showChevron = trailing == null && onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.t(title),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: danger ? Colors.red : scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      S.t(subtitle!),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontFamily: subtitleMono ? 'monospace' : null,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

/// ZL2 风格的顶部搜索框（圆角填充、无边框）。
class ZSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const ZSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: S.t(hint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// ZL2 风格的沉浸式 AppBar。
///
/// 全局 [appBarTheme] 已把底色设为透明，这里再统一处理「前景色」与「状态栏」，
/// 避免两类问题：
/// 1. 有壁纸时顶栏文字/图标仍是深色 → 看不清；
/// 2. 切页时顶栏在「白不透明 ↔ 透明」之间跳变 → 视觉闪烁。
///
/// 有自定义壁纸时：标题/图标转白、状态栏图标转浅色；无壁纸时跟随主题。
/// 接受与 [AppBar] 同名的常用参数，可直接替换页面里的 `AppBar(`，无需改动其余代码。
class ZAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final double? elevation;
  final double? scrolledUnderElevation;

  const ZAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.systemOverlayStyle,
    this.elevation,
    this.scrolledUnderElevation,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final titleWidget = (subtitle == null || subtitle!.isEmpty)
        ? title
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) title!,
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: hasWallpaper
                      ? Colors.white.withOpacity(0.72)
                      : Theme.of(context).hintColor,
                ),
              ),
            ],
          );
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: titleWidget,
      actions: actions,
      bottom: bottom,
      elevation: elevation ?? 0,
      scrolledUnderElevation: scrolledUnderElevation ?? 0,
      backgroundColor: backgroundColor ?? (hasWallpaper ? Colors.transparent : null),
      foregroundColor: foregroundColor ?? (hasWallpaper ? Colors.white : null),
      systemOverlayStyle: systemOverlayStyle ??
          (hasWallpaper
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                )
              : null),
    );
  }
}
