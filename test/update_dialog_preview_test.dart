import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zv_manager/core/theme/app_theme.dart';
import 'package:zv_manager/core/utils/update_info.dart';
import 'package:zv_manager/core/widgets/update_dialog.dart';

/// 预览测试默认跳过，避免普通测试运行时生成图片。
///
/// 运行方式：
///   UPDATE_DIALOG_PREVIEW=1 flutter test test/update_dialog_preview_test.dart
///
/// 生成的文件：
///   build/preview/update_dialog_dark.png
///   build/preview/update_dialog_light.png
final bool _previewEnabled =
    Platform.environment['UPDATE_DIALOG_PREVIEW'] == '1';

final _previewKey = GlobalKey();

late final String _cjkFontPath;

const _releaseNotes = '''
## 更新内容
* 同步flutter 3.47变更，更新版本
* docs: 补充页面层与玩家服务的方法级注释
* style: 主题改用 Material 3 tonal 色板与标准形状体系（参考 ZL2）
* style: 全面 UI 美化——统一圆角/配色/间距主题体系
* fix: 模组/终端页空状态改为统一引导页（带标题栏）
* fix: 移除控制台页右上角重复的玩家管理入口（与底部玩家页签重复）
* fix: Gradle 发行包改用腾讯镜像，修复国内下载超时

**完整的更新日志**: https://gitee.com/driftinblock/zvmanager/compare/v2.0.0...v2.0.1
''';

final _info = UpdateInfo(
  latestVersion: '2.0.1',
  downloadUrl: 'https://example.com/ZVManager-v2.0.1.apk',
  apkName: 'ZVManager-v2.0.1.apk',
  releaseNotes: _releaseNotes,
  releasedAt: DateTime(2026, 10, 27, 21, 56, 7),
  releasePageUrl:
      'https://gitee.com/driftinblock/zvmanager/releases/tag/v2.0.1',
);

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

String? _firstExisting(List<String> paths) {
  for (final path in paths) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

String? _materialIconsPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    // 从 Dart 可执行文件反推 Flutter SDK 根目录。
    '${File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path}'
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  return _firstExisting(candidates);
}

ThemeData _withPreviewFont(ThemeData base) {
  final filledStyle = base.filledButtonTheme.style;
  final outlinedStyle = base.outlinedButtonTheme.style;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    // 按钮的 textStyle 在主题里单独定义，不会自动继承 textTheme 的字体。
    filledButtonTheme: FilledButtonThemeData(
      style: filledStyle?.copyWith(
        textStyle: WidgetStatePropertyAll(
          (filledStyle.textStyle?.resolve(<WidgetState>{}) ?? const TextStyle())
              .copyWith(fontFamily: 'Roboto'),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlinedStyle?.copyWith(
        textStyle: WidgetStatePropertyAll(
          (outlinedStyle.textStyle?.resolve(<WidgetState>{}) ??
                  const TextStyle())
              .copyWith(fontFamily: 'Roboto'),
        ),
      ),
    ),
  );
}

Future<void> _pumpAndOpen(
  WidgetTester tester, {
  required ThemeData theme,
  required Color background,
}) async {
  tester.view.physicalSize = const Size(824, 1830);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withPreviewFont(theme),
        home: Scaffold(
          backgroundColor: background,
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => UpdateDialog(
                    info: _info,
                    currentVersion: '2.0.0',
                    onUpdate: () {},
                    onOpenUrl: (_) {},
                  ),
                ),
                child: const Text('打开更新弹窗'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('打开更新弹窗'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _savePreview(WidgetTester tester, String path) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_previewKey));
  // toByteData 依赖真实异步，必须放在 runAsync 里，否则测试会卡住。
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('预览图已生成：${file.absolute.path}');
  });
}

void main() {
  setUpAll(() async {
    if (!_previewEnabled) return;

    _cjkFontPath = _firstExisting(const [
          '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          '/usr/local/share/fonts/WindowsFonts/msyh.ttc',
          '/usr/local/share/fonts/WindowsFonts/simhei.ttf',
          '/System/Library/Fonts/PingFang.ttc',
          r'C:\Windows\Fonts\msyh.ttc',
          r'C:\Windows\Fonts\simhei.ttf',
        ]) ??
        '';

    if (_cjkFontPath.isEmpty) {
      fail('没有找到可用的中文字体，无法生成预览图。');
    }

    // 测试环境默认字体是 Ahem；把中文字体注册成 Roboto/Ahem，
    // 这样主题文字和按钮文字都能正常显示中文。
    await _loadFont('Roboto', _cjkFontPath);
    await _loadFont('Ahem', _cjkFontPath);

    final iconsPath = _materialIconsPath();
    if (iconsPath != null) {
      await _loadFont('MaterialIcons', iconsPath);
    }
  });

  testWidgets(
    '生成深色更新弹窗预览图',
    (tester) async {
      await _pumpAndOpen(
        tester,
        theme: AppTheme.darkTheme,
        background: const Color(0xFF101410),
      );
      await _savePreview(tester, 'build/preview/update_dialog_dark.png');
      expect(tester.takeException(), isNull);
    },
    skip: !_previewEnabled,
  );

  testWidgets(
    '生成浅色更新弹窗预览图',
    (tester) async {
      await _pumpAndOpen(
        tester,
        theme: AppTheme.lightTheme,
        background: const Color(0xFFF7FAF5),
      );
      await _savePreview(tester, 'build/preview/update_dialog_light.png');
      expect(tester.takeException(), isNull);
    },
    skip: !_previewEnabled,
  );
}
