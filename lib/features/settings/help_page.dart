import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/z_widgets.dart';
import '../../providers/wallpaper_provider.dart';

/// 使用教程页：教用户如何开启 RCON、SSH、使用模组管理/下载/终端等功能。
///
/// 版式：顶部一段说明块 + 每组教程一个 ZL2 圆角面板（标题行可展开正文）。
/// 展开后步骤按序号排列，末尾的「提示」用浅色说明块与步骤区分开。
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = context.watch<WallpaperProvider>().hasWallpaper;
    final st = ZStyle.of(context, hasWallpaper: hasWallpaper);

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: ZAppBar(
        title: T('使用教程'),
        backgroundColor: hasWallpaper ? Colors.transparent : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _Intro(style: st),
          const SizedBox(height: 14),
          _TutorialPanel(
            style: st,
            icon: Icons.settings_ethernet,
            title: '一、如何开启 RCON（必配，控制台/玩家管理需要）',
            steps: const [
              '在服务器目录找到 server.properties 文件（与启动 jar 同目录）',
              '修改/添加以下三行：',
              '   enable-rcon=true',
              '   rcon.port=25575',
              '   rcon.password=你的RCON密码',
              '保存后重启服务器生效',
              '回到 ZV Manager：服务器页 → 添加/编辑服务器，填入主机地址、端口（默认 25575）和 RCON 密码',
            ],
            tips: const [
              '云服务器/虚拟主机需在防火墙或安全组放行 rcon.port 端口',
              '不建议把 25575 端口直接暴露公网，强烈建议设置强密码',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.vpn_key,
            title: '二、如何开启 SSH（模组管理 / 终端 / 下载自动上传需要）',
            steps: const [
              'SSH 是服务器自带的远程管理服务，绝大多数独立服务器默认已开启（端口 22）',
              '不确定的话：用电脑终端执行 ssh 用户名@服务器IP 试试能否登录',
              '拿到 SSH 用户名（如 root）和密码',
              'ZV Manager：服务器页 → 编辑服务器 → 打开「SSH 连接」开关 → 填端口（默认 22）、用户名、密码 → 保存',
            ],
            tips: const [
              '部分面板服 / 虚拟主机只提供网页面板，不提供 SSH，此时模组和终端功能不可用（入口会提示）',
              '有的托管商需要先在控制台开启 SSH/SFTP 功能',
              'SSH 拥有服务器完全控制权，请勿随意执行不熟悉的命令',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.extension,
            title: '三、模组 / 插件管理怎么用',
            steps: const [
              '前提：该服务器已配置 SSH',
              '进入「模组」页签，顶部切换 mods（模组）/ plugins（插件）目录',
              '点「上传 jar」从手机选择文件上传；长按/点菜单可删除、重命名',
              '点击文件名可查看详情：模组名、版本、作者、依赖',
              '上传后需重启服务器才会加载新模组（可在终端执行，或控制台发 stop 后重开）',
            ],
            tips: const [
              'Fabric 模组放 mods 目录；Paper/Spigot 插件放 plugins 目录',
              '版本要和 MC 版本、加载器匹配，否则服务器起不来',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.download,
            title: '四、下载中心与镜像加速',
            steps: const [
              '进入「服务器」页 → 下载中心（或首页快捷入口）',
              '输入关键词搜索 Modrinth 上的模组/插件，可用 MC 版本、加载器筛选',
              '点结果选版本即可加入下载队列，支持暂停/继续/取消',
              '下载完成且配置了 SSH 时，会自动上传到服务器的 mods/plugins 目录',
            ],
            tips: const [
              '国内网络慢时：点右上角测速图标 →「一键测速并选择最快线路」，或改用自定义镜像地址',
              '默认使用 MCIM 国内镜像，无需科学上网',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.terminal,
            title: '五、远程终端',
            steps: const [
              '前提：该服务器已配置 SSH',
              '进入「终端」页签，点右上角 + 新建会话并选择服务器',
              '等同于电脑上的 SSH 终端，可以执行任意命令',
              '底部快捷键栏：Tab 补全、Ctrl+C 中断、Ctrl+D 退出、↑↓ 调历史，以及 htop / df -h / screen -r 常用命令',
              'screen -r 可以进入服务器控制台会话（开服时用了 screen 的话）',
            ],
            tips: const [
              '断网会自动重连（最多 3 次）',
              '命令历史只保存在手机本地，可放心使用',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.account_tree,
            title: '六、依赖仓库（查询模组依赖）',
            steps: const [
              '进入「模组」页签 → 右上角依赖仓库',
              '点「同步」扫描服务器 mods/plugins，建立本地依赖索引',
              '点击任意模组查看：它依赖什么、被谁依赖、缺失哪些依赖',
              '缺失依赖可一键从 Modrinth 下载补齐',
              '点右上角重复检测按钮重复安装 / 版本冲突的 jar',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.notifications_active_outlined,
            title: '七、状态监控与通知',
            steps: const [
              '进入「我的」→ 设置 → 「状态监控」，打开总开关',
              '首次开启会申请通知权限（Android 13+），请点「允许」，否则提醒会被系统丢弃',
              '按需开启「服务器离线 / 服务器恢复 / 玩家上线」三类提醒',
              '「检查间隔」可选 30 秒 / 1 / 2 / 5 分钟，间隔越短发现越快、轮询压力越大',
              '点「立即检查一次」可手动验证 RCON 配置是否可用',
              '提醒依赖 App 进程存活：彻底关闭 App 或被系统省电策略限制时不会推送',
            ],
          ),
          _TutorialPanel(
            style: st,
            icon: Icons.help_outline,
            title: '八、常见问题',
            steps: const [
              'Q：连接失败？→ 检查防火墙是否放行端口、地址端口是否填对、服务器是否在线',
              'Q：控制台能连但模组页提示无 SSH？→ 编辑服务器开启 SSH 并填好账号密码',
              'Q：TPS 显示 —？→ 原版服务端不支持 tps 命令，Paper/Purpur 等服务端才支持',
              'Q：上传模组后不生效？→ 需要重启服务器',
              'Q：开了监控却收不到通知？→ 检查系统是否允许本应用通知、是否开了省电限制',
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶部说明块。
class _Intro extends StatelessWidget {
  final ZStyle style;
  const _Intro({required this.style});

  @override
  Widget build(BuildContext context) {
    return ZPanel(style: style, children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${S.t('本页教您一步步开启并使用 ZV Manager 的各项功能。')}\n'
          '${S.t('首次使用建议按「一 → 二」顺序配置，其余功能即可解锁。')}',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: style.hasWallpaper ? Colors.white : style.scheme.onSurface,
          ),
        ),
      ),
    ]);
  }
}

/// 单组教程：标题行（图标 + 粗标题 + 序号说明）+ 可展开的正文。
class _TutorialPanel extends StatelessWidget {
  final ZStyle style;
  final IconData icon;
  final String title;
  final List<String> steps;
  final List<String> tips;

  const _TutorialPanel({
    required this.style,
    required this.icon,
    required this.title,
    required this.steps,
    this.tips = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor =
        style.hasWallpaper ? Colors.white.withOpacity(0.92) : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Theme(
        // 去掉 ExpansionTile 展开时的默认高亮背景，保持面板底色一致
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ZPanel(style: style, children: [
          ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            iconColor: style.subColor,
            collapsedIconColor: style.subColor,
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kZAccent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: kZAccent),
            ),
            title: Text(
              S.t(title),
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: style.titleColor,
              ),
            ),
            children: [
              ...steps.asMap().entries.map((e) {
                final raw = S.t(e.value);
                // 以空格开头的行是配置片段（如 "   enable-rcon=true"），用等宽字体
                final isCode = e.value.startsWith(' ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.key + 1}.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: kZAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCode ? raw.trim() : raw,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: textColor,
                            fontFamily: isCode ? 'monospace' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kZAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: tips
                        .map((t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                S.t(t),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  color: style.subColor,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}
