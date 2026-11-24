import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/sftp_service.dart';
import '../../core/l10n/strings.dart';
import '../../providers/server_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../core/widgets/z_widgets.dart';
import '../dashboard/server_picker_bar.dart';

/// 服务器日志页（设置内入口）：通过 SFTP 读取服务器 logs 目录，
/// 列出日志文件并查看内容（默认读取末尾 2MB，支持自动刷新）。
class ServerLogPage extends StatefulWidget {
  const ServerLogPage({super.key});

  @override
  State<ServerLogPage> createState() => _ServerLogPageState();
}

class _ServerLogPageState extends State<ServerLogPage> {
  final _sftp = SftpService();
  final _pathCtrl = TextEditingController();
  Timer? _autoTimer;

  bool _loading = false;
  String? _error;
  List<_LogFile> _files = [];
  bool _autoRefresh = false;

  ServerConfig? _server;

  @override
  void initState() {
    super.initState();
    final holder = context.read<SelectedServerHolder>();
    _server = holder.server;
    _pathCtrl.text = _defaultLogsDir(_server);
    holder.addListener(_onHolderChanged);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    context.read<SelectedServerHolder>().removeListener(_onHolderChanged);
    _pathCtrl.dispose();
    _sftp.disconnect();
    super.dispose();
  }

  /// 切换服务器时清空旧文件列表，并把路径重置为新服务器的默认值，
  /// 避免把 A 服务器的日志路径带到 B 服务器上。
  void _onHolderChanged() {
    if (!mounted) return;
    final s = context.read<SelectedServerHolder>().server;
    if (s?.id != _server?.id) {
      setState(() {
        _server = s;
        _files = [];
        _error = null;
        _pathCtrl.text = _defaultLogsDir(s);
      });
    }
  }

  /// 推导默认日志目录：root 用户为 /root/logs，
  /// 其他用户为 /home/<user>/logs（与原版服务端默认工作目录一致）。
  String _defaultLogsDir(ServerConfig? s) {
    if (s == null) return '';
    final user = s.sshUser;
    final home = user == 'root' ? '/root' : '/home/$user';
    return '$home/logs';
  }

  String get _dir => _pathCtrl.text.trim().isEmpty
      ? _defaultLogsDir(_server)
      : _pathCtrl.text.trim();

  /// 通过 SFTP 拉取日志目录列表，按修改时间倒序（最新的在最上面）。
  /// 无 SSH 配置时直接给出提示，不发请求。
  Future<void> _refresh() async {
    final s = _server;
    if (s == null || !s.hasSsh) {
      setState(() => _error = S.t('请先在「服务器」页配置 SSH 连接'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _sftp.connect(s);
      final items = await _sftp.listDir(_dir);
      final files = <_LogFile>[];
      for (final it in items) {
        if (it.attr.isDirectory) continue;
        files.add(_LogFile(
          name: it.filename,
          size: it.attr.size ?? 0,
          mtime: DateTime.fromMillisecondsSinceEpoch(
              (it.attr.modifyTime ?? 0) * 1000),
        ));
      }
      files.sort((a, b) => b.mtime.compareTo(a.mtime));
      if (!mounted) return;
      setState(() => _files = files);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = S.f('加载失败：{0}', [e.toString()]));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 开关自动刷新：开启后每 5 秒重读一次文件。
  /// 轮询而非长连接，是因为 SFTP 没有 tail 语义，代价也可控。
  void _toggleAuto(bool v) {
    setState(() => _autoRefresh = v);
    _autoTimer?.cancel();
    if (v) {
      _autoTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    }
  }

  Future<void> _viewFile(_LogFile f) async {
    final s = _server;
    if (s == null || !s.hasSsh) return;
    setState(() => _loading = true);
    try {
      await _sftp.connect(s);
      final content = await _sftp.readString('$_dir/${f.name}');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _LogViewerPage(
            title: f.name,
            content: content,
            sftp: _sftp,
            remotePath: '$_dir/${f.name}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.f('读取失败：{0}', [e.toString()]))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final servers = context.watch<ServerProvider>().servers;
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: T('服务器日志'),
        backgroundColor: hasWallpaper ? Colors.transparent : null,
      ),
      body: Column(
        children: [
          // ---------- 顶部：服务器 + 路径 + 自动刷新 ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ZPanel(style: st, children: [
              ZRow(
                title: '服务器',
                subtitle: _server == null
                    ? S.t('请选择一台已配置 SSH 的服务器')
                    : '${_server!.name}  ·  ${_server!.sshUser}@${_server!.host}',
                style: st,
                leading: Icon(Icons.dns_outlined, size: 20, color: st.subColor),
                trailing: DropdownButton<String>(
                  value:
                      _server != null && servers.any((s) => s.id == _server!.id)
                          ? _server!.id
                          : null,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  hint: T('选择'),
                  items: servers
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: SizedBox(
                              width: 110,
                              child: Text(s.name,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right),
                            ),
                          ))
                      .toList(),
                  onChanged: (id) {
                    final s = servers.where((e) => e.id == id).firstOrNull;
                    setState(() {
                      _server = s;
                      _files = [];
                      _error = null;
                      _pathCtrl.text = _defaultLogsDir(s);
                    });
                  },
                ),
              ),
              ZDivider(style: st),
              ZRow(
                title: '日志目录',
                subtitle: '默认按 SSH 用户推导，可手动修改',
                style: st,
                leading:
                    Icon(Icons.folder_outlined, size: 20, color: st.subColor),
                trailing: SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _pathCtrl,
                    textAlign: TextAlign.right,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: InputDecoration(
                      hintText: S.t('例如 /root/logs'),
                      hintStyle: TextStyle(fontSize: 12, color: st.subColor),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              ZDivider(style: st),
              ZRow(
                title: '自动刷新',
                subtitle: '每 5 秒重新读取目录列表',
                style: st,
                leading: Icon(Icons.autorenew, size: 20, color: st.subColor),
                trailing: ZSwitch(
                  value: _autoRefresh,
                  size: 40,
                  borderColor: st.subColor,
                  onChanged: _toggleAuto,
                ),
              ),
            ]),
          ),
          // ---------- 文件列表 ----------
          Expanded(child: _buildList(st)),
        ],
      ),
    );
  }

  /// 日志文件列表：整块一个圆角面板，文件行之间用细线分隔。
  Widget _buildList(ZStyle st) {
    if (_loading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: st.subColor),
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, height: 1.5, color: st.subColor)),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _refresh, child: T('重试')),
            ],
          ),
        ),
      );
    }
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 40, color: st.subColor),
            const SizedBox(height: 12),
            Text(S.t('目录下没有日志文件'),
                style: TextStyle(fontSize: 13, color: st.subColor)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loading ? null : _refresh,
              child: T('刷新'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ZPanel(style: st, children: [
            for (var i = 0; i < _files.length; i++) ...[
              if (i > 0) ZDivider(style: st),
              ZRow(
                title: _files[i].name,
                subtitle: '${_fmtSize(_files[i].size)} · '
                    '${_files[i].mtime.toLocal().toString().substring(0, 19)}',
                style: st,
                leading: Icon(Icons.description_outlined,
                    size: 20, color: st.subColor),
                onTap: () => _viewFile(_files[i]),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _LogFile {
  final String name;
  final int size;
  final DateTime mtime;
  _LogFile({required this.name, required this.size, required this.mtime});
}

/// 单个日志文件内容查看页。
class _LogViewerPage extends StatefulWidget {
  final String title;
  final String content;
  final SftpService sftp;
  final String remotePath;

  const _LogViewerPage({
    required this.title,
    required this.content,
    required this.sftp,
    required this.remotePath,
  });

  @override
  State<_LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<_LogViewerPage> {
  final _controller = ScrollController();
  Timer? _autoTimer;
  bool _autoRefresh = false;
  bool _following = true;
  late String _content;

  @override
  void initState() {
    super.initState();
    _content = widget.content;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpBottom());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 把视图滚到底部（模拟 tail -f 的跟随效果）。
  void _jumpBottom() {
    if (_controller.hasClients) {
      _controller.jumpTo(_controller.position.maxScrollExtent);
    }
  }

  /// 重新拉取日志内容；仅在 [_following] 为 true 时才自动滚到底，
  /// 避免用户上翻查看历史时被强行拉回底部。
  Future<void> _reload() async {
    try {
      final c = await widget.sftp.readString(widget.remotePath);
      if (!mounted) return;
      setState(() => _content = c);
      if (_following)
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpBottom());
    } catch (_) {}
  }

  /// 开关自动刷新：开启后每 5 秒重读一次文件。
  /// 轮询而非长连接，是因为 SFTP 没有 tail 语义，代价也可控。
  void _toggleAuto(bool v) {
    setState(() => _autoRefresh = v);
    _autoTimer?.cancel();
    if (v) {
      _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) => _reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _content.split('\n');
    return Scaffold(
      appBar: ZAppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: S.t('刷新'),
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      // 底部工具条：自动刷新开关 + 回到底部，两者都是长日志场景的高频操作
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  S.t('自动刷新并跟随底部（每 5 秒）'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _jumpBottom,
                icon: const Icon(Icons.vertical_align_bottom, size: 18),
                label: T('底部'),
              ),
              const SizedBox(width: 6),
              ZSwitch(
                value: _autoRefresh,
                size: 40,
                borderColor: Theme.of(context).colorScheme.onSurfaceVariant,
                onChanged: _toggleAuto,
              ),
            ],
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is UserScrollNotification) {
            _following = n.metrics.pixels >= n.metrics.maxScrollExtent - 24;
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.all(14),
          child: SelectableText(
            lines.join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}
