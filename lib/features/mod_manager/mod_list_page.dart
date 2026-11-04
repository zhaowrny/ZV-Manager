import 'package:file_picker/file_picker.dart';
import '../../providers/wallpaper_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dashboard/server_picker_bar.dart';
import 'mod_provider.dart';
import 'mod_detail_page.dart';
import 'dependency_tree_page.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/empty_state_page.dart';
import '../../core/widgets/z_widgets.dart';

/// 模组/插件管理页：列出服务器 mods / plugins 目录中的 jar 文件，
/// 支持上传 / 删除 / 重命名 / 查看详情（M1）。
class ModListPage extends StatefulWidget {
  const ModListPage({super.key});

  @override
  State<ModListPage> createState() => _ModListPageState();
}

class _ModListPageState extends State<ModListPage>
    with AutomaticKeepAliveClientMixin {
  ModProvider? _provider;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final server = context.read<SelectedServerHolder>().server;
    if (server != null && (_provider == null || _provider!.server?.id != server.id)) {
      _disposeProvider();
      final p = ModProvider();
      _provider = p;
      p.open(server);
    }
  }

  @override
  void dispose() {
    _disposeProvider();
    super.dispose();
  }

  void _disposeProvider() {
    _provider?.disconnect();
    _provider?.dispose();
    _provider = null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final server = context.watch<SelectedServerHolder>().server;
    if (server == null) {
      return EmptyStatePage(
        title: '模组管理',
        icon: Icons.extension_outlined,
        message: '请先在「服务器」页选择一台服务器',
      );
    }
    if (!server.hasSsh) {
      return EmptyStatePage(
        title: '模组管理',
        icon: Icons.extension_outlined,
        message: '「${server.name}」未开启 SSH，请在服务器设置中开启后使用模组管理',
      );
    }
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final p = _provider;
    if (p == null) return const SizedBox.shrink();
    return ChangeNotifierProvider<ModProvider>.value(
      value: p,
      child: Consumer<ModProvider>(builder: (context, mod, _) {
        final st = ZStyle.of(context, hasWallpaper: hasWallpaper);
        return Scaffold(
          backgroundColor: hasWallpaper ? Colors.transparent : null,
          appBar: ZAppBar(
            title: T('模组管理'),
            backgroundColor: hasWallpaper ? Colors.transparent : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: mod.loading ? null : mod.refresh,
                tooltip: S.t('刷新'),
              ),
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: S.t('依赖仓库'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DependencyTreePage(server: server),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // ---------- 目录切换 + 排序 ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    _DirSwitch(
                      value: mod.currentDir,
                      onChanged: (v) => mod.open(server, dir: v),
                    ),
                    const Spacer(),
                    if (mod.files.isNotEmpty)
                      Text(
                        S.f('{0} 个文件', [mod.files.length]),
                        style: TextStyle(fontSize: 12, color: st.subColor),
                      ),
                    PopupMenuButton<ModSortMode>(
                      icon: Icon(Icons.sort_rounded,
                          size: 20, color: st.subColor),
                      tooltip: S.t('排序'),
                      onSelected: (m) => mod.setSortMode(m),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: ModSortMode.name, child: T('按名称')),
                        PopupMenuItem(value: ModSortMode.size, child: T('按大小')),
                        PopupMenuItem(value: ModSortMode.mtime, child: T('按修改时间')),
                      ],
                    ),
                  ],
                ),
              ),
              if (mod.loading) const LinearProgressIndicator(minHeight: 2),
              if (mod.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: st.scheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          S.f('加载失败：{0}', [mod.error.toString()]),
                          style:
                              TextStyle(fontSize: 12.5, color: st.scheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: mod.files.isEmpty && !mod.loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.extension_off_outlined,
                                size: 40, color: st.subColor),
                            const SizedBox(height: 12),
                            Text(
                              S.t('目录下没有 .jar 文件'),
                              style: TextStyle(
                                  fontSize: 13, color: st.subColor),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: mod.loading
                                  ? null
                                  : () => _upload(context, mod),
                              child: T('上传 jar'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        children: [
                          ZPanel(style: st, children: [
                            for (var i = 0; i < mod.files.length; i++) ...[
                              if (i > 0) ZDivider(style: st),
                              _jarRow(context, mod, mod.files[i], st),
                            ],
                          ]),
                        ],
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.upload_file),
            label: T('上传 jar'),
            onPressed: mod.loading ? null : () => _upload(context, mod),
          ),
        );
      }),
    );
  }

  /// 单个 jar 行：文件名 + 元数据（名称/版本/大小）+ 操作菜单。
  Widget _jarRow(BuildContext context, ModProvider mod, RemoteJarFile f, ZStyle st) {
    final metaLine = [
      if (f.meta.name != null) f.meta.name!,
      if (f.meta.version != null) f.meta.version!,
      _fmtSize(f.size),
    ].join(' · ');
    return ZRow(
      style: st,
      title: f.fileName,
      subtitle: metaLine,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFAB47BC).withOpacity(0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.extension_rounded,
            size: 18, color: Color(0xFFAB47BC)),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ModDetailPage(file: f, provider: mod),
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: st.subColor),
        tooltip: S.t('更多操作'),
        onSelected: (a) => _onAction(context, mod, f, a),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: T('详情')),
          PopupMenuItem(value: 'rename', child: T('重命名')),
          PopupMenuItem(value: 'delete', child: T('删除')),
        ],
      ),
    );
  }

  Future<void> _upload(BuildContext context, ModProvider mod) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jar'],
    );
    if (result == null || result.files.single.path == null) return;
    try {
      await mod.uploadJar(result.files.single.path!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.f('上传失败：{0}', [e.toString()]))));
      }
    }
  }

  Future<void> _onAction(
      BuildContext context, ModProvider mod, RemoteJarFile f, String action) async {
    switch (action) {
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: T('确认删除'),
            content: Text(S.f('确定要删除 {0} 吗？此操作不可恢复。', [f.fileName])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: T('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: T('删除')),
            ],
          ),
        );
        if (ok == true) await mod.deleteJar(f.fileName);
        break;
      case 'rename':
        final ctrl = TextEditingController(text: f.fileName);
        final newName = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: T('重命名'),
            content: TextField(controller: ctrl, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: T('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                  child: T('确定')),
            ],
          ),
        );
        if (newName != null && newName.isNotEmpty && newName != f.fileName) {
          await mod.renameJar(f.fileName, newName);
        }
        break;
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// mods / plugins 目录切换：两段等宽圆角按钮，选中段用品牌色。
class _DirSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DirSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget seg(String id, String label) {
      final selected = value == id;
      return GestureDetector(
        onTap: () => onChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? kZAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('mods', 'mods'), seg('plugins', 'plugins')],
      ),
    );
  }
}
