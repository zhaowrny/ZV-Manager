import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../utils/release_notes.dart';
import '../utils/update_info.dart';

/// 检查更新详情弹窗：版本号、发布时间、发布页和解析后的更新日志。
class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  final String currentVersion;
  final VoidCallback onUpdate;
  final ValueChanged<String> onOpenUrl;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.currentVersion,
    required this.onUpdate,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = ReleaseNotes.parse(info.releaseNotes);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text(
                S.t('发现新版本'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: S.t('版本号'), value: info.latestVersion),
                    const SizedBox(height: 7),
                    if (info.releasedAt != null) ...[
                      _InfoRow(
                        label: S.t('更新时间'),
                        value: _formatDateTime(info.releasedAt!),
                      ),
                      const SizedBox(height: 7),
                    ],
                    _InfoRow(
                      label: S.t('当前版本'),
                      value: currentVersion,
                    ),
                    if (info.releasePageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: S.t('更新发布页'),
                        value: 'Gitee',
                        link: true,
                        onTap: () => onOpenUrl(info.releasePageUrl),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 16),
                    Text(
                      S.t('更新内容'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (notes.isEmpty)
                      Text(
                        S.t('本次更新暂无详细说明'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ..._buildSections(context, notes.sections),
                    if (notes.links.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...notes.links.map(
                        (link) => _NoteLink(
                          label: link.label,
                          onTap: () => onOpenUrl(link.url),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  if (info.releasePageUrl.isNotEmpty)
                    TextButton(
                      onPressed: () => onOpenUrl(info.releasePageUrl),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: T('查看发布页'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: T('忽略'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onUpdate();
                    },
                    child: T('立即更新'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    List<ReleaseNoteSection> sections,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final widgets = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (i > 0) widgets.add(const SizedBox(height: 14));
      widgets.add(
        Text(
          S.t(section.title),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
      );

      for (final item in section.items) {
        widgets.add(const SizedBox(height: 6));
        if (item.bullet) {
          widgets.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.primary,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
          );
        } else {
          widgets.add(
            Text(
              item.text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          );
        }
      }
    }

    return widgets;
  }
}

/// 「版本号：xxx」形式的单行信息。
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool link;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.label,
    required this.value,
    this.link = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final separator = S.en ? ': ' : '：';
    final valueStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: link ? scheme.primary : scheme.onSurface,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label$separator',
          style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
        ),
        Expanded(
          child: link
              ? InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(value, style: valueStyle),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                )
              : Text(value, style: valueStyle),
        ),
      ],
    );
  }
}

/// 发布说明底部提取出的可点击链接。
class _NoteLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NoteLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.link, size: 17, color: scheme.primary),
        label: Text(S.t(label)),
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');

  if (S.en) {
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
  return '${local.year}年${two(local.month)}月${two(local.day)}日 '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
