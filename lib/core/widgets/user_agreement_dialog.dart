import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserAgreementDialog extends StatefulWidget {
  final VoidCallback onAgree;

  const UserAgreementDialog({super.key, required this.onAgree});

  @override
  State<UserAgreementDialog> createState() => _UserAgreementDialogState();
}

class _UserAgreementDialogState extends State<UserAgreementDialog> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              const Text('📜', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),

              // 标题
              const Text(
                '用户守则',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 16),

              // 内容
              Container(
                height: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('一、总则'),
                      _SectionText('欢迎使用 ZV Manager。本守则旨在规范用户行为，保障服务器与用户权益。使用本软件即表示你已阅读并同意本守则。'),

                      _SectionTitle('二、使用规范'),
                      _SectionText('1. 本软件仅供 Minecraft 服务器管理使用，不得用于任何违法用途。'),
                      _SectionText('2. 不得利用本软件对他人服务器进行未经授权的访问或攻击。'),
                      _SectionText('3. 不得利用本软件传播违法信息或进行任何破坏行为。'),

                      _SectionTitle('三、账号与安全'),
                      _SectionText('1. 请妥善保管你的 RCON 密码，因密码泄露造成的损失由用户自行承担。'),
                      _SectionText('2. 本软件采用加密方式存储密码，但不对因设备丢失导致的信息泄露负责。'),

                      _SectionTitle('四、免责声明'),
                      _SectionText('1. 本软件为社区开源项目，并非 Mojang Studios 或 Microsoft 官方产品。'),
                      _SectionText('2. 使用本软件产生的任何后果由用户自行承担。'),
                      _SectionText('3. 开发者保留随时修改本守则的权利。'),

                      _SectionTitle('五、其他'),
                      _SectionText('本守则最终解释权归 ZV Team 所有。如有疑问，请联系开发者。'),

                      SizedBox(height: 16),
                      Text(
                        '© 2026 ZV Team · 与 Mojang 无关',
                        style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 同意勾选
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isChecked = !_isChecked;
                  });
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isChecked,
                        onChanged: (value) {
                          setState(() {
                            _isChecked = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF28A745),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '我已阅读并同意《用户守则》',
                      style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isChecked ? widget.onAgree : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '同意并进入',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}

class _SectionText extends StatelessWidget {
  final String text;
  const _SectionText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF666666),
          height: 1.6,
        ),
      ),
    );
  }
}