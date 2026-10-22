import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/dependency_index_service.dart';
import '../../providers/download_provider.dart';
import '../../providers/server_provider.dart';

/// 依赖仓库页：服务器本地仓库增量同步 + 依赖树查询 + 缺失依赖一键补齐 + 重复检测。
class DependencyTreePage extends StatefulWidget {
  final ServerConfig server;

  const DependencyTreePage({super.key, required this.server});

  @override
  State<DependencyTreePage> createState() => _DependencyTreePageState();
}

class _DependencyTreePageState extends State<DependencyTreePage> {
  List<IndexedMod>? _mods;
  bool _syncing = false;
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
        _syncInfo = '同步失败：$e';
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
            const Text('该模组依赖：'),
            ...tree.dependsOn.map((m) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text('${m.name ?? m.fileName} ${m.version ?? ''}'),
                )),
            if (tree.dependsOn.isEmpty) const Text('无', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('被以下模组依赖：'),
            ...tree.dependents.map((m) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text('${m.name ?? m.fileName} ${m.version ?? ''}'),
                )),
            if (tree.dependents.isEmpty) const Text('无', style: TextStyle(color: Colors.grey)),
            if (tree.missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('缺失依赖（可一键补齐）：',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ...tree.missing.map((d) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    title: Text(d),
                    trailing: TextButton(
                      onPressed: () => _fetchMissing(d),
                      child: const Text('从 Modrinth 补齐'),
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
      if (results.isEmpty) throw '未找到 $name';
      final project = results.first;
      final versions = await dp.versions(project.projectId);
      if (versions.isEmpty) throw '该项目没有可用版本';
      final v = versions.first;
      if (v.files.isEmpty) throw '没有可用文件';
      final primary = v.files.firstWhere((f) => f['primary'] == true, orElse: () => v.files.first);
      await dp.download(url: primary['url'], fileName: primary['filename'], projectType: 'mod');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已下载 $name（${v.versionNumber}）')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('补齐失败：$e')));
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
            Text('版本冲突 / 重复 jar', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            if (dups.isEmpty) const Text('未发现重复'),
            ...dups.map((g) => ExpansionTile(
                  title: Text(g.modId,
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  subtitle: Text('${g.items.length} 个版本共存'),
                  children: g.items
                      .map((m) => ListTile(
                            dense: true,
                            title: Text(m.fileName),
                            subtitle: Text('版本 ${m.version ?? '未知'} · ${m.remotePath}'),
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
        title: const Text('依赖仓库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: '重复检测',
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
                  label: const Text('同步'),
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
                            const Text('索引为空，先点击「同步」'),
                            if (!widget.server.hasSsh)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('（该服务器未配置 SSH，无法同步）',
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
                              '${m.fileName} · 依赖 ${m.depends.length} · 软依赖 ${m.softDepends.length}',
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
