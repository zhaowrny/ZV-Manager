import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zv_manager/core/utils/update_info.dart';
import 'package:zv_manager/core/widgets/update_dialog.dart';

void main() {
  testWidgets('更新弹窗展示版本、时间和更新日志', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final info = UpdateInfo(
      latestVersion: '2.0.1',
      downloadUrl: 'https://example.com/app.apk',
      apkName: 'app.apk',
      releaseNotes: '## 更新内容\n'
          '* feat: 新增 A\n'
          '* fix: 修复 B\n'
          '\n'
          '**完整的更新日志**: https://example.com/log',
      releasedAt: DateTime.parse('2026-10-27T21:56:07+08:00'),
      releasePageUrl:
          'https://gitee.com/driftinblock/zvmanager/releases/tag/v2.0.1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateDialog(
            info: info,
            currentVersion: '2.0.0',
            onUpdate: () {},
            onOpenUrl: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('2.0.1'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(find.text('2.0.0'), findsOneWidget);
    expect(find.text('更新'), findsOneWidget);
    expect(find.text('修复'), findsOneWidget);
    expect(find.text('新增 A'), findsOneWidget);
    expect(find.text('修复 B'), findsOneWidget);
    expect(find.text('查看发布页'), findsOneWidget);
    expect(find.text('忽略'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长更新日志可滚动且不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final info = UpdateInfo(
      latestVersion: '2.0.1',
      downloadUrl: 'https://example.com/app.apk',
      apkName: 'app.apk',
      releaseNotes: '## 更新内容\n${[
        for (var i = 1; i <= 40; i++) '* feat: 第 $i 条更新说明',
      ].join('\n')}',
      releasePageUrl:
          'https://gitee.com/driftinblock/zvmanager/releases/tag/v2.0.1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateDialog(
            info: info,
            currentVersion: '2.0.0',
            onUpdate: () {},
            onOpenUrl: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('第 1 条更新说明'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
