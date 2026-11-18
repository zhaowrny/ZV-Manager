import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/download_provider.dart';
import '../../providers/wallpaper_provider.dart';

/// 下载与镜像设置页：镜像线路选择、测速自动选线、并发数（原下载页内设置移入此处）。
///
/// 版式：两组 ZL2 圆角面板。镜像线路用尾部圆形勾选钮表达单选，
/// 比 RadioListTile 更紧凑，也与其他设置页的选中态语言一致。
class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    context.read<DownloadProvider>().init();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DownloadProvider>();
    final mirror = dp.mirror;
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: T('下载与镜像设置'),
        backgroundColor: hasWallpaper ? Colors.transparent : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // ---------- 镜像线路 ----------
          ZPanel(style: st, children: [
            _MirrorRow(
              style: st,
              title: 'MCIM 国内镜像（推荐）',
              subtitle: 'mod.mcimirror.top，无需科学上网',
              selected: mirror.currentId == 'mcim',
              onTap: () async {
                await mirror.select('mcim');
                setState(() {});
              },
            ),
            ZDivider(style: st),
            _MirrorRow(
              style: st,
              title: 'Modrinth 官方',
              subtitle: '直连官方源，适合海外网络',
              selected: mirror.currentId == 'official',
              onTap: () async {
                await mirror.select('official');
                setState(() {});
              },
            ),
            ZDivider(style: st),
            _MirrorRow(
              style: st,
              title: '自定义镜像',
              subtitle: mirror.currentId == 'custom' && mirror.customUrl.isNotEmpty
                  ? mirror.customUrl
                  : '使用自建/第三方镜像地址',
              selected: mirror.currentId == 'custom',
              onTap: () async {
                await _editCustomUrl();
                if (mounted) setState(() {});
              },
            ),
            ZDivider(style: st),
            ZRow(
              title: '一键测速并选择最快线路',
              subtitle: mirror.lastSpeedMs > 0
                  ? S.f('上次测速：{0}ms（{1}）',
                      [mirror.lastSpeedMs, mirror.currentName])
                  : '自动在官方与镜像之间选择延迟最低的线路',
              style: st,
              leading: Icon(Icons.speed, size: 20, color: st.subColor),
              trailing: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _testing ? null : _autoSelect,
            ),
          ]),
          const SizedBox(height: 14),
          // ---------- 下载队列 ----------
          ZPanel(style: st, children: [
            ZRow(
              title: '同时下载任务数',
              subtitle: S.f('当前：{0} 个（越大越占带宽，建议 1-3）', [dp.concurrency]),
              style: st,
              leading: Icon(Icons.playlist_play, size: 20, color: st.subColor),
              trailing: DropdownButton<int>(
                value: dp.concurrency,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: const [1, 2, 3, 4, 5, 6]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (n) async {
                  if (n == null) return;
                  await dp.setConcurrency(n);
                  setState(() {});
                },
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              S.t('说明：下载完成的文件保存在应用目录 downloads/ 下；'
                  '若服务器配置了 SSH，会自动上传到对应服务器的 mods/plugins 目录。'),
              style: TextStyle(fontSize: 12, height: 1.6, color: st.subColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 测速并自动选线：过程中禁用点击，完成后用 SnackBar 告知结果。
  Future<void> _autoSelect() async {
    final dp = context.read<DownloadProvider>();
    final mirror = dp.mirror;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testing = true);
    await mirror.autoSelect();
    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(SnackBar(
      content: Text(S.f('已选择最快线路：{0}（{1}ms）',
          [mirror.currentName, mirror.lastSpeedMs])),
    ));
  }

  Future<void> _editCustomUrl() async {
    final dp = context.read<DownloadProvider>();
    final ctrl = TextEditingController(text: dp.mirror.customUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: T('自定义镜像地址'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'https://your-mirror.example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: T('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: T('确定')),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      await dp.mirror.select('custom', customUrl: url);
    }
  }
}

/// 镜像线路单选行：右侧用圆形勾选钮表示当前生效线路。
class _MirrorRow extends StatelessWidget {
  final ZStyle style;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MirrorRow({
    required this.style,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ZRow(
      style: style,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: ZCheck(
        value: selected,
        size: 20,
        borderColor: style.subColor,
        // 单选：只允许从未选变选中，再点已选项不做取消
        onChanged: (_) => onTap(),
      ),
    );
  }
}
