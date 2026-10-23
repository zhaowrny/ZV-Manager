import 'dart:async';
import 'package:flutter/material.dart';

class UserAgreementDialog extends StatefulWidget {
  final VoidCallback onAgree;

  const UserAgreementDialog({super.key, required this.onAgree});

  @override
  State<UserAgreementDialog> createState() => _UserAgreementDialogState();
}

class _UserAgreementDialogState extends State<UserAgreementDialog> {
  bool _isChecked = false;

  /// 强制阅读：倒计时 10 秒 + 滚动到底，两者都满足才能勾选同意。
  static const int _readSeconds = 10;
  int _countdown = _readSeconds;
  bool _readToEnd = false;
  Timer? _timer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_readToEnd) return;
    final c = _scrollController;
    if (c.position.maxScrollExtent <= 0 || c.offset >= c.position.maxScrollExtent - 8) {
      setState(() => _readToEnd = true);
    }
  }

  bool get _canAgree => _isChecked && _countdown <= 0 && _readToEnd;

  String get _buttonLabel {
    if (_countdown > 0) return '请仔细阅读守则（${_countdown}s）';
    if (!_readToEnd) return '请阅读至守则底部';
    return '同意并进入';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
              const Icon(Icons.menu_book_outlined, size: 48),
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
                height: 420,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionText('版本 v2.0 · 下载、安装或使用本软件，即视为您已阅读并同意本守则全部条款。'),

                      _SectionTitle('一、软件性质与用途'),
                      _SectionText('ZV Manager 是一款 Minecraft 服务器远程管理工具，通过 RCON、SSH/SFTP 等协议连接到您有权管理的服务器，提供服务器控制、玩家管理、模组插件管理、文件下载与远程终端等功能。本软件按"现状"提供。'),

                      _SectionTitle('二、账号与凭据安全'),
                      _SectionText('1. 连接凭据（RCON 密码、SSH 用户名/密码等）仅保存在您的设备本地（加密存储），本软件无云端账号系统，不会将凭据上传至开发者或任何第三方。'),
                      _SectionText('2. 请妥善保管设备与凭据，因主动泄露、设备被他人使用、越狱/Root 等造成的损失由您自行承担。'),
                      _SectionText('3. 仅连接您拥有管理权限的服务器，并使用强密码、定期更换。'),

                      _SectionTitle('三、合法使用（重要）'),
                      _SectionText('1. 仅管理您有权管理的服务器。严禁连接、探测、控制任何未获授权的第三方服务器——未经授权访问计算机系统属于违法行为。'),
                      _SectionText('2. 遵守《网络安全法》《计算机信息系统安全保护条例》等法律法规及 Minecraft EULA 与服务器规则。'),
                      _SectionText('3. 不得利用本软件传播违法信息、破坏他人服务器、恶意攻击或盗取数据。'),
                      _SectionText('4. 下载中心获取的模组/插件版权归原作者所有，请遵守对应开源协议，不得下载、分发盗版或破解内容。'),

                      _SectionTitle('四、SSH / 终端功能风险提示'),
                      _SectionText('1. SSH 终端拥有服务器完全控制能力，您执行的任何命令（含删除文件、重启系统）后果由您自行承担。'),
                      _SectionText('2. 建议不要以 root 账户长期连接，执行不熟悉的命令前请先确认其作用。'),
                      _SectionText('3. 命令历史仅保存在设备本地，可在应用内清除，本软件不做任何云端记录。'),

                      _SectionTitle('五、模组管理与下载功能说明'),
                      _SectionText('1. 下载功能数据来自 Modrinth 公开接口及其镜像线路（如 MCIM）。镜像线路由第三方维护，其可用性与安全性不由开发者控制。'),
                      _SectionText('2. 第三方模组/插件可能影响服务器稳定性，安装前请备份重要数据；"依赖仓库"查询结果仅供参考。'),

                      _SectionTitle('六、免责声明'),
                      _SectionText('1. 本软件为免费开源软件，不提供商业担保。在法律允许的最大范围内，开发者不对因使用或无法使用本软件造成的任何直接或间接损失负责（包括数据丢失、服务器宕机、存档损坏、经济损失）。'),
                      _SectionText('2. 因第三方服务（Modrinth、镜像源、托管商、网络）变更或故障导致的异常，开发者不承担责任。'),

                      _SectionTitle('七、数据与隐私'),
                      _SectionText('1. 本软件不收集、不上传您的任何个人数据，全部数据保存在设备本地，卸载即删除。'),
                      _SectionText('2. 应用仅联网检查更新（Gitee 发布页）及访问 Modrinth/镜像接口，无其他网络请求。'),

                      _SectionTitle('八、知识产权'),
                      _SectionText('1. 本软件按开源协议发布，可依协议使用、修改和分发；"ZV Manager"名称与图标版权归作者所有。'),
                      _SectionText('2. Minecraft 是 Mojang Studios 的商标，本软件与 Mojang、微软无任何隶属关系。'),

                      _SectionTitle('九、守则变更'),
                      _SectionText('开发者可能随版本更新修订本守则并在应用内展示；不同意修订内容请停止使用，继续使用即视为接受。'),

                      _SectionTitle('十、其他'),
                      _SectionText('本守则最终解释权归 ZV Team 所有。如有疑问或发现漏洞，欢迎通过 Gitee 仓库（gitee.com/driftinblock/zvmanager）或官方 QQ 群反馈。'),

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

              // 同意勾选（倒计时结束且阅读到底后才可勾选）
              GestureDetector(
                onTap: _countdown <= 0 && _readToEnd
                    ? () {
                        setState(() {
                          _isChecked = !_isChecked;
                        });
                      }
                    : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isChecked,
                        onChanged: (_countdown <= 0 && _readToEnd)
                            ? (value) {
                                setState(() {
                                  _isChecked = value ?? false;
                                });
                              }
                            : null,
                        activeColor: const Color(0xFF28A745),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _countdown > 0
                          ? '阅读倒计时 $_countdown 秒…'
                          : (_readToEnd ? '我已阅读并同意《用户守则》' : '请先滑动阅读至守则底部'),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canAgree ? widget.onAgree : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _buttonLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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