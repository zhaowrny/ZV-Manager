import 'package:flutter/material.dart';
import '../../providers/server_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';

/// 新增 / 编辑服务器的表单弹窗。
///
/// [existingServer] 为 null 表示新建，否则为编辑（保留原 id）。
/// 校验通过后通过 `Navigator.pop` 返回组装好的 [ServerConfig]，
/// 持久化交给调用方处理。
class ServerFormDialog extends StatefulWidget {
  final ServerConfig? existingServer;

  const ServerFormDialog({super.key, this.existingServer});

  @override
  State<ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends State<ServerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _passCtrl;
  bool _obscurePassword = true;
  // SSH 可选配置（模组管理 / 终端需要）
  bool _sshEnabled = false;
  bool _obscureSshPassword = true;
  late TextEditingController _sshPortCtrl;
  late TextEditingController _sshUserCtrl;
  late TextEditingController _sshPasswordCtrl;

  bool get isEditing => widget.existingServer != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingServer;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _hostCtrl = TextEditingController(text: s?.host ?? '');
    _portCtrl = TextEditingController(text: s?.port.toString() ?? '25575');
    _passCtrl = TextEditingController(text: s?.password ?? '');
    _sshEnabled = s?.sshEnabled ?? false;
    _sshPortCtrl = TextEditingController(text: s?.sshPort.toString() ?? '22');
    _sshUserCtrl = TextEditingController(text: s?.sshUser ?? '');
    _sshPasswordCtrl = TextEditingController(text: s?.sshPassword ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _passCtrl.dispose();
    _sshPortCtrl.dispose();
    _sshUserCtrl.dispose();
    _sshPasswordCtrl.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String field) {
    if (value == null || value.trim().isEmpty) return S.f('{0}不能为空', [field]);
    return null;
  }

  /// 端口校验：必须是 1-65535 的整数。
  String? _validatePort(String? value) {
    if (value == null || value.trim().isEmpty) return S.t('端口不能为空');
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) return S.t('端口范围 1-65535');
    return null;
  }

  /// 组装并返回配置。编辑时沿用原 id，保证已有连接/缓存能对应上。
  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final server = ServerConfig(
      id: isEditing ? widget.existingServer!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      password: _passCtrl.text,
      sshEnabled: _sshEnabled,
      sshPort: int.tryParse(_sshPortCtrl.text.trim()) ?? 22,
      sshUser: _sshUserCtrl.text.trim(),
      sshPassword: _sshPasswordCtrl.text,
    );

    Navigator.pop(context, server);
  }

  @override
  Widget build(BuildContext context) {
    final st = ZStyle.of(context, hasWallpaper: false);
    return AlertDialog(
      title: Text(isEditing ? '编辑服务器' : '添加服务器'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: S.t('服务器名称'), hintText: S.t('例如: 我的生存服')),
                validator: (v) => _validateRequired(v, '服务器名称'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostCtrl,
                decoration: InputDecoration(labelText: S.t('主机地址'), hintText: S.t('IP 或域名')),
                validator: (v) => _validateRequired(v, '主机地址'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portCtrl,
                decoration: InputDecoration(labelText: S.t('RCON 端口'), hintText: S.t('默认 25575')),
                keyboardType: TextInputType.number,
                validator: _validatePort,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: S.t('RCON 密码'),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => _validateRequired(v, 'RCON 密码'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              ZPanel(
                style: st,
                children: [
                  ZRow(
                    style: st,
                    title: 'SSH 连接（可选）',
                    subtitle: '用于模组插件管理与远程终端',
                    trailing: ZSwitch(
                      value: _sshEnabled,
                      onChanged: (v) => setState(() => _sshEnabled = v),
                    ),
                  ),
                ],
              ),
              if (_sshEnabled) ...[
                TextFormField(
                  controller: _sshPortCtrl,
                  decoration: InputDecoration(labelText: S.t('SSH 端口'), hintText: S.t('默认 22')),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (!_sshEnabled) return null;
                    return _validatePort(v);
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sshUserCtrl,
                  decoration: InputDecoration(labelText: S.t('SSH 用户名'), hintText: S.t('例如 root')),
                  validator: (v) => _sshEnabled ? _validateRequired(v, 'SSH 用户名') : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sshPasswordCtrl,
                  obscureText: _obscureSshPassword,
                  decoration: InputDecoration(
                    labelText: S.t('SSH 密码'),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureSshPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscureSshPassword = !_obscureSshPassword),
                    ),
                  ),
                  validator: (v) => _sshEnabled ? _validateRequired(v, 'SSH 密码') : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: T('取消')),
        FilledButton(onPressed: _submit, child: Text(isEditing ? '保存' : '添加')),
      ],
    );
  }
}
