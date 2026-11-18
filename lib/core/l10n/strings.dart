// 轻量 i18n：集中式文案翻译表 + Text 包装组件 + 模板插值。
// 用法：静态文案 Text('取消') → T('取消')；参数文案 S.f('在线 · {0}ms', [ms])。
// 英文模式下命中映射表返回英文，未收录自动回退中文，不会出现空白文案。
import 'package:flutter/material.dart';

class S {
  S._();

  /// 是否英文模式（由 LanguageProvider 同步）。
  static bool en = false;

  static const Map<String, String> _en = {
    // ---- 通用 ----
    '取消': 'Cancel',
    '确定': 'OK',
    '删除': 'Delete',
    '编辑': 'Edit',
    '保存': 'Save',
    '刷新': 'Refresh',
    '同步': 'Sync',
    '上传': 'Upload',
    '搜索': 'Search',
    '知道了': 'Got it',
    '添加': 'Add',
    '无': 'None',
    '未知': 'Unknown',
    // ---- 底部导航 ----
    '服务器': 'Servers',
    '控制台': 'Console',
    '玩家': 'Players',
    '模组': 'Mods',
    '终端': 'Terminal',
    '我的': 'Me',
    // ---- Dashboard ----
    '添加服务器': 'Add Server',
    '还没有服务器，点击下方按钮添加吧': 'No servers yet. Tap the button below to add one.',
    '请先在「服务器」页选择一台服务器': 'Select a server on the Servers tab first',
    '在线': 'Online',
    '离线': 'Offline',
    '在线人数': 'Players online',
    '磁盘': 'Disk',
    '需 SSH 终端': 'Needs SSH terminal',
    '下载中心': 'Downloads',
    'Modrinth 搜索 · 镜像加速': 'Modrinth search · mirror boost',
    '远程终端': 'Remote Terminal',
    'SSH Shell': 'SSH Shell',
    '模组管理': 'Mod Manager',
    '上传 / 删除 / 查看依赖': 'Upload / delete / view dependencies',
    '编辑服务器': 'Edit Server',
    '删除服务器': 'Delete Server',
    '刷新状态': 'Refresh status',
    '未选择': 'None',
    '切换': 'Switch',
    // ---- 服务器表单 ----
    '服务器名称': 'Server name',
    '例如: 我的生存服': 'e.g. My survival server',
    '主机地址': 'Host',
    'IP 或域名': 'IP or domain',
    'RCON 端口': 'RCON port',
    '默认 25575': 'default 25575',
    'RCON 密码': 'RCON password',
    'SSH 连接（可选）': 'SSH connection (optional)',
    '用于模组插件管理与远程终端': 'For mod management & remote terminal',
    'SSH 端口': 'SSH port',
    '默认 22': 'default 22',
    'SSH 用户名': 'SSH username',
    '例如 root': 'e.g. root',
    'SSH 密码': 'SSH password',
    // ---- 模组管理 ----
    '依赖仓库': 'Dependency Repo',
    '按名称': 'By name',
    '按大小': 'By size',
    '按修改时间': 'By mtime',
    '目录下没有 .jar 文件': 'No .jar files in this directory',
    '详情': 'Details',
    '重命名': 'Rename',
    '上传 jar': 'Upload jar',
    '确认删除': 'Confirm delete',
    '文件名': 'File',
    '大小': 'Size',
    '修改时间': 'Modified',
    '作者': 'Authors',
    '元数据来源': 'Metadata source',
    '描述': 'Description',
    '硬依赖': 'Hard dependencies',
    '软依赖': 'Soft dependencies',
    // ---- 依赖仓库 ----
    '该模组依赖：': 'Depends on:',
    '被以下模组依赖：': 'Required by:',
    '缺失依赖（可一键补齐）：': 'Missing dependencies (one-click fetch):',
    '从 Modrinth 补齐': 'Fetch from Modrinth',
    '版本冲突 / 重复 jar': 'Conflicts / duplicate jars',
    '未发现重复': 'No duplicates found',
    '重复检测': 'Duplicate check',
    '点击「同步」增量扫描服务器 mods/plugins 并建立依赖索引':
        'Tap Sync to incrementally scan server mods/plugins and build the dependency index',
    '索引为空，先点击「同步」': 'Index is empty. Tap Sync first',
    '（该服务器未配置 SSH，无法同步）': '(No SSH on this server; sync unavailable)',
    // ---- 下载中心 ----
    '搜索下载': 'Search',
    '{0} · 依赖 {1} · 软依赖 {2}': '{0} · deps {1} · soft deps {2}',
    '已清除背景': 'Background cleared',
    '检查更新失败：{0}': 'Update check failed: {0}',
    '正在获取版本列表...': 'Loading version list...',
    '获取更新信息失败': 'Failed to get update info',
    '任务队列': 'Queue',
    '搜索 Modrinth 模组/插件，如 sodium': 'Search Modrinth mods/plugins, e.g. sodium',
    '插件': 'Plugins',
    'MC 版本': 'MC version',
    '加载器': 'Loader',
    '输入关键词开始搜索': 'Type a keyword to start searching',
    '没有结果': 'No results',
    '暂无下载任务': 'No download tasks',
    '暂停': 'Pause',
    '继续': 'Resume',
    '重试': 'Retry',
    '排队中': 'Queued',
    '下载中': 'Downloading',
    '已暂停': 'Paused',
    '已完成': 'Completed',
    '失败': 'Failed',
    '已取消': 'Canceled',
    // ---- 下载与镜像设置 ----
    '镜像线路': 'Mirror',
    'MCIM 国内镜像（推荐）': 'MCIM China mirror (recommended)',
    'mod.mcimirror.top，无需科学上网': 'mod.mcimirror.top, no VPN needed',
    'Modrinth 官方': 'Modrinth official',
    '直连官方源，适合海外网络': 'Direct official source, best overseas',
    '自定义镜像': 'Custom mirror',
    '使用自建/第三方镜像地址': 'Use your own/third-party mirror URL',
    '一键测速并选择最快线路': 'Speed test & pick fastest',
    '自动在官方与镜像之间选择延迟最低的线路':
        'Auto-pick lowest latency between official & mirrors',
    '下载队列': 'Queue',
    '同时下载任务数': 'Concurrent downloads',
    '说明：下载完成的文件保存在应用目录 downloads/ 下；':
        'Note: finished files are saved in the app directory downloads/;',
    '若服务器配置了 SSH，会自动上传到对应服务器的 mods/plugins 目录。':
        'if the server has SSH, they are auto-uploaded to its mods/plugins directory.',
    '自定义镜像地址': 'Custom mirror URL',
    // ---- 终端 ----
    '新会话': 'New session',
    '选择一台服务器开始会话': 'Pick a server to start a session',
    '没有配置 SSH 的服务器。\n\n请在「服务器」页编辑服务器，开启 SSH 后即可使用终端。':
        'No servers with SSH configured.\n\nEdit a server on the Servers tab and enable SSH to use the terminal.',
    // ---- 设置 ----
    '设置': 'Settings',
    '外观主题': 'Theme',
    '应用背景': 'Background',
    '未设置': 'Not set',
    '视频声音': 'Video sound',
    '开启后背景视频将播放声音': 'Play sound for background video',
    '下载与镜像设置': 'Download & mirror settings',
    '镜像线路、测速选线、同时下载任务数': 'Mirror, speed test, concurrent downloads',
    '使用教程': 'Tutorials',
    '如何开启 RCON / SSH、模组管理、下载与终端':
        'How to enable RCON / SSH, mods, downloads & terminal',
    '检查更新': 'Check updates',
    '关于': 'About',
    '开发者：Z有3笔，协作者：venti1112': 'Developer: Z有3笔, Collaborator: venti1112',
    '开源许可': 'Open-source licenses',
    '语言 / Language': '语言 / Language',
    '跟随系统 / System': '跟随系统 / System',
    '简体中文': '简体中文',
    'English': 'English',
    '选择图片': 'Pick image',
    '选择视频': 'Pick video',
    '清除背景': 'Clear background',
    '界面显示语言': 'Display language',
    '选择一张图片或一段视频作为应用背景':
        'Pick an image or a video as the app background',
    '使用教程（模组/终端等）': 'Tutorials (mods / terminal etc.)',
    // ---- 模板插值 ----
    '服务器「{0}」已断开连接！': 'Server "{0}" disconnected!',
    '确定要删除「{0}」吗？仅删除本应用中的连接配置，不影响服务器本身。':
        'Delete "{0}"? Only removes the connection profile in this app; the server itself is unaffected.',
    '在线 · {0}ms · {1} 人': 'Online · {0}ms · {1} players',
    'RCON 连接失败：{0}': 'RCON connection failed: {0}',
    '{0}不能为空': '{0} cannot be empty',
    '在线 · {0}ms': 'Online · {0}ms',
    '版本 {0}': 'Version {0}',
    '加载失败：{0}': 'Load failed: {0}',
    '上传失败：{0}': 'Upload failed: {0}',
    '确定要删除 {0} 吗？此操作不可恢复。': 'Delete {0}? This cannot be undone.',
    '{0} 未配置 SSH': '{0} has no SSH configured',
    '模组管理需要 SSH 连接。请在「服务器」页编辑该服务器，\n开启 SSH 并填写用户名和密码。':
        'Mod management needs SSH. Edit the server on the Servers tab,\nenable SSH and fill in username & password.',
    '已下载 {0}（{1}）': 'Downloaded {0} ({1})',
    '补齐失败：{0}': 'Fetch failed: {0}',
    '未找到 {0}': '{0} not found',
    '获取版本失败：{0}': 'Failed to fetch versions: {0}',
    '已加入下载队列：{0}': 'Queued: {0}',
    '搜索失败：{0}': 'Search failed: {0}',
    '选择 {0} 的版本': 'Choose a version of {0}',
    '该版本没有可用文件': 'No files for this version',
    '上次测速：{0}ms（{1}）': 'Last test: {0}ms ({1})',
    '已选择最快线路：{0}（{1}ms）': 'Fastest route: {0} ({1}ms)',
    '当前：{0} 个（越大越占带宽，建议 1-3）':
        'Now: {0} (more uses more bandwidth; 1-3 recommended)',
    '{0} 个版本共存': '{0} versions coexist',
    '同步失败：{0}': 'Sync failed: {0}',
    '当前版本: {0}': 'Current version: {0}',
    '已设置 {0}': 'Set: {0}',
    '{0} 视频': '{0} video',
    '{0} 图片': '{0} image',
    '壁纸已更新': 'Wallpaper updated',
    '背景已更新 ': 'Background updated ',
    '已恢复默认壁纸': 'Default wallpaper restored',
    '保存失败，请重试': 'Save failed, please retry',
    '壁纸设置保存失败，请重试': 'Failed to save wallpaper settings, please retry',
    '背景已更新': 'Background updated',
    '   rcon.password=你的RCON密码': '   rcon.password=your RCON password',
    '1. SSH 终端拥有服务器完全控制能力，您执行的任何命令（含删除文件、重启系统）后果由您自行承担。':
        '1. The SSH terminal grants full control of your server. You bear all consequences of any command you run (including deleting files or rebooting the system).',
    '1. 下载功能数据来自 Modrinth 公开接口及其镜像线路（如 MCIM）。镜像线路由第三方维护，其可用性与安全性不由开发者控制。':
        '1. Download data comes from the public Modrinth API and its mirrors (e.g. MCIM). Mirrors are maintained by third parties; the developer does not control their availability or safety.',
    '1. 仅管理您有权管理的服务器。严禁连接、探测、控制任何未获授权的第三方服务器——未经授权访问计算机系统属于违法行为。':
        '1. Only manage servers you are authorized to. Connecting to, probing or controlling any unauthorized third-party server is strictly prohibited — unauthorized access to computer systems is illegal.',
    '1. 本软件不收集、不上传您的任何个人数据，全部数据保存在设备本地，卸载即删除。':
        '1. This app does not collect or upload any personal data. All data is stored locally on your device and removed on uninstall.',
    '1. 本软件为免费开源软件，不提供商业担保。在法律允许的最大范围内，开发者不对因使用或无法使用本软件造成的任何直接或间接损失负责（包括数据丢失、服务器宕机、存档损坏、经济损失）。':
        '1. This software is free and open source, provided without commercial warranty. To the maximum extent permitted by law, the developer is not liable for any direct or indirect loss arising from use or inability to use (including data loss, server downtime, world corruption or financial loss).',
    '1. 本软件按开源协议发布，可依协议使用、修改和分发；"ZV Manager"名称与图标版权归作者所有。':
        '1. This software is released under an open source license and may be used, modified and distributed accordingly. The name and logo "ZV Manager" are copyrighted by the author.',
    '1. 连接凭据（RCON 密码、SSH 用户名/密码等）仅保存在您的设备本地（加密存储），本软件无云端账号系统，不会将凭据上传至开发者或任何第三方。':
        '1. Connection credentials (RCON password, SSH username/password, etc.) are stored only on your device (encrypted). This app has no cloud account system and never uploads credentials to the developer or any third party.',
    '2. Minecraft 是 Mojang Studios 的商标，本软件与 Mojang、微软无任何隶属关系。':
        '2. Minecraft is a trademark of Mojang Studios. This software is not affiliated with Mojang or Microsoft.',
    '2. 因第三方服务（Modrinth、镜像源、托管商、网络）变更或故障导致的异常，开发者不承担责任。':
        '2. The developer is not responsible for issues caused by changes or failures of third-party services (Modrinth, mirrors, hosting providers, networks).',
    '2. 应用仅联网检查更新（Gitee 发布页）及访问 Modrinth/镜像接口，无其他网络请求。':
        '2. The app only connects to the network to check updates (Gitee releases) and access the Modrinth/mirror APIs; there are no other network requests.',
    '2. 建议不要以 root 账户长期连接，执行不熟悉的命令前请先确认其作用。':
        '2. Avoid staying connected as root for long periods, and confirm what a command does before running unfamiliar ones.',
    '2. 第三方模组/插件可能影响服务器稳定性，安装前请备份重要数据；"依赖仓库"查询结果仅供参考。':
        '2. Third-party mods/plugins may affect server stability. Back up important data before installing; "Dependency Index" results are for reference only.',
    '2. 请妥善保管设备与凭据，因主动泄露、设备被他人使用、越狱/Root 等造成的损失由您自行承担。':
        '2. Keep your device and credentials safe. Losses caused by voluntary disclosure, unauthorized device use, jailbreak/Root, etc. are borne by you.',
    '2. 遵守《网络安全法》《计算机信息系统安全保护条例》等法律法规及 Minecraft EULA 与服务器规则。':
        '2. Comply with applicable laws and regulations (e.g. the Cybersecurity Law) as well as the Minecraft EULA and server rules.',
    '3. 不得利用本软件传播违法信息、破坏他人服务器、恶意攻击或盗取数据。':
        '3. Do not use this software to spread unlawful information, sabotage others\' servers, launch attacks or steal data.',
    '3. 仅连接您拥有管理权限的服务器，并使用强密码、定期更换。':
        '3. Only connect to servers you administer, using strong passwords changed regularly.',
    '3. 命令历史仅保存在设备本地，可在应用内清除，本软件不做任何云端记录。':
        '3. Command history is stored locally only, can be cleared in the app, and is never recorded in the cloud.',
    '4. 下载中心获取的模组/插件版权归原作者所有，请遵守对应开源协议，不得下载、分发盗版或破解内容。':
        '4. Mods/plugins obtained from the Download Center belong to their authors. Follow the corresponding licenses; pirated or cracked content must not be downloaded or distributed.',
    'Fabric 模组放 mods 目录；Paper/Spigot 插件放 plugins 目录':
        'Fabric mods go in the mods directory; Paper/Spigot plugins go in the plugins directory',
    'Q：TPS 显示 —？→ 原版服务端不支持 tps 命令，Paper/Purpur 等服务端才支持':
        'Q: TPS shows "—"? → Vanilla servers do not support the tps command; only Paper/Purpur and similar do',
    'Q：上传模组后不生效？→ 需要重启服务器':
        'Q: Mod upload not taking effect? → Restart the server',
    'Q：控制台能连但模组页提示无 SSH？→ 编辑服务器开启 SSH 并填好账号密码':
        'Q: Console connects but the mods page says no SSH? → Edit the server, enable SSH and fill in the credentials',
    'Q：连接失败？→ 检查防火墙是否放行端口、地址端口是否填对、服务器是否在线':
        'Q: Connection failed? → Check firewall rules for the port, verify address/port, and confirm the server is online',
    'Q：开了监控却收不到通知？→ 检查系统是否允许本应用通知、是否开了省电限制':
        'Q: Monitoring is on but no alerts? → Check that notifications are allowed for this app and battery saving is not restricting it',
    'SSH 拥有服务器完全控制权，请勿随意执行不熟悉的命令':
        'SSH grants full server control; do not run unfamiliar commands carelessly',
    'SSH 是服务器自带的远程管理服务，绝大多数独立服务器默认已开启（端口 22）':
        'SSH is a built-in remote management service, enabled by default on most standalone servers (port 22)',
    'ZV Manager 是一款 Minecraft 服务器远程管理工具，通过 RCON、SSH/SFTP 等协议连接到您有权管理的服务器，提供服务器控制、玩家管理、模组插件管理、文件下载与远程终端等功能。本软件按"现状"提供。':
        'ZV Manager is a remote management tool for Minecraft servers. It connects to servers you are authorized to manage via RCON, SSH/SFTP and other protocols, offering server control, player management, mod/plugin management, file downloads and a remote terminal. The software is provided "as is".',
    'ZV Manager：服务器页 → 编辑服务器 → 打开「SSH 连接」开关 → 填端口（默认 22）、用户名、密码 → 保存':
        'ZV Manager: Servers → Edit server → enable "SSH Connection" → fill in port (default 22), username and password → Save',
    'screen -r 可以进入服务器控制台会话（开服时用了 screen 的话）':
        'screen -r reattaches to the server console session (if you started the server inside screen)',
    '© 2026 ZV Team · 与 Mojang 无关':
        '© 2026 ZV Team · Not affiliated with Mojang',
    '一、如何开启 RCON（必配，控制台/玩家管理需要）':
        '1. How to enable RCON (required for console/player management)',
    '一、软件性质与用途': '1. Nature and Purpose of the Software',
    '七、状态监控与通知': '7. Status Monitoring and Notifications',
    '进入「我的」→ 设置 → 「状态监控」，打开总开关':
        'Open Me → Settings → "Status monitoring" and turn the switch on',
    '首次开启会申请通知权限（Android 13+），请点「允许」，否则提醒会被系统丢弃':
        'The first time you enable it, Android 13+ asks for notification permission — tap Allow, otherwise alerts are dropped',
    '按需开启「服务器离线 / 服务器恢复 / 玩家上线」三类提醒':
        'Enable the offline / recovered / player-join alerts you want',
    '「检查间隔」可选 30 秒 / 1 / 2 / 5 分钟，间隔越短发现越快、轮询压力越大':
        '"Check interval" can be 30 s / 1 / 2 / 5 min; shorter is faster but polls more',
    '点「立即检查一次」可手动验证 RCON 配置是否可用':
        'Tap "Check now" to verify the RCON configuration manually',
    '提醒依赖 App 进程存活：彻底关闭 App 或被系统省电策略限制时不会推送':
        'Alerts need the app process alive: nothing is pushed once the app is fully closed or restricted by battery saving',
    '八、常见问题': '8. FAQ',
    '七、数据与隐私': '7. Data and Privacy',
    '三、合法使用（重要）': '3. Lawful Use (Important)',
    '三、模组 / 插件管理怎么用': '3. Using Mod / Plugin Management',
    '上传后需重启服务器才会加载新模组（可在终端执行，或控制台发 stop 后重开）':
        'The server must be restarted after uploading to load new mods (via terminal, or send stop in console and start again)',
    '下载完成且配置了 SSH 时，会自动上传到服务器的 mods/plugins 目录':
        'When the download finishes and SSH is configured, files upload automatically to the server\'s mods/plugins directory',
    '不建议把 25575 端口直接暴露公网，强烈建议设置强密码':
        'Do not expose port 25575 directly to the public internet; a strong password is strongly recommended',
    '不确定的话：用电脑终端执行 ssh 用户名@服务器IP 试试能否登录':
        'If unsure: run ssh user@server-ip in a desktop terminal to test login',
    '九、守则变更': '9. Changes to This Agreement',
    '二、如何开启 SSH（模组管理 / 终端 / 下载自动上传需要）':
        '2. How to enable SSH (required for mod management / terminal / auto upload)',
    '二、账号与凭据安全': '2. Account and Credential Security',
    '云服务器/虚拟主机需在防火墙或安全组放行 rcon.port 端口':
        'For cloud servers/VPS, open rcon.port in the firewall or security group',
    '五、模组管理与下载功能说明': '5. Mod Management and Downloads',
    '五、远程终端': '5. Remote Terminal',
    '保存后重启服务器生效': 'Restart the server after saving for changes to take effect',
    '修改/添加以下三行：': 'Add or modify the following three lines:',
    '八、知识产权': '8. Intellectual Property',
    '六、依赖仓库（查询模组依赖）': '6. Dependency Index (query mod dependencies)',
    '六、免责声明': '6. Disclaimer',
    '前提：该服务器已配置 SSH': 'Prerequisite: SSH is configured for this server',
    '十、其他': '10. Miscellaneous',
    '同意并进入': 'Agree and Continue',
    '命令历史只保存在手机本地，可放心使用':
        'Command history is stored on your phone only; use it with confidence',
    '四、SSH / 终端功能风险提示': '4. SSH / Terminal Risk Notice',
    '四、下载中心与镜像加速': '4. Download Center and Mirror Acceleration',
    '回到 ZV Manager：服务器页 → 添加/编辑服务器，填入主机地址、端口（默认 25575）和 RCON 密码':
        'Back in ZV Manager: Servers → Add/Edit server, fill in the host, port (default 25575) and RCON password',
    '国内网络慢时：点右上角测速图标 →「一键测速并选择最快线路」，或改用自定义镜像地址':
        'If the network is slow in China: tap the speed-test icon in the top right → "Test and pick the fastest route", or use a custom mirror URL',
    '在服务器目录找到 server.properties 文件（与启动 jar 同目录）':
        'Find server.properties in the server directory (same folder as the startup jar)',
    '底部快捷键栏：Tab 补全、Ctrl+C 中断、Ctrl+D 退出、↑↓ 调历史，以及 htop / df -h / screen -r 常用命令':
        'Bottom shortcut bar: Tab completion, Ctrl+C interrupt, Ctrl+D exit, ↑↓ history, plus htop / df -h / screen -r quick commands',
    '开发者可能随版本更新修订本守则并在应用内展示；不同意修订内容请停止使用，继续使用即视为接受。':
        'The developer may revise this agreement with version updates and display it in the app. If you disagree, stop using the app; continued use constitutes acceptance.',
    '我已阅读并同意《用户守则》': 'I have read and agree to the User Agreement',
    '拿到 SSH 用户名（如 root）和密码': 'Obtain the SSH username (e.g. root) and password',
    '断网会自动重连（最多 3 次）':
        'Reconnects automatically after network loss (up to 3 times)',
    '有的托管商需要先在控制台开启 SSH/SFTP 功能':
        'Some hosting providers require enabling SSH/SFTP in their control panel first',
    '本守则最终解释权归 ZV Team 所有。如有疑问或发现漏洞，欢迎通过 Gitee 仓库（gitee.com/driftinblock/zvmanager）或官方 QQ 群反馈。':
        'The final interpretation of this agreement belongs to ZV Team. For questions or vulnerability reports, reach us via the Gitee repo (gitee.com/driftinblock/zvmanager) or the official QQ group.',
    '本页教您一步步开启并使用 ZV Manager 的各项功能。':
        'This guide walks you through enabling and using ZV Manager step by step.',
    '点「上传 jar」从手机选择文件上传；长按/点菜单可删除、重命名':
        'Tap "Upload jar" to pick a file from your phone; long-press/menu to delete or rename',
    '点「同步」扫描服务器 mods/plugins，建立本地依赖索引':
        'Tap "Sync" to scan the server\'s mods/plugins and build the local dependency index',
    '点击任意模组查看：它依赖什么、被谁依赖、缺失哪些依赖':
        'Tap any mod to see what it depends on, what depends on it, and which dependencies are missing',
    '点击文件名可查看详情：模组名、版本、作者、依赖':
        'Tap a file name for details: mod name, version, author, dependencies',
    '点右上角重复检测按钮重复安装 / 版本冲突的 jar':
        'Tap the duplicate-check button in the top right to find duplicated or conflicting jars',
    '点结果选版本即可加入下载队列，支持暂停/继续/取消':
        'Tap a result, pick a version and add it to the download queue; pause/resume/cancel supported',
    '版本 v2.0 · 下载、安装或使用本软件，即视为您已阅读并同意本守则全部条款。':
        'Version v2.0 · By downloading, installing or using this software, you are deemed to have read and agreed to all terms of this agreement.',
    '版本要和 MC 版本、加载器匹配，否则服务器起不来':
        'Versions must match the MC version and loader, or the server will fail to start',
    '用户守则': 'User Agreement',
    '等同于电脑上的 SSH 终端，可以执行任意命令':
        'Works like a desktop SSH terminal; you can run any command',
    '缺失依赖可一键从 Modrinth 下载补齐':
        'Missing dependencies can be downloaded from Modrinth with one tap',
    '请仔细阅读守则（{0}s）': 'Please read carefully ({0}s)',
    '请先滑动阅读至守则底部': 'Please scroll to the bottom of the agreement first',
    '请阅读至守则底部': 'Please read to the bottom of the agreement',
    '输入关键词搜索 Modrinth 上的模组/插件，可用 MC 版本、加载器筛选':
        'Search Modrinth mods/plugins by keyword; filter by MC version and loader',
    '进入「服务器」页 → 下载中心（或首页快捷入口）':
        'Go to the "Servers" page → Download Center (or the home shortcut)',
    '进入「模组」页签 → 右上角依赖仓库':
        'Go to the "Mods" tab → Dependency Index in the top right',
    '进入「模组」页签，顶部切换 mods（模组）/ plugins（插件）目录':
        'In the "Mods" tab, switch between mods and plugins directories at the top',
    '进入「终端」页签，点右上角 + 新建会话并选择服务器':
        'In the "Terminal" tab, tap + in the top right to create a session and pick a server',
    '部分面板服 / 虚拟主机只提供网页面板，不提供 SSH，此时模组和终端功能不可用（入口会提示）':
        'Some panel-hosted/virtual hosts offer only a web panel without SSH; mod management and terminal are unavailable then (the entry will tell you)',
    '阅读倒计时 {0} 秒…': 'Reading countdown {0}s…',
    '默认使用 MCIM 国内镜像，无需科学上网':
        'Uses the MCIM China mirror by default; no VPN needed',
    '清空输出': 'Clear output',
    '输入命令后按回车执行': 'Type a command and press Enter',
    '当前': 'Active',
    '运行状态': 'Status',
    '搜索 Modrinth 模组，镜像加速下载': 'Search Modrinth mods with mirror acceleration',
    '通过 SSH 执行任意命令': 'Run any command over SSH',
    '上传、删除、查看依赖': 'Upload, delete, inspect dependencies',
    '{0} 个文件': '{0} files',
    '排序': 'Sort',
    // ---- ZL2 下载页 ----
    '共 {0} 个结果': '{0} results',
    '共 {0} 个任务': '{0} tasks',
    '在上方「搜索下载」页签中选择模组即可开始': 'Pick a mod in the Search tab above to get started',
    '在线公告': 'Online notice',
    '在线列表': 'Online list',
    '晴天': 'Clear weather',
    '查看种子': 'Show seed',
    '白名单列表': 'Whitelist',
    '立即存档': 'Save now',
    '设为白天': 'Set day',
    '设为黑夜': 'Set night',
    '关闭': 'Close',
    '更新失败：{0}': 'Update failed: {0}',
    '未找到可下载的安装包': 'No downloadable package found',
    '版本号': 'Version',
    '更新时间': 'Release time',
    '当前版本': 'Current version',
    '更新发布页': 'Release page',
    '更新内容': 'Release notes',
    '更新': 'Updates',
    '修复': 'Fixes',
    '查看发布页': 'View release page',
    '忽略': 'Later',
    '本次更新暂无详细说明': 'No detailed release notes.',
    '完整的更新日志': 'Full changelog',
    '更新日志': 'Changelog',
    '相关链接': 'Related link',
    '正在下载更新': 'Downloading update',
    '正在下载，请稍候…': 'Downloading, please wait…',
    '立即更新': 'Update now',
    '例如：save-all': 'e.g. save-all',
    '例如：立即存档': 'e.g. Save now',
    '发送': 'Send',
    '命令': 'Command',
    '完成': 'Done',
    '快速命令': 'Quick Commands',
    '新增': 'Add',
    '暂无预设，点击下方按钮添加': 'No presets yet. Tap the button below to add one',
    '服务器控制台': 'Server Console',
    '标签': 'Label',
    '标签和命令都不能为空': 'Label and command cannot be empty',
    '点击标签一键发送，点击右侧按钮编辑':
        'Tap a tag to send instantly; tap the button on the right to edit',
    '玩家管理': 'Players',
    '管理快速命令': 'Manage quick commands',
    '输入命令...': 'Enter command...',
    '{0}失败：{1}': '{0} failed: {1}',
    '{0}完成：成功 {1} 人': '{0} done: {1} succeeded',
    '，失败 {0} 人': ', {0} failed',
    '全选': 'Select all',
    '原因（可选）': 'Reason (optional)',
    '取消 OP': 'Deop',
    '封禁': 'Ban',
    '将对「{0}」执行该操作': 'This will run the action on "{0}"',
    '批量操作': 'Batch actions',
    '操作': 'Actions',
    '暂无在线玩家': 'No players online',
    '确认': 'Confirm',
    '给予 OP': 'Op',
    '踢出': 'Kick',
    '退出选择': 'Exit selection',
    '无法连接': 'Cannot connect',
    '更多操作': 'More actions',
    '正在获取状态': 'Fetching status',
    '正在连接...': 'Connecting...',
    '确定要删除服务器「{0}」吗？': 'Delete server "{0}"?',
    '连接失败：{0}': 'Connection failed: {0}',
    '从相册选择图片作为应用背景': 'Pick an image from the gallery as the app background',
    '壁纸设置': 'Wallpaper',
    '当前为默认壁纸': 'Using the default wallpaper',
    '恢复默认': 'Restore default',
    '恢复默认壁纸': 'Restore default wallpaper',
    '点击下方「选择图片」自定义': 'Tap "Choose image" below to customize',
    '确定要恢复默认壁纸吗？': 'Restore the default wallpaper?',
    '确认重置': 'Confirm reset',
    '自定义壁纸已应用': 'Custom wallpaper applied',
    '选择壁纸': 'Choose wallpaper',
    '重置': 'Reset',
    '重置壁纸': 'Reset wallpaper',
    '发现新版本': 'New version available',
    '已是最新': 'Up to date',
    '当前版本 {0} 已是最新': 'Current version {0} is up to date',
    '正在下载安装包…': 'Downloading package…',
    '下载中：{0}%': 'Downloading: {0}%',
    '(无响应)': '(no response)',
    '{0}：{1}': '{0}: {1}',
    '无响应': 'No response',
    '{0} 名玩家': '{0} players',
    '已选 {0} 人': '{0} selected',
    '检测中': 'Checking',
    '点击重试': 'Tap to retry',
    '{0} 人': '{0} players',
    '进入控制台': 'Open console',
    '该项目没有可用版本': 'No available versions for this project',
    '没有可用文件': 'No available files',
    '未知名称': 'Unknown name',
    '网络错误': 'Network error',
    'MCIM 国内镜像 (mcimirror.top)': 'MCIM China mirror (mcimirror.top)',
    '自定义 ({0})': 'Custom ({0})',
    'SFTP 未连接，请先调用 connect()': 'SFTP not connected; call connect() first',
    'RCON 未连接或未认证': 'RCON not connected or not authenticated',
    '新增 {0} · 更新 {1} · 未变化 {2} · 共 {3} 条':
        'Added {0} · Updated {1} · Unchanged {2} · {3} total',
    '[警告] 连接断开，正在重连...': '[Warning] Connection lost, reconnecting...',
    '[信息] 重连成功': '[Info] Reconnected',
    '[错误] {0}': '[Error] {0}',
    '建议：{0}': 'Suggestions: {0}',
    '新增预设': 'Add preset',
    '编辑预设': 'Edit preset',
    '给予OP': 'Op',
    '取消OP': 'Deop',
    '端口不能为空': 'Port cannot be empty',
    '端口范围 1-65535': 'Port range 1-65535',
    '还没有添加服务器': 'No servers added yet',
    '填入主机地址与 RCON 密码，即可在手机上管理':
        'Enter the host and RCON password to manage it from your phone',
    '视频': 'Video',
    '图片': 'Image',
    '连接凭据已加密保存，仅存于本机':
        'Credentials are encrypted and stored on this device only',
    '服务器日志': 'Server Logs',
    '通过 SSH 查看服务器 logs 目录日志输出': 'View server logs directory output via SSH',
    '请先在「服务器」页配置 SSH 连接':
        'Configure an SSH connection on the Servers page first',
    '选择服务器（需开启 SSH）': 'Select server (SSH required)',
    '日志目录路径': 'Logs directory path',
    '例如 /root/logs': 'e.g. /root/logs',
    '自动刷新（每 5 秒）': 'Auto refresh (every 5s)',
    '目录下没有日志文件': 'No log files in this directory',
    '读取失败：{0}': 'Failed to read: {0}',
    '自动刷新并跟随底部（每 5 秒）': 'Auto refresh & follow bottom (every 5s)',
    '卡片视图': 'Card view',
    '进度条视图': 'Progress bar view',
    '用户须知': 'User Notice',
    '查看用户守则全部条款': 'View all terms of the user agreement',
    '关于软件': 'About',
    '版本、检查更新、创造者与开源许可': 'Version, updates, creators and licenses',
    '我知道了': 'Got it',
    '创造者': 'Creators',
    'ZV Manager 是一款 Minecraft 服务器远程管理工具，本软件与 Mojang、微软无任何隶属关系。':
        'ZV Manager is a remote management tool for Minecraft servers. Not affiliated with Mojang or Microsoft.',
    '开发者 · Gitee: DriftinBlock': 'Developer · Gitee: DriftinBlock',
    '协作者 · Gitee: venti1112': 'Collaborator · Gitee: venti1112',
    // ---- ZL2 版式新增 ----
    '在线玩家 {0} 人': '{0} players online',
    '选择': 'Select',
    '底部': 'Bottom',
    '日志目录': 'Logs directory',
    '默认按 SSH 用户推导，可手动修改': 'Derived from the SSH user; edit if needed',
    '每 5 秒重新读取目录列表': 'Reload the file list every 5 seconds',
    '请选择一台已配置 SSH 的服务器': 'Select a server with SSH configured',
    '从 Gitee 获取最新版本': 'Fetch the latest version from Gitee',
    '查看本应用使用的第三方库许可': 'View third-party licenses used by this app',
    '支持作者 · 爱发电': 'Support us on Afdian',
    '通过爱发电支持项目开发': 'Support development via Afdian',
    '赞助链接待配置': 'Sponsor link not configured yet',
    '加入官方 QQ 群': 'Join our QQ group',
    '与开发者和其他用户交流': 'Chat with the developer and other users',
    '群号已复制，打开 QQ 搜索加群':
        'Group number copied — open QQ and search to join',
    // ---- 多主题 / 胶囊开关 ----
    '深色模式': 'Dark mode',
    '跟随系统': 'Follow system',
    '主题配色': 'Theme color',
    '开启后使用暗色界面': 'Use the dark interface',
    '跟随系统开启时由系统决定，关闭后可手动切换':
        'Follows the system; turn off Follow system to set it manually',
    '随系统的深色 / 浅色设置自动切换': 'Switch automatically with the system theme',
    '切换全站强调色与界面色调': 'Change the accent color across the app',
    'ZL2 绿': 'ZL2 Green',
    '海蓝': 'Ocean Blue',
    '星紫': 'Violet',
    '暖橙': 'Sunset Orange',
    '樱粉': 'Sakura Pink',
    // ---- 状态监控与通知 ----
    '状态监控': 'Status monitoring',
    '开启后定时检查服务器状态，并在变化时推送通知':
        'Periodically checks server status and pushes alerts on changes',
    '每 {0}检查一次 · 最近 {1}': 'Every {0} · last check {1}',
    '服务器离线提醒': 'Offline alerts',
    '服务器掉线时推送系统通知':
        'Send a system notification when a server goes offline',
    '服务器恢复提醒': 'Recovery alerts',
    '服务器重新上线时推送通知':
        'Send a notification when a server comes back online',
    '玩家上线提醒': 'Player join alerts',
    '有新玩家进入服务器时推送通知':
        'Send a notification when a player joins a server',
    '检查间隔': 'Check interval',
    '间隔越短发现越快，对服务器的轮询压力也越大':
        'Shorter intervals detect changes faster but poll the server more',
    '立即检查一次': 'Check now',
    '正在检查…': 'Checking…',
    '手动跑一轮检查，用来确认 RCON 配置是否可用':
        'Run one check manually to verify the RCON configuration',
    '30 秒': '30 s',
    '1 分钟': '1 min',
    '2 分钟': '2 min',
    '5 分钟': '5 min',
    '尚未检查': 'not yet',
    '检查完成：{0} 台服务器在线': 'Check complete: {0} server(s) online',
    '未获得通知权限，提醒可能无法显示，请到系统设置中允许通知':
        'Notification permission was not granted; alerts may not appear',
    '服务器离线': 'Server offline',
    '服务器恢复': 'Server recovered',
    '玩家上线': 'Player joined',
    '「{0}」已离线，可能已停止运行': '"{0}" is offline and may have stopped',
    '「{0}」已恢复在线': '"{0}" is back online',
    '「{0}」：{1} 进入服务器': '"{0}": {1} joined the server',
  };

  static String t(String zh) => en ? (_en[zh] ?? zh) : zh;

  /// 模板插值：S.f('在线 · {0}ms', [ms])
  static String f(String zh, List<Object> args) {
    var s = t(zh);
    for (var i = 0; i < args.length; i++) {
      s = s.replaceAll('{$i}', '${args[i]}');
    }
    return s;
  }
}

/// Text 的翻译包装：T('取消') 等价 Text(S.t('取消'))。
class T extends StatelessWidget {
  final String zh;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const T(this.zh,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) => Text(S.t(zh),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow);
}
