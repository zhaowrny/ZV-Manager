/// 一条更新日志条目。
class ReleaseNoteItem {
  final String text;

  /// 是否为列表项（发布说明里以 `*`、`-` 或数字开头）。
  final bool bullet;

  const ReleaseNoteItem({required this.text, required this.bullet});
}

/// 一个更新日志分组，例如「更新」「修复」或发布者自定义的小标题。
class ReleaseNoteSection {
  final String title;
  final List<ReleaseNoteItem> items;

  const ReleaseNoteSection({required this.title, required this.items});
}

/// 发布说明里提取出的链接。
class ReleaseNoteLink {
  final String label;
  final String url;

  const ReleaseNoteLink({required this.label, required this.url});
}

/// Gitee 发布说明的轻量解析结果。
///
/// 不引入 Markdown 依赖，只处理发布说明里常见的标题、列表、粗体和链接。
class ReleaseNotes {
  final List<ReleaseNoteSection> sections;
  final List<ReleaseNoteLink> links;

  const ReleaseNotes({required this.sections, required this.links});

  /// 没有任何可展示的正文条目。
  bool get isEmpty => sections.isEmpty;

  factory ReleaseNotes.parse(String markdown) {
    final sections = <String, ReleaseNoteSection>{};
    final links = <ReleaseNoteLink>[];
    final seenUrls = <String>{};
    var activeTitle = '更新';

    ReleaseNoteSection sectionFor(String title) {
      return sections.putIfAbsent(
        title,
        () => ReleaseNoteSection(title: title, items: <ReleaseNoteItem>[]),
      );
    }

    void addLink(String label, String url) {
      final cleanedUrl =
          url.trim().replaceFirst(RegExp(r'[.,;:!?，。；：！？*_`]+$'), '');
      if (cleanedUrl.isEmpty || !seenUrls.add(cleanedUrl)) return;

      final cleanedLabel =
          _cleanInline(label).replaceFirst(RegExp(r'[:：\s]+$'), '').trim();
      links.add(
        ReleaseNoteLink(
          label: cleanedLabel.isEmpty ? '相关链接' : cleanedLabel,
          url: cleanedUrl,
        ),
      );
    }

    final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (var rawLine in normalized.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('```')) continue;
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line)) continue;
      line = line.replaceFirst(RegExp(r'^>\s?'), '');

      final heading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final title = _cleanInline(heading.group(1) ?? '');
        if (title.isEmpty) continue;
        final lower = title.toLowerCase();
        if (title.contains('更新') ||
            title.contains('新增') ||
            lower.contains('feature') ||
            lower.contains('change')) {
          activeTitle = '更新';
        } else if (title.contains('修复') ||
            lower.contains('fix') ||
            lower.contains('bug')) {
          activeTitle = '修复';
        } else {
          activeTitle = title;
          sectionFor(title);
        }
        continue;
      }

      final bulletMatch = RegExp(r'^[*+-]\s+(.*)$').firstMatch(line) ??
          RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(line);
      final isBullet = bulletMatch != null;
      var content = bulletMatch?.group(1)?.trim() ?? line;

      // 先提取 Markdown 链接，避免 URL 里的字符干扰后面的列表解析。
      content = content.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\((https?://[^)\s]+)\)'),
        (match) {
          addLink(match.group(1) ?? '', match.group(2) ?? '');
          return '';
        },
      );

      // 提取裸链接，并从正文中移除，避免日志里出现很长的 URL。
      content = content.replaceAllMapped(
        RegExp(r'https?://[^\s)<>]+'),
        (match) {
          final rawUrl = match.group(0) ?? '';
          final rest = content.replaceRange(match.start, match.end, '');
          addLink(_linkLabel(rest), rawUrl);
          return '';
        },
      );

      content = _cleanInline(content);
      content = content.replaceFirst(RegExp(r'[\s:：]+$'), '').trim();
      if (content.isEmpty || _isChangelogLabel(content)) continue;

      final prefixMatch = RegExp(
        r'^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(?:\([^)]*\))?!?:\s*',
        caseSensitive: false,
      ).firstMatch(content);
      String? prefix;
      if (prefixMatch != null) {
        prefix = (prefixMatch.group(1) ?? '').toLowerCase();
        content = content.substring(prefixMatch.end).trim();
      }
      if (content.isEmpty) continue;

      final hasPrefix = prefix != null;
      final isFix = prefix == 'fix' ||
          prefix == 'revert' ||
          (!hasPrefix && content.startsWith('修复'));

      final String title;
      if (hasPrefix) {
        title = isFix ? '修复' : '更新';
      } else if (activeTitle == '修复') {
        title = '修复';
      } else if (activeTitle == '更新') {
        title = isFix ? '修复' : '更新';
      } else {
        title = activeTitle;
      }

      sectionFor(title).items.add(
            ReleaseNoteItem(text: content, bullet: isBullet),
          );
    }

    // 固定先展示「更新」和「修复」，再展示发布者自定义的小标题。
    final ordered = <ReleaseNoteSection>[];
    for (final title in const ['更新', '修复']) {
      final section = sections[title];
      if (section != null && section.items.isNotEmpty) ordered.add(section);
    }
    for (final section in sections.values) {
      if (section.title != '更新' &&
          section.title != '修复' &&
          section.items.isNotEmpty) {
        ordered.add(section);
      }
    }

    return ReleaseNotes(sections: ordered, links: links);
  }
}

String _cleanInline(String text) {
  var value = text;
  value = value.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  value = value.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  value = value.replaceAll(RegExp(r'<[^>]*>'), '');
  value = value.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
  value = value.replaceFirst(RegExp(r'^\s*>\s?'), '');
  return value.trim();
}

String _linkLabel(String text) {
  final label = _cleanInline(text).replaceFirst(RegExp(r'[:：\s]+$'), '').trim();
  if (label.isEmpty) return '相关链接';
  if (label.contains('更新日志') ||
      label.contains('完整的更新') ||
      label.toLowerCase().contains('changelog')) {
    return '完整的更新日志';
  }
  return label.length > 32 ? '${label.substring(0, 32)}…' : label;
}

bool _isChangelogLabel(String text) {
  final label = text.replaceAll(RegExp(r'[:：\s]+'), '').toLowerCase();
  return label == '完整的更新日志' ||
      label == '完整更新日志' ||
      label == '更新日志' ||
      label == 'changelog' ||
      label == 'releasenotes' ||
      label == 'fullchangelog';
}
