import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../core/services/modrinth_api.dart';
import '../../providers/download_provider.dart';
import '../../core/services/download_manager.dart';
import '../settings/download_settings_page.dart';
import '../../core/l10n/strings.dart';

/// 下载中心：Modrinth 搜索 + 镜像线路选择 + 下载任务队列（M2）。
class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _searchCtrl = TextEditingController();
  List<ModrinthSearchResult>? _results;
  bool _searching = false;
  String _projectType = 'mod';
  String? _mcVersion;
  String? _loader;

  static const _mcVersions = ['1.21.4', '1.21.1', '1.20.6', '1.20.4', '1.20.1', '1.19.4', '1.18.2', '1.16.5'];
  static const _loaders = ['fabric', 'forge', 'quilt', 'neoforge', 'paper', 'bukkit', 'spigot'];

  /// 任务队列视图：false=卡片列表，true=进度条视图。
  bool _barView = false;

  @override
  void initState() {
    super.initState();
    context.read<DownloadProvider>().init();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _results = null;
    });
    try {
      final dp = context.read<DownloadProvider>();
      final results = await dp.search(
        query,
        projectType: _projectType,
        mcVersion: _mcVersion,
        loader: _loader,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.f('搜索失败：{0}', [e]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.read<DownloadProvider>();
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: hasWallpaper ? Colors.transparent : null,
        appBar: AppBar(
          title: T('下载中心'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: S.t('下载与镜像设置'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadSettingsPage()),
              ),
            ),
            IconButton(
              icon: Icon(_barView ? Icons.view_list_outlined : Icons.equalizer),
              tooltip: _barView ? S.t('卡片视图') : S.t('进度条视图'),
              onPressed: () => setState(() => _barView = !_barView),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: '搜索下载'), Tab(text: '任务队列')]),
        ),
        body: TabBarView(children: [_buildSearchTab(), _buildQueueTab(dp)]),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: S.t('搜索 Modrinth 模组/插件，如 sodium'),
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _searching ? null : _search, child: T('搜索')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _dropdown<String>(
                value: _projectType,
                items: const {'mod': '模组', 'plugin': '插件'},
                onChanged: (v) => setState(() => _projectType = v!),
              ),
              const SizedBox(width: 8),
              _dropdown<String>(
                value: _mcVersion,
                hint: 'MC 版本',
                items: {for (final v in _mcVersions) v: v},
                onChanged: (v) => setState(() => _mcVersion = v),
              ),
              const SizedBox(width: 8),
              _dropdown<String>(
                value: _loader,
                hint: '加载器',
                items: {for (final v in _loaders) v: v},
                onChanged: (v) => setState(() => _loader = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : _results == null
                  ? const Center(child: T('输入关键词开始搜索'))
                  : _results!.isEmpty
                      ? const Center(child: T('没有结果'))
                      : ListView.builder(
                          itemCount: _results!.length,
                          itemBuilder: (context, i) {
                            final r = _results![i];
                            return ListTile(
                              leading: const Icon(Icons.extension),
                              title: Text(r.title),
                              subtitle: Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text('${r.downloads}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              onTap: () => _showVersionSheet(r),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required Map<String, String> items,
    String? hint,
    required ValueChanged<T?> onChanged,
  }) {
    return Expanded(
      child: DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(), isDense: true),
        items: items.entries
            .map((e) => DropdownMenuItem<T>(value: e.key as T, child: Text(e.value, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// 版本选择底部弹层。
  Future<void> _showVersionSheet(ModrinthSearchResult r) async {
    final dp = context.read<DownloadProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: T('正在获取版本列表...'), duration: Duration(seconds: 1)),
    );
    try {
      final versions = await dp.versions(r.projectId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(S.f('选择 {0} 的版本', [r.title]), style: Theme.of(context).textTheme.titleMedium),
              ),
              ...versions.take(15).map((v) => ListTile(
                    title: Text(v.versionNumber),
                    subtitle: Text('${v.loaders.join('/')} · ${v.gameVersions.take(3).join(', ')}'),
                    trailing: const Icon(Icons.download),
                    onTap: () => _downloadVersion(v),
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.f('获取版本失败：{0}', [e]))));
      }
    }
  }

  Future<void> _downloadVersion(ModrinthVersion v) async {
    Navigator.pop(context);
    final dp = context.read<DownloadProvider>();
    // 取主 jar 文件
    final files = v.files;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: T('该版本没有可用文件')));
      return;
    }
    final primary = files.firstWhere((f) => f['primary'] == true, orElse: () => files.first);
    final url = primary['url'] as String;
    final fileName = primary['filename'] as String;
    await dp.download(url: url, fileName: fileName, projectType: _projectType);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.f('已加入下载队列：{0}', [fileName]))));
    }
  }

  /// 进度条视图：每个任务一条横向进度条 + 百分比。
  Widget _buildBarList(DownloadProvider dp, List tasks) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${i + 1}. ${t.fileName}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Text('${(t.progress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 4),
                  _statusChip(t.status),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: t.status == DownloadStatus.completed ? 1 : t.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${_fmt(t.receivedBytes)} / ${_fmt(t.totalBytes)}'
                    '${t.status == DownloadStatus.running ? " · ${_fmt(t.speed)}/s" : ""}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (t.status == DownloadStatus.running)
                    IconButton(
                      icon: const Icon(Icons.pause, size: 20),
                      tooltip: S.t('暂停'),
                      onPressed: () => dp.manager.pause(t.id),
                    ),
                  if (t.status == DownloadStatus.paused)
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 20),
                      tooltip: S.t('继续'),
                      onPressed: () => dp.manager.resume(t.id),
                    ),
                  if (t.status == DownloadStatus.failed)
                    IconButton(
                      icon: const Icon(Icons.replay, size: 20),
                      tooltip: S.t('重试'),
                      onPressed: () => dp.manager.retry(t.id),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: S.t('取消'),
                    onPressed: () => dp.manager.cancel(t.id),
                  ),
                ],
              ),
              if (t.error != null)
                Text(t.error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueTab(DownloadProvider dp) {
    return AnimatedBuilder(
      animation: dp.manager,
      builder: (context, _) {
        final tasks = dp.manager.tasks;
        if (tasks.isEmpty) return const Center(child: T('暂无下载任务'));
        if (_barView) return _buildBarList(dp, tasks);
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, i) {
            final t = tasks[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(t.fileName, overflow: TextOverflow.ellipsis)),
                        _statusChip(t.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: t.progress),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${_fmt(t.receivedBytes)} / ${_fmt(t.totalBytes)}'
                          '${t.status == DownloadStatus.running ? " · ${_fmt(t.speed)}/s" : ""}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (t.status == DownloadStatus.running)
                          IconButton(
                            icon: const Icon(Icons.pause),
                            tooltip: S.t('暂停'),
                            onPressed: () => dp.manager.pause(t.id),
                          ),
                        if (t.status == DownloadStatus.paused)
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: S.t('继续'),
                            onPressed: () => dp.manager.resume(t.id),
                          ),
                        if (t.status == DownloadStatus.failed)
                          IconButton(
                            icon: const Icon(Icons.replay),
                            tooltip: S.t('重试'),
                            onPressed: () => dp.manager.retry(t.id),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: S.t('取消'),
                          onPressed: () => dp.manager.cancel(t.id),
                        ),
                      ],
                    ),
                    if (t.error != null)
                      Text(t.error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusChip(DownloadStatus s) {
    final (label, color) = switch (s) {
      DownloadStatus.queued => ('排队中', Colors.grey),
      DownloadStatus.running => ('下载中', Colors.blue),
      DownloadStatus.paused => ('已暂停', Colors.orange),
      DownloadStatus.completed => ('已完成', Colors.green),
      DownloadStatus.failed => ('失败', Colors.red),
      DownloadStatus.canceled => ('已取消', Colors.grey),
    };
    return Chip(label: Text(label, style: const TextStyle(fontSize: 12)), backgroundColor: color.withOpacity(0.15), visualDensity: VisualDensity.compact);
  }

  String _fmt(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }


}
