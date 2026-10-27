import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/dependency_index_service.dart';
import '../../providers/download_provider.dart';
import '../../providers/server_provider.dart';
import '../../core/l10n/strings.dart';

/// 依赖仓库页：服务器本地仓库增量同步 + 依赖树查询 + 缺失依赖一键补齐 + 重复检测。
class DependencyTreePage extends StatefulWidget {
  final ServerConfig server;

  const DependencyTreePage({super.key, required this.server});

  @override
  State<DependencyTreePage> createState() => _DependencyTreePageState();
}

class _DependencyTreePageState extends State<DependencyTreePage> {
  /// null 表示尚未完成首次加载（显示 loading）
  List<IndexedMod>? _mods;
  bool _syncing = false;

  /// 同步结果提示文字（成功统计 / 失败原因）
  String? _syncInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mods = await DependencyIndexService.listForServer(widget.server.id);
    if (!mounted) return;
    setState(() => _mods = mods);
  }

  /// 手动触发一次增量同步：只解析新增或变更的 jar，未变化的跳过，
  /// 因此重复点击的代价很低。
  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncInfo = null;
    });
    try {
      final result = await DependencyIndexService.syncServer(widget.server);
      if (!mounted) return;
      setState(() {
        _syncInfo = result.toString();
        _syncing = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncInfo = S.f('同步失败：{0}', [e]);
      });
    }
  }

  Future<void> _showTree(IndexedMod mod) async {
    final tree = await DependencyIndexService.queryTree(widget.server.id, mod.modId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('${tree.mod.name ?? tree.mod.fileName} ${tree.mod.version ?? ''}',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            T('该模组依赖：'),
            ...tree.dependsOn.map((m) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text('${m.name ?? m.fileName} ${m.version ?? ''}'),
                )),
            if (tree.dependsOn.isEmpty) T('无', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            T('被以下模组依赖：'),
            ...tree.dependents.map((m) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text('${m.name ?? m.fileName} ${m.version ?? ''}'),
                )),
            if (tree.dependents.isEmpty) T('无', style: TextStyle(color: Colors.grey)),
            if (tree.missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              T('缺失依赖（可一键补齐）：',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ...tree.missing.map((d) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    title: Text(d),
                    trailing: TextButton(
                      onPressed: () => _fetchMissing(d),
                      child: T('从 Modrinth 补齐'),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fetchMissing(String name) async {
    final dp = context.read<DownloadProvider>();
    try {
      final results = await dp.search(name, projectType: 'mod', limit: 1);
      if (results.isEmpty) throw S.f('未找到 {0}', [name]);
      final project = results.first;
      final versions = await dp.versions(project.projectId);
      if (versions.isEmpty) throw S.t('该项目没有可用版本');
      final v = versions.first;
      if (v.files.isEmpty) throw S.t('没有可用文件');
      final primary = v.files.firstWhere((f) => f['primary'] == true, orElse: () => v.files.first);
      await dp.download(url: primary['url'], fileName: primary['filename'], projectType: 'mod');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.f('已下载 {0}（{1}）', [name, v.versionNumber]))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.f('补齐失败：{0}', [e]))));
      }
    }
  }

  Future<void> _checkDuplicates() async {
    final dups = await DependencyIndexService.findDuplicates(widget.server.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(S.t('版本冲突 / 重复 jar'), style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            if (dups.isEmpty) T('未发现重复'),
            ...dups.map((g) => ExpansionTile(
                  title: Text(g.modId,
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  subtitle: Text(S.f('{0} 个版本共存', [g.items.length])),
                  children: g.items
                      .map((m) => ListTile(
                            dense: true,
                            title: Text(m.fileName),
                            subtitle: Text('${m.version ?? S.t('未知')} · ${m.remotePath}'),
                          ))
                      .toList(),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: T('依赖仓库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: S.t('重复检测'),
            onPressed: _checkDuplicates,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(_syncInfo ?? '点击「同步」增量扫描服务器 mods/plugins 并建立依赖索引'),
                ),
                FilledButton.icon(
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: T('同步'),
                  onPressed: _syncing ? null : _sync,
                ),
              ],
            ),
          ),
          Expanded(
            child: _mods == null
                ? const Center(child: CircularProgressIndicator())
                : _mods!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            T('索引为空，先点击「同步」'),
                            if (!widget.server.hasSsh)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: T('（该服务器未配置 SSH，无法同步）',
                                    style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _mods!.length,
                        itemBuilder: (context, i) {
                          final m = _mods![i];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text('${m.name ?? m.fileName} ${m.version ?? ''}'),
                            subtitle: Text(
                              S.f('{0} · 依赖 {1} · 软依赖 {2}', [m.fileName, m.depends.length, m.softDepends.length]),
                            ),
                            trailing: const Icon(Icons.account_tree_outlined),
                            onTap: () => _showTree(m),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
