import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../widgets/z_widgets.dart';

/// 统一的「需要先选服务器 / 未配置」引导空状态页。
/// 自带 AppBar 标题栏，避免页面看起来空白、引导文字无处安放。
class EmptyStatePage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 可选的 AppBar bottom（例如页签内的模式切换条）。
  final PreferredSizeWidget? bottom;

  const EmptyStatePage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: ZAppBar(title: T(title), bottom: bottom),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 36, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                S.t(message),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor, height: 1.6),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: T(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
