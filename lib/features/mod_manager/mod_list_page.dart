import 'package:file_picker/file_picker.dart';
import '../../providers/wallpaper_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dashboard/server_picker_bar.dart';
import 'mod_provider.dart';
import 'mod_detail_page.dart';
import 'dependency_tree_page.dart';

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
      return const Center(child: Text('请先在「服务器」页选择一台服务器'));
    }
    if (!server.hasSsh) {
      return _NoSshHint(serverName: server.name);
    }
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final p = _provider;
    if (p == null) return const SizedBox.shrink();
    return ChangeNotifierProvider<ModProvider>.value(
      value: p,
      child: Consumer<ModProvider>(builder: (context, mod, _) {
        return Scaffold(
          backgroundColor: hasWallpaper ? Colors.transparent : null,
          appBar: AppBar(
            title: const Text('模组管理'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: mod.loading ? null : mod.refresh,
                tooltip: '刷新',
              ),
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: '依赖仓库',
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
              // mods / plugins 切换 + 排序
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'mods', label: Text('mods')),
                        ButtonSegment(value: 'plugins', label: Text('plugins')),
                      ],
                      selected: {mod.currentDir},
                      onSelectionChanged: (s) =>
                          mod.open(server, dir: s.first),
                    ),
                    const Spacer(),
                    PopupMenuButton<ModSortMode>(
                      icon: const Icon(Icons.sort),
                      onSelected: (m) => mod.setSortMode(m),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: ModSortMode.name, child: Text('按名称')),
                        PopupMenuItem(value: ModSortMode.size, child: Text('按大小')),
                        PopupMenuItem(value: ModSortMode.mtime, child: Text('按修改时间')),
                      ],
                    ),
                  ],
                ),
              ),
              if (mod.loading) const LinearProgressIndicator(),
              if (mod.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('加载失败：${mod.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(
                child: mod.files.isEmpty && !mod.loading
                    ? const Center(child: Text('目录下没有 .jar 文件'))
                    : ListView.builder(
                        itemCount: mod.files.length,
                        itemBuilder: (context, i) {
                          final f = mod.files[i];
                          return ListTile(
                            leading: const Icon(Icons.extension_outlined),
                            title: Text(f.fileName),
                            subtitle: Text(
                              '${f.meta.name ?? '未知'} ${f.meta.version ?? ''}'
                              ' · ${_fmtSize(f.size)}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (a) => _onAction(context, mod, f, a),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'detail', child: Text('详情')),
                                PopupMenuItem(value: 'rename', child: Text('重命名')),
                                PopupMenuItem(value: 'delete', child: Text('删除')),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ModDetailPage(file: f, provider: mod),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.upload_file),
            label: const Text('上传 jar'),
            onPressed: mod.loading ? null : () => _upload(context, mod),
          ),
        );
      }),
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
            .showSnackBar(SnackBar(content: Text('上传失败：$e')));
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
            title: const Text('确认删除'),
            content: Text('确定要删除 ${f.fileName} 吗？此操作不可恢复。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
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
            title: const Text('重命名'),
            content: TextField(controller: ctrl, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                  child: const Text('确定')),
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

class _NoSshHint extends StatelessWidget {
  final String serverName;
  const _NoSshHint({required this.serverName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_encryption_outlined, size: 56),
            const SizedBox(height: 12),
            Text('$serverName 未配置 SSH'),
            const SizedBox(height: 8),
            const Text(
              '模组管理需要 SSH 连接。请在「服务器」页编辑该服务器，\n开启 SSH 并填写用户名和密码。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
