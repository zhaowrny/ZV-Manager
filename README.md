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
| 数据 | 加密存储 

技术栈

| 项目 | 说明 |
|------|------|
| **框架** | Flutter 3.x |
| **语言** | Dart 3.x |
| **目标平台** | Android 7.0+ / Web |
| **通信协议** | RCON (Minecraft 远程控制协议) |
| **本地存储** | Shared Preferences + Flutter Secure Storage |
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
