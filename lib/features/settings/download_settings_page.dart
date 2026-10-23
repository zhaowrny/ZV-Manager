import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';

/// 下载与镜像设置页：镜像线路选择、测速自动选线、并发数（原下载页内设置移入此处）。
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
    return Scaffold(
      appBar: AppBar(title: const Text('下载与镜像设置')),
      body: ListView(
        children: [
          const SectionHeader('镜像线路'),
          RadioListTile<String>(
            title: const Text('MCIM 国内镜像（推荐）'),
            subtitle: const Text('modrinth.mcimirror.top，无需科学上网'),
            value: 'mcim',
            groupValue: mirror.currentId,
            onChanged: (v) async {
              await mirror.select(v!);
              setState(() {});
            },
          ),
          RadioListTile<String>(
            title: const Text('Modrinth 官方'),
            subtitle: const Text('直连官方源，适合海外网络'),
            value: 'official',
            groupValue: mirror.currentId,
            onChanged: (v) async {
              await mirror.select(v!);
              setState(() {});
            },
          ),
          RadioListTile<String>(
            title: const Text('自定义镜像'),
            subtitle: Text(mirror.currentId == 'custom' && mirror.customUrl.isNotEmpty
                ? mirror.customUrl
                : '使用自建/第三方镜像地址'),
            value: 'custom',
            groupValue: mirror.currentId,
            onChanged: (v) async => {await _editCustomUrl(), setState(() {})},
          ),
          ListTile(
            leading: _testing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.speed),
            title: const Text('一键测速并选择最快线路'),
            subtitle: Text(mirror.lastSpeedMs > 0
                ? '上次测速：${mirror.lastSpeedMs}ms（${mirror.currentName}）'
                : '自动在官方与镜像之间选择延迟最低的线路'),
            onTap: _testing
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _testing = true);
                    await mirror.autoSelect();
                    if (!mounted) return;
                    setState(() => _testing = false);
                    messenger.showSnackBar(SnackBar(
                      content: Text('已选择最快线路：${mirror.currentName}（${mirror.lastSpeedMs}ms）'),
                    ));
                  },
          ),
          const Divider(),
          const SectionHeader('下载队列'),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('同时下载任务数'),
            subtitle: Text('当前：${dp.concurrency} 个（越大越占带宽，建议 1-3）'),
            trailing: DropdownButton<int>(
              value: dp.concurrency,
              underline: const SizedBox.shrink(),
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '说明：下载完成的文件保存在应用目录 downloads/ 下；'
              '若服务器配置了 SSH，会自动上传到对应服务器的 mods/plugins 目录。',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editCustomUrl() async {
    final dp = context.read<DownloadProvider>();
    final ctrl = TextEditingController(text: dp.mirror.customUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('自定义镜像地址'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'https://your-mirror.example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      await dp.mirror.select('custom', customUrl: url);
    }
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
