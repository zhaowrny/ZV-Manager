# Gitee Go 流水线配置说明

## 文件位置

```
.workflow/flutter-ci.yml
```

Gitee Go 约定：仓库根目录 `.workflow/` 下的 yml 即为流水线定义，支持多个文件（每个文件是一条流水线）。

## 一、先决条件（必须手动做，CI 不会自己启动）

1. **账号绑定手机号**
   Gitee Go 依赖云原生弹性调度，未绑手机号无法开通。

2. **开通 Gitee Go**
   仓库页 → 顶部「服务」→「Gitee Go」→ 开通。
   免费额度：单仓库 200 分钟（永久）+ 个人每月 500 分钟。

3. **创建流水线并选择「导入已有配置」**
   开通后会引导新建流水线，选择从 `.workflow/flutter-ci.yml` 导入。
   如果页面没有自动识别，手动选「自定义 / 代码视图」粘贴该文件内容。

> 注意：只把 yml 推到仓库**不会自动生效**，必须在 Gitee Go 页面里完成一次绑定。

## 二、这条流水线做什么

| 阶段 | 步骤 | 失败即中断 |
| --- | --- | --- |
| `analyze` | 安装 Flutter 3.38.1 → `pub get` → `flutter analyze` → `flutter test` | 是 |
| `build` | `flutter build apk --debug` → 归档 `app-debug.apk` | 是 |

触发条件：

- push 到 `main`、`dev`、`feat/*`、`fix/*`、`ci/*`
- 对 `main` 提 PR

## 三、为什么锁 Flutter 3.38.1

项目工具链是新的：

| 项 | 版本 |
| --- | --- |
| AGP | 9.3.1 |
| Gradle | 9.8 |
| compileSdk | `release(37) { minorApiLevel = 2 }` |
| buildTools | 37.0.0 |
| JDK | 17 |

`compileSdk { version = release(37) {...} }` 是 Flutter 3.35 之后才支持的写法，旧版 Flutter 的 Gradle 插件解析不了，会直接报错。所以 CI 必须用 3.38.1 或更高。

**如果构建报「compileSdk 语法不识别」，说明该节点 Flutter 版本低于 3.35**，把 `FLUTTER_VERSION` 往上调即可。

## 四、为什么只构建 debug 包

`android/key.properties` 与 keystore 都在 `.gitignore` 中（这是对的，签名文件绝不能进仓库）。CI 环境没有签名材料，`flutter build apk --release` 会因 `storeFile` 为空而失败。

debug 包已足够验证 CI 的核心目标：**代码能编译、Gradle 能跑通**。

若以后要让 CI 出正式包，正确做法是：

1. 把 keystore 转 base64 存到 Gitee「仓库设置 → 环境变量 / 密钥」
2. 在脚本里解码回 `android/app/release.jks`
3. 用环境变量生成 `key.properties`
4. 再执行 `--release --split-per-abi`

这件事建议等流水线先跑通再做，一次改一处。

## 五、已知不确定点（首次运行可能踩到）

| 风险 | 说明 | 应对 |
| --- | --- | --- |
| 构建节点无 Android SDK | Gitee Go 的 `shell@agent` 基于宿主机/Docker 镜像，官方文档未明确列出预装工具 | 看日志里 `sdkmanager` / `ANDROID_HOME`；缺就用 `cmdline-tools` 自装 |
| 首次下载 Flutter 慢或超时 | `git clone` GitHub 源，国内节点不稳 | 改用 Gitee 镜像或缩短超时 |
| 200 分钟额度消耗快 | 首次全量构建含 SDK 下载，可能吃掉大半额度 | 先只跑 `analyze` 阶段，通了再开 `build` |

**建议第一步只跑 `analyze` 阶段**：把 `stages` 里的 `build` 整段注释掉，先确认 Flutter 能装上、analyze 和 test 能过。这一步最快暴露环境问题，也最省额度。跑通后再把 `build` 打开。

## 六、拿到结果后

- 绿了：以后每次 push 都会自动检查，PR 页面能看到状态
- 红了：把红字日志贴出来，主要看 `prepare` 和第一步，多半是 SDK 路径或版本问题

## 七、顺带建议：提交 pubspec.lock

当前 `.gitignore` 里有这一行：

```
pubspec.lock
```

应用型项目（有明确发布目标，不是库）通常应该提交 `pubspec.lock`，否则每次 CI 都可能解析出不同的依赖小版本，出现「昨天能过今天挂」。这条不影响本次配置，但值得一并改掉。

如果要改：删掉 `.gitignore` 里那一行，执行 `flutter pub get` 生成后提交。
