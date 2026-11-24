// 底部悬浮胶囊导航（PillNavBar）的冒烟测试：
// 渲染 5 个页签、点击切换选中项、动画播完不出现布局异常。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zv_manager/core/theme/app_theme.dart';
import 'package:zv_manager/features/shell/pill_nav_bar.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  const labels = ['服务器', '控制台', '玩家', '模组', '我的'];
  const selectedIcons = [
    Icons.dns,
    Icons.terminal,
    Icons.group,
    Icons.extension,
    Icons.settings,
  ];
  const unselectedIcons = [
    Icons.dns_outlined,
    Icons.terminal_outlined,
    Icons.group_outlined,
    Icons.extension_outlined,
    Icons.settings_outlined,
  ];

  testWidgets('底部导航渲染 5 个页签，点击切换选中态', (tester) async {
    var index = 0;

    await tester.pumpWidget(_host(
      StatefulBuilder(
        builder: (context, setState) => PillNavBar(
          selectedIndex: index,
          labels: labels,
          selectedIcons: selectedIcons,
          unselectedIcons: unselectedIcons,
          onSelected: (i) => setState(() => index = i),
          hasWallpaper: false,
        ),
      ),
    ));

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    // 终端已并入控制台页签，不再作为独立导航项
    expect(find.text('终端'), findsNothing);
    expect(index, 0);

    // 未选中项只显示图标，点击图标区域切换
    await tester.tap(find.byIcon(Icons.group_outlined));
    await tester.pumpAndSettle();

    expect(index, 2);
    expect(find.byIcon(Icons.group), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('有壁纸样式下正常渲染', (tester) async {
    await tester.pumpWidget(_host(
      PillNavBar(
        selectedIndex: 1,
        labels: labels,
        selectedIcons: selectedIcons,
        unselectedIcons: unselectedIcons,
        onSelected: (_) {},
        hasWallpaper: true,
      ),
    ));

    expect(find.byIcon(Icons.terminal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
