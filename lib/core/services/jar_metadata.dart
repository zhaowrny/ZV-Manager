import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';

/// 从 jar（zip）中解析模组/插件元数据。
/// 支持：fabric.mod.json / quilt.mod.json / paper-plugin.yml / plugin.yml / mods.toml
class JarMetadata {
  final String? name;
  final String? version;
  final String? authors;
  final String? description;
  final List<String> depends;     // 硬依赖
  final List<String> softDepends; // 软依赖
  final String source;            // 来源文件类型

  const JarMetadata({
    this.name,
    this.version,
    this.authors,
    this.description,
    this.depends = const [],
    this.softDepends = const [],
    this.source = 'unknown',
  });

  static JarMetadata empty = const JarMetadata();

  /// 解析本地 jar 文件，失败时返回 empty。
  static JarMetadata parse(String jarPath) {
    try {
      final bytes = File(jarPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      return parseArchive(archive);
    } catch (_) {
      return empty;
    }
  }

  /// 从内存中的 zip Archive 解析（公开以便测试）。
  static JarMetadata parseArchive(Archive archive) => _fromArchive(archive);

  static JarMetadata _fromArchive(Archive archive) {
    // 1) Fabric / Quilt：fabric.mod.json
    for (final entry in ['fabric.mod.json', 'quilt.mod.json']) {
      final f = archive.findFile(entry);
      if (f != null) {
        final json = jsonDecode(utf8.decode(f.content as List<int>));
        final loader = json['quilt_loader'];
        final root = loader ?? json;
        final meta = root['metadata'] ?? {};
        return JarMetadata(
          name: (root['name'] ?? meta['name'] ?? root['id'])?.toString(),
          version: (root['version'] ?? meta['version'])?.toString(),
          authors: _joinAuthors(meta['contributors'] ?? root['authors']),
          description: (meta['description'] ?? root['description'])?.toString(),
          depends: _toStringList(root['depends'] ?? json['depends']),
          softDepends: _toStringList(root['suggests'] ?? json['suggests']),
          source: entry,
        );
      }
    }

    // 2) Paper/Bukkit 插件：paper-plugin.yml / plugin.yml
    for (final entry in ['paper-plugin.yml', 'plugin.yml']) {
      final f = archive.findFile(entry);
      if (f != null) {
        final y = loadYaml(utf8.decode(f.content as List<int>));
        return JarMetadata(
          name: (y['name'])?.toString(),
          version: (y['version'])?.toString(),
          authors: _joinAuthors(y['authors'] ?? y['author']),
          description: (y['description'])?.toString(),
          depends: _toStringList(y['depend']),
          softDepends: _toStringList(y['softdepend']),
          source: entry,
        );
      }
    }

    // 3) Forge：META-INF/mods.toml / mcmod.info
    for (final entry in ['META-INF/mods.toml', 'mcmod.info']) {
      final f = archive.findFile(entry);
      if (f != null) {
        final text = utf8.decode(f.content as List<int>);
        if (entry.endsWith('.toml')) {
          final name = RegExp(r'''^\s*displayName\s*=\s*["']([^"']+)''', multiLine: true).firstMatch(text)?.group(1);
          final ver = RegExp(r'''^\s*version\s*=\s*["']([^"']+)''', multiLine: true).firstMatch(text)?.group(1);
          final deps = RegExp(r'''^\s*modId\s*=\s*["']([^"']+)''', multiLine: true)
              .allMatches(text)
              .map((m) => m.group(1)!)
              .toList();
          return JarMetadata(name: name, version: ver, depends: deps.skip(1).toList(), source: entry);
        }
        final json = jsonDecode(text);
        final info = json is List ? json.first : (json['modList']?.first ?? {});
        return JarMetadata(
          name: info['name']?.toString(),
          version: info['version']?.toString(),
          authors: _joinAuthors(info['authorList']),
          description: info['description']?.toString(),
          source: entry,
        );
      }
    }
    return empty;
  }

  static List<String> _toStringList(dynamic v) {
    if (v == null) return const [];
    if (v is YamlList) return v.map((e) => e.toString()).toList();
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is Map) {
      // fabric depends 可能是 {modid: "^1.0.0"} 或 contributors map
      return v.keys.map((e) => e.toString()).toList();
    }
    return v.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static String? _joinAuthors(dynamic v) {
    if (v == null) return null;
    if (v is YamlList || v is List) return v.join(', ');
    if (v is YamlMap || v is Map) return v.keys.join(', ');
    return v.toString();
  }
}
