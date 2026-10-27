import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/l10n/strings.dart';
import '../../core/utils/update_service.dart';

/// 关于软件页：版本与检查更新 + 开发者信息 + 开源许可。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _currentVersion = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// 从 APK 信息读取当前版本号（对应 pubspec.yaml 的 version）。
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

  /// 检查更新：拉取 Gitee 最新 release 并与当前版本比对。
  /// 网络异常和"拿不到发布信息"给出不同提示，便于用户区分是网络问题还是仓库问题。
  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final updateInfo = await UpdateService.fetchInfo(userAgent: _currentVersion);
      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (updateInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: T('获取更新信息失败')),
        );
        return;
      }

      UpdateService.showUpdateDialog(context, updateInfo, _currentVersion);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.f('检查更新失败：{0}', [e]))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: T('关于软件')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/logo.png', width: 96, height: 96),
              ),
              const SizedBox(height: 8),
              T('ZV Manager', style: Theme.of(context).textTheme.titleLarge),
              Text(S.f('版本 {0}', [_currentVersion]),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: T('检查更新'),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : _checkUpdate,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: T('创造者', style: Theme.of(context).textTheme.titleSmall),
          ),
          const _CreatorTile(
            name: 'Z有3笔',
            role: '开发者 · Gitee: DriftinBlock',
            assetAvatar: 'assets/creator_zavatar.png',
            homeUrl: 'https://gitee.com/driftinblock',
          ),
          _CreatorTile(
            name: 'Ventiの酒',
            role: S.t('协作者 · Gitee: venti1112'),
            avatarUrl: 'https://gitee.com/venti1112.png',
            homeUrl: 'https://gitee.com/venti1112',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: T('开源许可'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              S.t('ZV Manager 是一款 Minecraft 服务器远程管理工具，本软件与 Mojang、微软无任何隶属关系。'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 创造者条目：头像 + 名称 + 角色，点击打开 Gitee 主页。
class _CreatorTile extends StatelessWidget {
  final String name;
  final String role;
  final String homeUrl;

  /// 头像二选一：本地资产优先，否则用网络头像。
  final String? assetAvatar;
  final String? avatarUrl;

  const _CreatorTile({
    required this.name,
    required this.role,
    required this.homeUrl,
    this.assetAvatar,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: assetAvatar != null
              ? Image.asset(assetAvatar!, fit: BoxFit.cover)
              : Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFDDDDDD), child: Icon(Icons.person)),
                ),
        ),
      ),
      title: Text(name),
      subtitle: Text(role, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => UpdateService.openUrl(homeUrl),
    );
  }
}
