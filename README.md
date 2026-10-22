ZV Manager

你的手机，就是服务器控制台

ZV Manager 是一款轻量、安全的 Minecraft 服务器远程管理工具。通过 RCON 协议，让你随时随地用手机管理你的服务器，无需打开电脑。

---

功能特性

| 模块 | 功能 | 状态 |
|------|------|------|
| 服务器管理 | 添加/编辑/删除服务器 |
| 服务器管理 | 多服务器切换 |
| 状态监控 | 实时在线人数 |
| 状态监控 | TPS 监控 
| 玩家管理 | 查看玩家列表 
| 玩家管理 | 授予/撤销 OP 
| 玩家管理 | 踢出/封禁玩家 
| 玩家管理 | 批量操作玩家 
| 控制台 | RCON 模式 |
| 控制台 | 快速命令预设
| 主题 | 浅色/深色/跟随系统 
| 壁纸 | 自定义壁纸 
| 数据 | 加密存储 | 模组管理 | SFTP 浏览 mods/plugins 目录 | ✅ v2.0 新增 |
| 模组管理 | 上传/删除/重命名 jar | ✅ v2.0 新增 |
| 模组管理 | 解析 fabric.mod.json / plugin.yml 元数据（名称/版本/作者/依赖） | ✅ v2.0 新增 |
| 下载中心 | Modrinth 搜索与下载（支持 MC 版本/加载器筛选） | ✅ v2.0 新增 |
| 下载中心 | 多任务并发队列（默认 3）、断点续传、失败指数退避重试 | ✅ v2.0 新增 |
| 下载中心 | 镜像线路（MCIM 国内镜像 / 自定义）+ 一键测速自动选线 | ✅ v2.0 新增 |
| 下载中心 | 下载完成自动经 SFTP 上传到服务器对应目录 | ✅ v2.0 新增 |
| 终端 | SSH Shell（xterm 终端、快捷键栏、多会话标签、断线自动重连） | ✅ v2.0 新增 |
| UI | Dashboard 卡片式首页 + 底部导航（服务器/控制台/玩家/模组/终端/我的） | ✅ v2.0 新增 |
| UI | 控制台日志级别着色（INFO 绿 / WARN 黄 / ERROR 红） | ✅ v2.0 新增 |
| 依赖仓库 | SQLite 依赖索引 + 增量同步 + 依赖树查询 + 缺失依赖一键补齐 + 重复检测 | ✅ v2.0 新增 |

技术栈

| 项目 | 说明 |
|------|------|
| **框架** | Flutter 3.x |
| **语言** | Dart 3.x |
| **目标平台** | Android 7.0+ / Web |
| **通信协议** | RCON (Minecraft 远程控制协议) + SSH/SFTP (dartssh2) |
| **本地存储** | Shared Preferences + Flutter Secure Storage + SQLite (依赖索引) |
| **状态管理** | Provider |
| **主题** | Material 3 |

---

项目结构

```

lib/
├── main.dart                          # 应用入口
├── app.dart                           # MaterialApp 配置
├── core/
│   ├── theme/
│   │   └── app_theme.dart             # MD3 主题定义
│   ├── utils/
│   │   ├── rcon_client.dart           # RCON 客户端
│   │   └── update_service.dart        # 更新检查
│   └── widgets/
│       └── background_widget.dart     # 壁纸背景组件
├── data/
│   └── services/
│       └── secure_storage_service.dart # 加密存储
├── features/
│   ├── server_list/
│   │   ├── server_list_page.dart      # 服务器列表
│   │   └── server_form_dialog.dart    # 添加/编辑弹窗
│   ├── console/
│   │   └── console_page.dart          # 双模式控制台
│   ├── player_management/
│   │   └── player_list_page.dart      # 玩家管理
│   └── settings/
│       ├── settings_page.dart         # 设置页
│       └── wallpaper_settings.dart    # 壁纸设置
└── providers/
├── server_provider.dart           # 服务器状态
├── theme_provider.dart            # 主题状态
├── wallpaper_provider.dart        # 壁纸状态
└── rcon_provider.dart             # RCON 状态

```

---
