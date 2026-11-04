import 'package:flutter/material.dart';
import '../mod_manager/mod_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';

/// 模组详情页：展示 jar 元数据（名称 / 版本 / 作者 / 依赖 / 描述）。
class ModDetailPage extends StatelessWidget {
  final RemoteJarFile file;
  final ModProvider provider;

  const ModDetailPage({super.key, required this.file, required this.provider});

  @override
  Widget build(BuildContext context) {
    final meta = file.meta;
    return Scaffold(
      appBar: ZAppBar(title: Text(file.fileName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ZPanel(
            style: ZStyle.of(context, hasWallpaper: false),
            children: [
              ZSheetRow(
                icon: Icons.extension,
                title: meta.name ?? S.t('未知名称'),
                subtitle: S.f('版本 {0}', [meta.version ?? '未知']),
              ),
            ],
          ),
          const Divider(),
          _kv('文件名', file.fileName),
          _kv('大小', _fmtSize(file.size)),
          _kv('修改时间', '${file.mtime.toLocal()}'),
          _kv('作者', meta.authors ?? '未知'),
          _kv('元数据来源', meta.source),
          if (meta.description != null) _kv('描述', meta.description!),
          const Divider(),
          T('硬依赖', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (meta.depends.isEmpty)
            T('无')
          else
            Wrap(
              spacing: 6,
              children: meta.depends
                  .map((d) => Chip(label: Text(d)))
                  .toList(),
            ),
          const SizedBox(height: 12),
          T('软依赖', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (meta.softDepends.isEmpty)
            T('无')
          else
            Wrap(spacing: 6, children: meta.softDepends.map((d) => Chip(label: Text(d))).toList()),
        ],
      ),
    );
  }

  /// 键值行：左侧固定 96px 宽作标签，右侧自适应剩余宽度并自动换行。
  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
