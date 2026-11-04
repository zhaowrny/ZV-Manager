import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/update_service.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/wallpaper_provider.dart';

/// 关于软件页：版本与检查更新 + 开发者信息 + 开源许可。
///
/// 版式：顶部 Logo 区 → 「应用」面板（检查更新 / 开源许可）→
/// 「创造者」面板（头像行）→ 底部免责说明。
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
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: T('关于软件'),
        backgroundColor: hasWallpaper ? Colors.transparent : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _Header(version: _currentVersion, style: st),
          const SizedBox(height: 20),
          ZPanel(style: st, children: [
            ZRow(
              title: '检查更新',
              subtitle: '从 Gitee 获取最新版本',
              style: st,
              leading: Icon(Icons.system_update_outlined,
                  size: 20, color: st.subColor),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _checkingUpdate ? null : _checkUpdate,
            ),
            ZDivider(style: st),
            ZRow(
              title: '开源许可',
              subtitle: '查看本应用使用的第三方库许可',
              style: st,
              leading: Icon(Icons.fact_check_outlined,
                  size: 20, color: st.subColor),
              onTap: () => showLicensePage(context: context),
            ),
          ]),
          const SizedBox(height: 14),
          _SectionLabel('创造者', style: st),
          ZPanel(style: st, children: [
            _CreatorRow(
              style: st,
              name: 'Z有3笔',
              role: S.t('开发者 · Gitee: DriftinBlock'),
              assetAvatar: 'assets/creator_zavatar.png',
              homeUrl: 'https://gitee.com/driftinblock',
            ),
            ZDivider(style: st),
            _CreatorRow(
              style: st,
              name: 'Ventiの酒',
              role: S.t('协作者 · Gitee: venti1112'),
              avatarUrl: 'https://gitee.com/venti1112.png',
              homeUrl: 'https://gitee.com/venti1112',
            ),
          ]),
          const SizedBox(height: 22),
          Text(
            S.t('ZV Manager 是一款 Minecraft 服务器远程管理工具，'
                '本软件与 Mojang、微软无任何隶属关系。'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.6, color: st.subColor),
          ),
        ],
      ),
    );
  }
}

/// 顶部品牌区：Logo + 名称 + 版本号。
class _Header extends StatelessWidget {
  final String version;
  final ZStyle style;
  const _Header({required this.version, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset('assets/logo.png', width: 88, height: 88),
        ),
        const SizedBox(height: 12),
        Text(
          'ZV Manager',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: style.titleColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          S.f('版本 {0}', [version]),
          style: TextStyle(fontSize: 12.5, color: style.subColor),
        ),
      ],
    );
  }
}

/// 分组小标题（面板外的灰色小字）。
class _SectionLabel extends StatelessWidget {
  final String text;
  final ZStyle style;
  const _SectionLabel(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        S.t(text),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: style.subColor,
        ),
      ),
    );
  }
}

/// 创造者行：头像 + 名称 + 角色，点击打开 Gitee 主页。
class _CreatorRow extends StatelessWidget {
  final ZStyle style;
  final String name;
  final String role;
  final String homeUrl;

  /// 头像二选一：本地资产优先，否则用网络头像。
  final String? assetAvatar;
  final String? avatarUrl;

  const _CreatorRow({
    required this.style,
    required this.name,
    required this.role,
    required this.homeUrl,
    this.assetAvatar,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ZRow(
      style: style,
      title: name,
      subtitle: role,
      leading: ClipOval(
        child: SizedBox(
          width: 38,
          height: 38,
          child: assetAvatar != null
              ? Image.asset(assetAvatar!, fit: BoxFit.cover)
              : Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: style.scheme.surfaceContainerHighest,
                    child: Icon(Icons.person,
                        size: 20, color: style.scheme.onSurfaceVariant),
                  ),
                ),
        ),
      ),
      onTap: () => UpdateService.openUrl(homeUrl),
    );
  }
}
