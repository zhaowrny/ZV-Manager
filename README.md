# ZV Manager

> 你的手机，就是服务器控制台

ZV Manager 是一款轻量、安全的 Minecraft 服务器远程管理工具。通过 RCON 协议，让你随时随地用手机管理你的服务器，无需打开电脑。

---

## 功能特性

| 模块 | 功能 | 状态 |
|------|------|------|
| 服务器管理 | 添加/编辑/删除服务器 | ✅ |
| 服务器管理 | 多服务器切换 | ✅ |
| 状态监控 | 实时在线人数 | ✅ |
| 状态监控 | TPS 监控 | ✅ |
| 玩家管理 | 查看玩家列表 | ✅ |
| 玩家管理 | 授予/撤销 OP | ✅ |
| 玩家管理 | 踢出/封禁玩家 | ✅ |
| 玩家管理 | 批量操作玩家 | ✅ |
| 控制台 | RCON 模式 | ✅ |
| 控制台 | 快速命令预设 | ✅ |
| 主题 | 浅色/深色/跟随系统 | ✅ |
| 壁纸 | 自定义壁纸 | ✅ |
| 数据 | 加密存储 | ✅ |
| 模组管理 | SFTP 浏览 mods/plugins 目录 | ✅ v2.0 新增 |
| 模组管理 | 上传/删除/重命名 jar | ✅ v2.0 新增 |
| 模组管理 | 解析 fabric.mod.json / plugin.yml 元数据（名称/版本/作者/依赖） | ✅ v2.0 新增 |
| 下载中心 | Modrinth 搜索与下载（支持 MC 版本/加载器筛选） | ✅ v2.0 新增 |
| 下载中心 | 多任务并发队列（默认 3）、断点续传、失败指数退避重试 | ✅ v2.0 新增 |
| 下载中心 | 镜像线路（MCIM 国内镜像 / 官方 / 自定义）+ 一键测速自动选线，镜像连接失败自动回退官方源 | ✅ v2.0 新增 |
| 下载中心 | 下载完成自动经 SFTP 上传到服务器对应目录 | ✅ v2.0 新增 |
| 终端 | SSH Shell（xterm 终端、快捷键栏、多会话标签、断线自动重连） | ✅ v2.0 新增 |
| UI | Dashboard 卡片式首页 + 底部导航（服务器/控制台/玩家/模组/终端/我的） | ✅ v2.0 新增 |
| UI | 全站 ZL2 风格（分组圆角面板 / 两行式设置行 / 圆形绿底勾选钮 / 透明沉浸顶栏） | ✅ v2.0 新增 |
| UI | 控制台日志级别着色（INFO 绿 / WARN 黄 / ERROR 红） | ✅ v2.0 新增 |
| 依赖仓库 | SQLite 依赖索引 + 增量同步 + 依赖树查询 + 缺失依赖一键补齐 + 重复检测 | ✅ v2.0 新增 |

## 技术栈

| 项目 | 说明 |
|------|------|
| **版本** | 2.0.3 |
| **框架** | Flutter 3.x |
| **语言** | Dart 3.x |
| **目标平台** | Android 7.0+ / Web |
| **通信协议** | RCON (Minecraft 远程控制协议) + SSH/SFTP (dartssh2) |
| **本地存储** | Shared Preferences + Flutter Secure Storage + SQLite (依赖索引) |
| **状态管理** | Provider |
| **主题** | Material 3 + ZL2 风格组件库（`core/widgets/z_widgets.dart`） |
| **网络** | Dio（Modrinth API / 镜像线路 / 下载队列） |
| **国际化** | 轻量 i18n（`core/l10n/strings.dart`，中 / 英） |

---

## 项目结构

```
lib/
├── main.dart                              # 应用入口
├── app.dart                               # MaterialApp 配置、全局壁纸层
├── core/
│   ├── l10n/
│   │   └── strings.dart                   # 轻量 i18n（S.t / S.f / T）
│   ├── services/
│   │   ├── dependency_index_service.dart  # 依赖索引（SQLite 增量同步 / 依赖树）
│   │   ├── download_manager.dart          # 下载队列（并发 / 断点续传 / 退避重试）
│   │   ├── jar_metadata.dart              # jar 元数据解析（fabric.mod.json / plugin.yml）
│   │   ├── mirror_service.dart            # 镜像线路（MCIM / 官方 / 自定义）+ 测速
│   │   ├── modrinth_api.dart              # Modrinth API 客户端（镜像故障回退官方）
│   │   ├── sftp_service.dart              # SFTP 文件传输
│   │   └── ssh_shell_service.dart         # SSH Shell 会话
│   ├── theme/
│   │   └── app_theme.dart                 # Material 3 主题 + ZL2 配色
│   ├── utils/
│   │   ├── background_service.dart        # 后台保活
│   │   ├── command_preset_service.dart    # 控制台命令预设
│   │   ├── rcon_client.dart               # RCON 客户端
│   │   ├── rcon_stream_parser.dart        # RCON 流解析
│   │   └── update_service.dart            # Gitee Release 更新检查 / 安装
│   └── widgets/
│       ├── background_widget.dart         # 全局壁纸背景（交叉淡入防闪）
│       ├── empty_state_page.dart          # 空态占位页
│       ├── user_agreement_dialog.dart     # 用户守则弹窗
│       └── z_widgets.dart                 # ZL2 公共组件库（ZPanel / ZRow / ZToggle / ZAppBar / ZSheetRow …）
├── data/
│   └── services/
│       └── secure_storage_service.dart    # 加密存储
├── features/
│   ├── console/
│   │   └── console_page.dart              # RCON 控制台（日志着色 / 预设命令）
│   ├── dashboard/
│   │   ├── dashboard_page.dart            # 首页（状态宫格 / 服务器列表 / 快捷入口）
│   │   └── server_picker_bar.dart         # 服务器切换条
│   ├── download/
│   │   └── download_page.dart             # 下载中心（Modrinth 搜索 + 任务队列）
│   ├── mod_manager/
│   │   ├── dependency_tree_page.dart      # 依赖树 / 缺失补齐 / 重复检测
│   │   ├── mod_detail_page.dart           # 模组详情
│   │   ├── mod_list_page.dart             # 模组 / 插件列表
│   │   └── mod_provider.dart              # 模组状态
│   ├── player_management/
│   │   ├── player_list_page.dart          # 玩家列表（OP / 踢出 / 封禁 / 批量）
│   │   └── player_service.dart            # 玩家数据服务
│   ├── server_list/
│   │   ├── server_card.dart               # 服务器卡片
│   │   ├── server_form_dialog.dart        # 添加 / 编辑弹窗（含 SSH 配置）
│   │   └── server_list_page.dart          # 服务器列表
│   ├── settings/
│   │   ├── about_page.dart                # 关于 / 检查更新
│   │   ├── download_settings_page.dart    # 下载设置（镜像线路 / 测速 / 并发）
│   │   ├── help_page.dart                 # 使用教程
│   │   ├── server_log_page.dart           # 服务器日志
│   │   ├── settings_page.dart             # 设置主页
│   │   └── wallpaper_settings.dart        # 壁纸设置
│   ├── shell/
│   │   └── main_shell.dart                # 底部导航壳（6 个 Tab）
│   └── terminal/
│       └── terminal_page.dart             # SSH 终端（xterm / 多会话 / 快捷键）
└── providers/
    ├── download_provider.dart             # 下载任务状态
    ├── language_provider.dart             # 语言状态
    ├── rcon_provider.dart                 # RCON 状态
    ├── server_provider.dart               # 服务器状态
    ├── theme_provider.dart                # 主题状态
    └── wallpaper_provider.dart            # 壁纸状态
```

顶层目录：

| 目录 | 说明 |
|------|------|
| `android/` `web/` | 各平台工程 |
| `assets/` | 图片 / 图标资源 |
| `docs/` | 用户守则等文档 |
| `test/` | 单元测试 |
| `third_party/dartssh2/` | 本地 dartssh2 副本（pubspec 以 path 依赖引入） |

---
