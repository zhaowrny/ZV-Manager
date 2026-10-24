import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/sftp_service.dart';
import '../../core/l10n/strings.dart';
import '../../providers/server_provider.dart';
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

  String _defaultLogsDir(ServerConfig? s) {
    if (s == null) return '';
    final user = s.sshUser;
    final home = user == 'root' ? '/root' : '/home/$user';
    return '$home/logs';
  }

  String get _dir => _pathCtrl.text.trim().isEmpty
      ? _defaultLogsDir(_server)
      : _pathCtrl.text.trim();

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

  void _toggleAuto(bool v) {
    setState(() => _autoRefresh = v);
    _autoTimer?.cancel();
    if (v) {
      _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
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
    return Scaffold(
      appBar: AppBar(title: T('服务器日志')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<ServerConfig>(
              value: _server != null && servers.any((s) => s.id == _server!.id)
                  ? _server
                  : null,
              decoration: InputDecoration(
                labelText: S.t('选择服务器（需开启 SSH）'),
                border: const OutlineInputBorder(),
              ),
              items: servers
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (s) {
                setState(() {
                  _server = s;
                  _files = [];
                  _error = null;
                  _pathCtrl.text = _defaultLogsDir(s);
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathCtrl,
                    decoration: InputDecoration(
                      labelText: S.t('日志目录路径'),
                      hintText: S.t('例如 /root/logs'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _refresh,
                  tooltip: S.t('刷新'),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: T('自动刷新（每 5 秒）'),
            value: _autoRefresh,
            onChanged: _toggleAuto,
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: T('重试')),
            ],
          ),
        ),
      );
    }
    if (_files.isEmpty) {
      return Center(child: T('目录下没有日志文件'));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _files.length,
        itemBuilder: (_, i) {
          final f = _files[i];
          return ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(f.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${_fmtSize(f.size)} · ${f.mtime.toLocal()}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _viewFile(f),
          );
        },
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

  void _jumpBottom() {
    if (_controller.hasClients) {
      _controller.jumpTo(_controller.position.maxScrollExtent);
    }
  }

  Future<void> _reload() async {
    try {
      final c = await widget.sftp.readString(widget.remotePath);
      if (!mounted) return;
      setState(() => _content = c);
      if (_following) WidgetsBinding.instance.addPostFrameCallback((_) => _jumpBottom());
    } catch (_) {}
  }

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
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: S.t('刷新'),
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      bottomNavigationBar: SwitchListTile(
        title: T('自动刷新并跟随底部（每 5 秒）'),
        value: _autoRefresh,
        onChanged: _toggleAuto,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is UserScrollNotification) {
            _following = n.metrics.pixels >=
                n.metrics.maxScrollExtent - 24;
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            lines.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
