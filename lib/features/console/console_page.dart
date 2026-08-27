import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/command_preset_service.dart';
import '../../core/utils/rcon_client.dart';
import '../player_management/player_list_page.dart';

class ConsolePage extends StatefulWidget {
  final RconClient rconClient;
  const ConsolePage({super.key, required this.rconClient});

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _history = <String>[];
  int _historyIndex = -1;
  final _outputLines = <_LogLine>[];
  List<QuickCommandPreset> _presets = [];

  static const _commands = [
    'help', 'list', 'stop', 'say', 'op', 'deop', 'kick', 'ban', 'pardon',
    'gamemode', 'tp', 'give', 'time set', 'weather', 'difficulty',
  ];

  @override
  void initState() {
    super.initState();
    widget.rconClient.onDisconnected = () {
      if (mounted) {
        setState(() => _outputLines.add(_LogLine(text: '[警告] 连接断开，正在重连...', isError: true)));
      }
    };
    widget.rconClient.onReconnected = () {
      if (mounted) {
        setState(() => _outputLines.add(_LogLine(text: '[信息] 重连成功', isCommand: false)));
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
    if (_history.isEmpty || _history.last != cmd) _history.add(cmd);
    _historyIndex = _history.length;

    setState(() {
      _outputLines.add(_LogLine(text: '> $cmd', isCommand: true));
    });
    _scrollToBottom();

    try {
      final response = await widget.rconClient.executeCommand(cmd);
      setState(() {
        _outputLines.add(_LogLine(
          text: stripMinecraftCodes(response ?? '(无响应)'),
          isCommand: false,
        ));
      });
    } catch (e) {
      setState(() {
        _outputLines.add(_LogLine(text: '[错误] $e', isCommand: false, isError: true));
      });
    }
    _scrollToBottom();
  }

  void _onTabPressed() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final matches = _commands.where((c) => c.startsWith(input)).toList();
    if (matches.length == 1) {
      _controller.text = matches.first;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: matches.first.length));
    } else if (matches.length > 1) {
      setState(() {
        _outputLines.add(_LogLine(text: '建议：${matches.join(", ")}', isCommand: false));
      });
      _scrollToBottom();
    }
  }

  void _onHistoryNavigate(bool up) {
    if (_history.isEmpty) return;
    setState(() {
      if (up) {
        _historyIndex = (_historyIndex - 1).clamp(0, _history.length - 1);
      } else {
        _historyIndex = (_historyIndex + 1).clamp(0, _history.length);
      }
      _controller.text = _historyIndex < _history.length ? _history[_historyIndex] : '';
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器控制台'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: '玩家管理',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerListPage(rconClient: widget.rconClient)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _outputLines.length,
                itemBuilder: (_, i) {
                  final line = _outputLines[i];
                  return SelectableText(
                    line.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: line.isError
                          ? theme.colorScheme.error
                          : line.isCommand
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ),
          ),
          _PresetBar(
            presets: _presets,
            onSend: _sendCommand,
            onManage: _managePresets,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) _onHistoryNavigate(true);
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown) _onHistoryNavigate(false);
                          if (event.logicalKey == LogicalKeyboardKey.tab) _onTabPressed();
                        }
                      },
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: '输入命令...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                        onSubmitted: (_) => _executeCommand(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _executeCommand,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('发送'),
                  ),
                ],
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
                return ActionChip(
                  label: Text(preset.label),
                  labelStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSecondaryContainer),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  onPressed: () => onSend(preset.command),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: '管理快速命令',
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
        _presets.add(QuickCommandPreset(label: result.label, command: result.command));
      } else {
        final index = _presets.indexOf(preset);
        _presets[index] = QuickCommandPreset(label: result.label, command: result.command);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('快速命令', style: theme.textTheme.titleMedium),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('点击标签一键发送，点击右侧按钮编辑'),
            ),
            Expanded(
              child: _presets.isEmpty
                  ? const Center(child: Text('暂无预设，点击下方按钮添加'))
                  : ListView.builder(
                      itemCount: _presets.length,
                      itemBuilder: (context, i) {
                        final preset = _presets[i];
                        return ListTile(
                          leading: const Icon(Icons.bolt_outlined),
                          title: Text(preset.label),
                          subtitle: Text(
                            preset.command,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.send_rounded, size: 20),
                                tooltip: '发送',
                                onPressed: () => widget.onSend(preset.command),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: '编辑',
                                onPressed: () => _editPreset(preset: preset),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                tooltip: '删除',
                                onPressed: () => setState(() => _presets.removeAt(i)),
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
                    label: const Text('新增'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _presets),
                    child: const Text('完成'),
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
  late final _labelController = TextEditingController(text: widget.preset?.label ?? '');
  late final _commandController = TextEditingController(text: widget.preset?.command ?? '');

  @override
  void dispose() {
    _labelController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.preset == null ? '新增预设' : '编辑预设'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: '标签', hintText: '例如：立即存档'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commandController,
            decoration: const InputDecoration(labelText: '命令', hintText: '例如：save-all'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelController.text.trim();
            final command = _commandController.text.trim();
            if (label.isEmpty || command.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('标签和命令都不能为空')),
              );
              return;
            }
            Navigator.pop(context, _PresetEditResult(label: label, command: command));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}