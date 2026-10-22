import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:zv_manager/core/services/jar_metadata.dart';

void main() {
  test('JarMetadata 解析 plugin.yml 插件', () {
    final archive = Archive()
      ..addFile(ArchiveFile('plugin.yml', 0, '''
name: EssentialsX
version: 2.20.1
authors: [Essentialsteam, md_5]
description: Essentials plugin
depend: [Vault]
softdepend: [PlaceholderAPI]
'''.codeUnits));
    final meta = JarMetadata.parseArchive(archive);
    expect(meta.name, 'EssentialsX');
    expect(meta.version, '2.20.1');
    expect(meta.depends, contains('Vault'));
    expect(meta.softDepends, contains('PlaceholderAPI'));
  });

  test('JarMetadata 解析 fabric.mod.json 模组', () {
    final archive = Archive()
      ..addFile(ArchiveFile('fabric.mod.json', 0, '''
{
  "schemaVersion": 1,
  "id": "sodium",
  "version": "0.5.3",
  "name": "Sodium",
  "authors": ["jellysquid3"],
  "depends": {"fabricloader": ">=0.14.0", "sodium": "x"}
}
'''.codeUnits));
    final meta = JarMetadata.parseArchive(archive);
    expect(meta.name, 'Sodium');
    expect(meta.version, '0.5.3');
    expect(meta.depends, contains('sodium'));
  });

  test('无效文件返回 empty', () {
    expect(JarMetadata.parse('/nonexistent/path.jar').name, isNull);
  });
}
