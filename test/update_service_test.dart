import 'package:flutter_test/flutter_test.dart';
import 'package:zv_manager/core/utils/release_notes.dart';
import 'package:zv_manager/core/utils/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('不会把旧版本当成新版本', () {
      expect(UpdateService.isNewerVersion('2.0.1', '2.0.3'), isFalse);
    });

    test('识别更高版本', () {
      expect(UpdateService.isNewerVersion('2.0.3', '2.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('v2.1.0', '2.0.9'), isTrue);
      expect(UpdateService.isNewerVersion('2.0', '2.0.0'), isFalse);
    });

    test('空版本不会触发更新', () {
      expect(UpdateService.isNewerVersion('', '2.0.0'), isFalse);
    });
  });

  group('ReleaseNotes.parse', () {
    test('按 feat/fix 前缀分组并提取完整日志链接', () {
      final notes = ReleaseNotes.parse(
        '## 更新内容\n'
        '* feat: 新增 A\n'
        '* fix: 修复 B\n'
        '* docs: 补充 C\n'
        '\n'
        '**完整的更新日志**: https://gitee.com/driftinblock/zvmanager/compare/v2.0.0...v2.0.1\n',
      );

      expect(notes.sections.length, 2);
      expect(notes.sections[0].title, '更新');
      expect(
        notes.sections[0].items.map((item) => item.text),
        ['新增 A', '补充 C'],
      );
      expect(notes.sections[1].title, '修复');
      expect(
        notes.sections[1].items.map((item) => item.text),
        ['修复 B'],
      );
      expect(notes.links.single.label, '完整的更新日志');
      expect(
        notes.links.single.url,
        'https://gitee.com/driftinblock/zvmanager/compare/v2.0.0...v2.0.1',
      );
    });

    test('纯文本发布说明回退到更新分组', () {
      final notes = ReleaseNotes.parse('卡片式服务器列表 + 壁纸切换闪屏修复');

      expect(notes.sections.single.title, '更新');
      expect(
        notes.sections.single.items.single.text,
        '卡片式服务器列表 + 壁纸切换闪屏修复',
      );
      expect(notes.sections.single.items.single.bullet, isFalse);
    });

    test('保留自定义小标题', () {
      final notes = ReleaseNotes.parse('## 注意事项\n* 更新前请先备份');

      expect(notes.sections.single.title, '注意事项');
      expect(notes.sections.single.items.single.text, '更新前请先备份');
    });
  });
}
