import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/command_preset_service.dart';
import '../../core/utils/rcon_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/wallpaper_provider.dart';
import 'package:provider/provider.dart';

/// 控制台页：命令输入 + 输出回显 + 命令历史 + Tab 补全 + 快捷指令。
///
/// 输出只保存在内存里（最多 [_maxLines] 行），退出页面即清空——
/// 真正的持久化日志请看「设置 → 服务器日志」（读服务器 logs 目录）。
class ConsolePage extends StatefulWidget {
  final RconClient rconClient;

  /// 可选的 AppBar bottom（如「控制台 / 终端」切换条）。
  final PreferredSizeWidget? bottom;

  const ConsolePage({super.key, required this.rconClient, this.bottom});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// 已执行过的命令，供上下键翻阅
  final _history = <String>[];

  /// 当前浏览到的历史位置；等于 length 表示"正在输入新命令"
  int _historyIndex = -1;
  final _outputLines = <_LogLine>[];

  /// 输出行数上限，防止长时间运行后内存无限增长
  static const _maxLines = 500;
  List<QuickCommandPreset> _presets = [];

  /// Tab 补全候选：常用服务端命令
  static const _commands = [
    'help',
    'list',
    'stop',
    'say',
    'op',
    'deop',
    'kick',
    'ban',
    'pardon',
    'gamemode',
    'tp',
    'give',
    'time set',
    'weather',
    'difficulty',
  ];

  @override
  void initState() {
    super.initState();
    // 连接状态变化直接写入输出区，用户能看到断线与恢复的时间点
    widget.rconClient.onDisconnected = () {
      if (mounted) {
        setState(() =>
            _append(_LogLine(text: S.t('[警告] 连接断开，正在重连...'), isError: true)));
      }
    };
    widget.rconClient.onReconnected = () {
      if (mounted) {
        setState(
            () => _append(_LogLine(text: S.t('[信息] 重连成功'), isCommand: false)));
      }
    };
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await CommandPresetService.load();
    if (mounted) setState(() => _presets = presets);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 追加一行输出，超过上限时丢弃最早的行。
  void _append(_LogLine line) {
    _outputLines.add(line);
    if (_outputLines.length > _maxLines) {
      _outputLines.removeRange(0, _outputLines.length - _maxLines);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _executeCommand() async {
    final cmd = _controller.text.trim();
    if (cmd.isEmpty) return;
    _controller.clear();
    await _sendCommand(cmd);
  }

  Future<void> _sendCommand(String cmd) async {
    // 去重：连续执行同一条命令时不重复记入历史
    if (_history.isEmpty || _history.last != cmd) _history.add(cmd);
    _historyIndex = _history.length;

    setState(() {
      _append(_LogLine(text: '> $cmd', isCommand: true));
    });
    _scrollToBottom();

    try {
      final response = await widget.rconClient.executeCommand(cmd);
      setState(() {
        _append(_LogLine(
          text: stripMinecraftCodes(response ?? S.t('(无响应)')),
          isCommand: false,
        ));
      });
    } catch (e) {
      setState(() {
        _append(_LogLine(
            text: S.f('[错误] {0}', [e.toString()]),
            isCommand: false,
            isError: true));
      });
    }
    _scrollToBottom();
  }

  void _onTabPressed() {
    // 简单的前缀补全：只有唯一匹配时直接补全，多个匹配则列出候选
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final matches = _commands.where((c) => c.startsWith(input)).toList();
    if (matches.length == 1) {
      _controller.text = matches.first;
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: matches.first.length));
    } else if (matches.length > 1) {
      setState(() {
        _append(_LogLine(
            text: S.f('建议：{0}', [matches.join(", ")]), isCommand: false));
      });
      _scrollToBottom();
    }
  }

  /// 上下键翻阅历史：up 往更早的命令走，down 往更新的走；
  /// 走到最新位置之后即为空白（相当于"取消翻阅"）。
  void _onHistoryNavigate(bool up) {
    if (_history.isEmpty) return;
    setState(() {
      if (up) {
        _historyIndex = (_historyIndex - 1).clamp(0, _history.length - 1);
      } else {
        _historyIndex = (_historyIndex + 1).clamp(0, _history.length);
      }
      _controller.text =
          _historyIndex < _history.length ? _history[_historyIndex] : '';
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
    });
  }

  Future<void> _managePresets() async {
    final result = await showModalBottomSheet<List<QuickCommandPreset>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PresetManageSheet(
        presets: _presets,
        onSend: _sendCommand,
      ),
    );
    if (result != null && mounted) {
      await CommandPresetService.save(result);
      if (mounted) setState(() => _presets = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: T('服务器控制台'),
        bottom: widget.bottom,
        backgroundColor: hasWallpaper ? Colors.transparent : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: S.t('清空输出'),
            onPressed: () => setState(_outputLines.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------- 输出区 ----------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(kZRadius),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: _outputLines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.terminal_rounded,
                                size: 32, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text(
                              S.t('输入命令后按回车执行'),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _outputLines.length,
                        itemBuilder: (_, i) {
                          final line = _outputLines[i];
                          return SelectableText(
                            line.text,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.45,
                              color: line.isError
                                  ? scheme.error
                                  : line.isCommand
                                      ? scheme.primary
                                      // 按日志级别前缀着色：WARN 黄 / ERROR 红 / INFO 绿
                                      : _logLevelColor(line.text) ??
                                          scheme.onSurface,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          _PresetBar(
            presets: _presets,
            onSend: _sendCommand,
            onManage: _managePresets,
          ),
          // ---------- 输入区 ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: Row(
                  children: [
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp)
                              _onHistoryNavigate(true);
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown)
                              _onHistoryNavigate(false);
                            if (event.logicalKey == LogicalKeyboardKey.tab)
                              _onTabPressed();
                          }
                        },
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: S.t('输入命令...'),
                            hintStyle: TextStyle(
                                fontSize: 13, color: scheme.onSurfaceVariant),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13.5),
                          onSubmitted: (_) => _executeCommand(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 圆形发送钮，与 ZL2 的圆形控件语言一致
                    GestureDetector(
                      onTap: _executeCommand,
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kZAccent,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine {
  final String text;
  final bool isCommand;
  final bool isError;
  _LogLine({required this.text, this.isCommand = false, this.isError = false});
}

/// 按日志前缀识别级别并返回对应颜色（INFO 绿 / WARN 黄 / ERROR 红）。
Color? _logLevelColor(String text) {
  final upper = text.toUpperCase();
  // 兼容 [WARN]、[WARN/...]、WARN : 等常见格式
  if (upper.contains('ERROR') ||
      upper.contains('FATAL') ||
      upper.contains('SEVERE')) {
    return Colors.red;
  }
  if (upper.contains(RegExp(r'\bWARN(ING)?\b'))) {
    return Colors.orange;
  }
  if (upper.contains(RegExp(r'\bINFO\b'))) {
    return Colors.green;
  }
  return null;
}

/// 快速命令预设栏：横向滚动的预设按钮 + 管理入口。
class _PresetBar extends StatelessWidget {
  final List<QuickCommandPreset> presets;
  final ValueChanged<String> onSend;
  final VoidCallback onManage;

  const _PresetBar({
    required this.presets,
    required this.onSend,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final preset = presets[i];
                return Center(
                  child: GestureDetector(
                    onTap: () => onSend(preset.command),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: S.t('管理快速命令'),
            onPressed: onManage,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// 快速命令管理底部弹窗：可新增、编辑、删除、一键发送，点完成保存。
class _PresetManageSheet extends StatefulWidget {
  final List<QuickCommandPreset> presets;
  final ValueChanged<String> onSend;

  const _PresetManageSheet({required this.presets, required this.onSend});

  @override
  State<_PresetManageSheet> createState() => _PresetManageSheetState();
}

class _PresetManageSheetState extends State<_PresetManageSheet> {
  late final List<QuickCommandPreset> _presets = List.of(widget.presets);

  Future<void> _editPreset({QuickCommandPreset? preset}) async {
    final result = await showDialog<_PresetEditResult>(
      context: context,
      builder: (_) => _PresetEditDialog(preset: preset),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (preset == null) {
        _presets.add(
            QuickCommandPreset(label: result.label, command: result.command));
      } else {
        final index = _presets.indexOf(preset);
        _presets[index] =
            QuickCommandPreset(label: result.label, command: result.command);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: T('快速命令', style: theme.textTheme.titleMedium),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: T('点击标签一键发送，点击右侧按钮编辑'),
            ),
            Expanded(
              child: _presets.isEmpty
                  ? const Center(child: T('暂无预设，点击下方按钮添加'))
                  : ListView.builder(
                      itemCount: _presets.length,
                      itemBuilder: (context, i) {
                        final preset = _presets[i];
                        return ZSheetRow(
                          icon: Icons.bolt_outlined,
                          title: preset.label,
                          subtitle: preset.command,
                          subtitleMono: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.send_rounded, size: 20),
                                tooltip: S.t('发送'),
                                onPressed: () => widget.onSend(preset.command),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: S.t('编辑'),
                                onPressed: () => _editPreset(preset: preset),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                                tooltip: S.t('删除'),
                                onPressed: () =>
                                    setState(() => _presets.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editPreset(),
                    icon: const Icon(Icons.add, size: 18),
                    label: T('新增'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _presets),
                    child: T('完成'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetEditResult {
  final String label;
  final String command;
  _PresetEditResult({required this.label, required this.command});
}

class _PresetEditDialog extends StatefulWidget {
  final QuickCommandPreset? preset;
  const _PresetEditDialog({this.preset});

  @override
  State<_PresetEditDialog> createState() => _PresetEditDialogState();
}

class _PresetEditDialogState extends State<_PresetEditDialog> {
  late final _labelController =
      TextEditingController(text: widget.preset?.label ?? '');
  late final _commandController =
      TextEditingController(text: widget.preset?.command ?? '');

  @override
  void dispose() {
    _labelController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.preset == null ? S.t('新增预设') : S.t('编辑预设')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            decoration:
                InputDecoration(labelText: S.t('标签'), hintText: S.t('例如：立即存档')),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commandController,
            decoration: InputDecoration(
                labelText: S.t('命令'), hintText: S.t('例如：save-all')),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: T('取消'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelController.text.trim();
            final command = _commandController.text.trim();
            if (label.isEmpty || command.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: T('标签和命令都不能为空')),
              );
              return;
            }
            Navigator.pop(
                context, _PresetEditResult(label: label, command: command));
          },
          child: T('保存'),
        ),
      ],
    );
  }
}
