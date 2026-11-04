import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../core/services/modrinth_api.dart';
import '../../providers/download_provider.dart';
import '../../core/services/download_manager.dart';
import '../settings/download_settings_page.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';

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

  /// 按关键词 + 版本 + 加载器筛选搜索 Modrinth。
  /// 结果置 null 表示"搜索中"，UI 据此显示骨架/加载态而非"无结果"。
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
        appBar: ZAppBar(
          title: T('下载中心'),
          backgroundColor: hasWallpaper ? Colors.transparent : null,
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

  /// 搜索页签：圆角搜索框 + 三枚筛选下拉 + 结果面板。
  Widget _buildSearchTab() {
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ZSearchField(
            controller: _searchCtrl,
            hint: '搜索 Modrinth 模组/插件，如 sodium',
            onSubmitted: (_) => _search(),
            trailing: _searching
                ? const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    tooltip: S.t('搜索'),
                    onPressed: _search,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
        Expanded(child: _buildResults(st)),
      ],
    );
  }

  /// 搜索结果列表：整块圆角面板，结果行之间用细线分隔。
  Widget _buildResults(ZStyle st) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_outlined, size: 40, color: st.subColor),
            const SizedBox(height: 12),
            Text(S.t('输入关键词开始搜索'),
                style: TextStyle(fontSize: 13, color: st.subColor)),
          ],
        ),
      );
    }
    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: st.subColor),
            const SizedBox(height: 12),
            Text(S.t('没有结果'),
                style: TextStyle(fontSize: 13, color: st.subColor)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 6),
          child: Text(
            S.f('共 {0} 个结果', [_results!.length]),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: st.subColor,
            ),
          ),
        ),
        ZPanel(style: st, children: [
          for (var i = 0; i < _results!.length; i++) ...[
            if (i > 0) ZDivider(style: st),
            ZRow(
              style: st,
              title: _results![i].title,
              subtitle: _results![i].description,
              value: '${_results![i].downloads}',
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: st.scheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.extension, size: 18, color: st.scheme.primary),
              ),
              onTap: () => _showVersionSheet(_results![i]),
            ),
          ],
        ]),
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
        builder: (ctx) {
          final st = ZStyle.of(ctx, hasWallpaper: false);
          final list = versions.take(15).toList();
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(S.f('选择 {0} 的版本', [r.title]), style: Theme.of(context).textTheme.titleMedium),
                ),
                ZPanel(
                  style: st,
                  children: [
                    for (int i = 0; i < list.length; i++) ...[
                      if (i > 0) ZDivider(style: st),
                      ZSheetRow(
                        icon: Icons.history,
                        title: list[i].versionNumber,
                        subtitle: '${list[i].loaders.join('/')} · ${list[i].gameVersions.take(3).join(', ')}',
                        trailing: Icon(Icons.download, color: kZAccent, size: 20),
                        onTap: () => _downloadVersion(list[i]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
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

  /// 进度条视图：每个任务一条横向进度条 + 百分比，整块放进一个圆角面板。
  Widget _buildBarList(DownloadProvider dp, List tasks, ZStyle st) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        ZPanel(style: st, children: [
          for (var i = 0; i < tasks.length; i++) ...[
            if (i > 0) ZDivider(style: st),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i + 1}. ${tasks[i].fileName}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: st.titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(tasks[i].progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: st.subColor),
                      ),
                      const SizedBox(width: 6),
                      _statusBadge(tasks[i].status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: tasks[i].status == DownloadStatus.completed
                          ? 1
                          : tasks[i].progress,
                      minHeight: 6,
                      backgroundColor: st.dividerColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_fmt(tasks[i].receivedBytes)} / ${_fmt(tasks[i].totalBytes)}'
                          '${tasks[i].status == DownloadStatus.running ? " · ${_fmt(tasks[i].speed)}/s" : ""}',
                          style: TextStyle(fontSize: 11.5, color: st.subColor),
                        ),
                      ),
                      ..._taskActions(dp, tasks[i], compact: true),
                    ],
                  ),
                  if (tasks[i].error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tasks[i].error!,
                        style: TextStyle(
                            fontSize: 11.5, color: st.scheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ]),
      ],
    );
  }

  /// 卡片视图：每个任务一张圆角卡片（信息更全，适合单手操作）。
  Widget _buildCardList(DownloadProvider dp, List tasks, ZStyle st) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ZPanel(style: st, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.fileName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: st.titleColor,
                            ),
                          ),
                        ),
                        _statusBadge(t.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: t.progress,
                        minHeight: 6,
                        backgroundColor: st.dividerColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_fmt(t.receivedBytes)} / ${_fmt(t.totalBytes)}'
                            '${t.status == DownloadStatus.running ? " · ${_fmt(t.speed)}/s" : ""}',
                            style: TextStyle(fontSize: 11.5, color: st.subColor),
                          ),
                        ),
                        ..._taskActions(dp, t, compact: false),
                      ],
                    ),
                    if (t.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(t.error!,
                            style: TextStyle(
                                fontSize: 11.5, color: st.scheme.error)),
                      ),
                  ],
                ),
              ),
            ]),
          ),
      ],
    );
  }

  /// 任务操作按钮组：按状态决定显示暂停/继续/重试，取消始终可用。
  List<Widget> _taskActions(DownloadProvider dp, dynamic t,
      {required bool compact}) {
    final size = compact ? 19.0 : 20.0;
    final scheme = Theme.of(context).colorScheme;
    return [
      if (t.status == DownloadStatus.running)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.pause_rounded, size: size),
          tooltip: S.t('暂停'),
          onPressed: () => dp.manager.pause(t.id),
        ),
      if (t.status == DownloadStatus.paused)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.play_arrow_rounded, size: size),
          tooltip: S.t('继续'),
          onPressed: () => dp.manager.resume(t.id),
        ),
      if (t.status == DownloadStatus.failed)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.replay_rounded, size: size),
          tooltip: S.t('重试'),
          onPressed: () => dp.manager.retry(t.id),
        ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.close_rounded, size: size, color: scheme.error),
        tooltip: S.t('取消'),
        onPressed: () => dp.manager.cancel(t.id),
      ),
    ];
  }

  Widget _buildQueueTab(DownloadProvider dp) {
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);
    return AnimatedBuilder(
      animation: dp.manager,
      builder: (context, _) {
        final tasks = dp.manager.tasks;
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_download_outlined,
                    size: 40, color: st.subColor),
                const SizedBox(height: 12),
                Text(S.t('暂无下载任务'),
                    style: TextStyle(fontSize: 13, color: st.subColor)),
                const SizedBox(height: 6),
                Text(S.t('在上方「搜索下载」页签中选择模组即可开始'),
                    style: TextStyle(fontSize: 12, color: st.subColor)),
              ],
            ),
          );
        }
        // 顶部任务计数
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(
                children: [
                  Text(
                    S.f('共 {0} 个任务', [tasks.length]),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: st.subColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _barView
                  ? _buildBarList(dp, tasks, st)
                  : _buildCardList(dp, tasks, st),
            ),
          ],
        );
      },
    );
  }

  /// 任务状态胶囊（沿用 ZL2 的小圆角标签样式）。
  Widget _statusBadge(DownloadStatus s) {
    final (label, color) = switch (s) {
      DownloadStatus.queued => ('排队中', const Color(0xFF90A4AE)),
      DownloadStatus.running => ('下载中', const Color(0xFF42A5F5)),
      DownloadStatus.paused => ('已暂停', const Color(0xFFFFA726)),
      DownloadStatus.completed => ('已完成', kZAccent),
      DownloadStatus.failed => ('失败', const Color(0xFFEF5350)),
      DownloadStatus.canceled => ('已取消', const Color(0xFF90A4AE)),
    };
    return ZBadge(label: label, color: color);
  }

  String _fmt(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }


}
