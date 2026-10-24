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

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

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
              const Icon(Icons.extension, size: 64),
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
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: T('创造者'),
            subtitle: T('开发者：Z有3笔，协作者：venti1112'),
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
