import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zv_manager/core/widgets/background_widget.dart';
import 'package:zv_manager/features/server_list/server_card.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('ServerCard', () {
    testWidgets('在线态展示名称、地址、人数与 TPS', (tester) async {
      await tester.pumpWidget(_host(
        ServerCard(
          name: '生存服',
          host: 'play.example.cn',
          port: 25575,
          state: ServerCardState.online,
          playerCount: 18,
          latencyMs: 42,
          tps: 19.8,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ));

      expect(find.text('生存服'), findsOneWidget);
      expect(find.text('play.example.cn:25575'), findsOneWidget);
      // 服务器未下发 max like，展示「18 人」
      expect(find.textContaining('18'), findsWidgets);
      expect(find.text('TPS 19.8'), findsOneWidget);
      expect(find.text('在线'), findsOneWidget);
      expect(find.text('42ms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('离线态不显示 TPS，显示无法连接', (tester) async {
      await tester.pumpWidget(_host(
        ServerCard(
          name: '测试服',
          host: '127.0.0.1',
          port: 25575,
          state: ServerCardState.offline,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ));

      expect(find.text('离线'), findsOneWidget);
      expect(find.text('无法连接'), findsOneWidget);
      expect(find.textContaining('TPS'), findsNothing);
    });

    testWidgets('检测中显示 loading 文案', (tester) async {
      await tester.pumpWidget(_host(
        ServerCard(
          name: '新服务器',
          host: '10.0.0.2',
          port: 25575,
          state: ServerCardState.loading,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ));

      expect(find.text('正在获取状态'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('长名称不溢出（窄屏）', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        ServerCard(
          name: '这是一个特别特别长的服务器名称用来测试截断是否正常工作',
          host: 'a-very-long-subdomain.example-minecraft-server.cn',
          port: 25575,
          state: ServerCardState.online,
          playerCount: 3,
          latencyMs: 120,
          tps: 20,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('菜单可打开编辑与删除', (tester) async {
      var edited = false;
      var deleted = false;

      await tester.pumpWidget(_host(
        ServerCard(
          name: 'A',
          host: 'h',
          port: 1,
          state: ServerCardState.online,
          onTap: () {},
          onEdit: () => edited = true,
          onDelete: () => deleted = true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(edited, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    test('TPS 分档着色边界', () {
      expect(ServerCard.tpsColor(16), const Color(0xFF34D399));
      expect(ServerCard.tpsColor(15.9), const Color(0xFFFBBF24));
      expect(ServerCard.tpsColor(10), const Color(0xFFFBBF24));
      expect(ServerCard.tpsColor(9.9), const Color(0xFFF87171));
    });
  });

  group('BackgroundSpec', () {
    test('值相等语义：同路径同类型视为相等', () {
      const a = BackgroundSpec(type: 'image', path: '/x/1.jpg');
      const b = BackgroundSpec(type: 'image', path: '/x/1.jpg');
      const c = BackgroundSpec(type: 'image', path: '/x/2.jpg');
      expect(a, b);
      expect(a == c, isFalse);
      expect(const BackgroundSpec.none().isEmpty, isTrue);
      expect(a.isEmpty, isFalse);
    });

    test('ValueNotifier 对相同值不重复通知', () {
      final notifier = BackgroundWidget.spec;
      var calls = 0;
      void listener() => calls++;
      notifier.addListener(listener);

      notifier.value = const BackgroundSpec(type: 'image', path: '/a.jpg');
      notifier.value = const BackgroundSpec(type: 'image', path: '/a.jpg');

      expect(calls, 1);
      notifier.removeListener(listener);
    });
  });
}
