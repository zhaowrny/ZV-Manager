import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartssh2/dartssh2.dart';

import '../../providers/server_provider.dart';
import '../l10n/strings.dart';

/// 创建内置演示服务器配置（隐藏调试入口使用）。
ServerConfig createDemoServer() => ServerConfig(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      name: S.t('演示服务器'),
      host: 'demo.local',
      port: 25575,
      password: 'demo',
      sshEnabled: true,
      sshPort: 22,
      sshUser: 'demo',
      sshPassword: 'demo',
      isDemo: true,
    );

/// 演示 jar 的元信息：下载时据此生成可被 [JarMetadata] 解析的真实 zip。
class DemoModInfo {
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> depends;
  final bool plugin;

  const DemoModInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.depends = const [],
    this.plugin = false,
  });
}

/// 演示 SFTP 的内存文件系统。
///
/// 只服务演示服务器：目录、文件、jar 元数据全部内置在内存里，
/// 上传的内容也只保存在本次进程内，重启后恢复初始演示数据。
class DemoFileSystem {
  static const String home = '/home/demo';

  final Map<String, List<_DemoEntry>> _dirs = {};

  DemoFileSystem() {
    _seed();
  }

  /// 列出目录（不存在的目录返回空列表，与真实 SFTP 行为接近）。
  List<SftpName> list(String path) {
    final entries = _dirs[_normalize(path)];
    if (entries == null) return <SftpName>[];
    return entries
        .map(
          (e) => SftpName(
            filename: e.name,
            longname: _longname(e),
            attr: SftpFileAttrs(
              size: e.isDir ? 4096 : e.size,
              modifyTime: e.mtime.millisecondsSinceEpoch ~/ 1000,
              mode: SftpFileMode.value(e.isDir ? 0x41ED : 0x81A4),
            ),
          ),
        )
        .toList();
  }

  String readString(String remotePath, {int maxBytes = 2 * 1024 * 1024}) {
    final bytes = bytesOf(remotePath);
    if (bytes.length <= maxBytes) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    var start = bytes.length - maxBytes;
    while (start < bytes.length && (bytes[start] & 0xC0) == 0x80) {
      start++;
    }
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  /// 读取文件内容。jar 会即时生成合法的 zip（含描述文件），
  /// 这样模组元数据解析在演示模式下也能走完整流程。
  Uint8List bytesOf(String remotePath) {
    final (dir, name) = _split(remotePath);
    _DemoEntry? entry;
    for (final e in _dirs[dir] ?? const <_DemoEntry>[]) {
      if (!e.isDir && e.name == name) {
        entry = e;
        break;
      }
    }
    if (entry == null) throw StateError('No such file: $remotePath');
    if (entry.raw != null) return entry.raw!;
    if (entry.text != null) return Uint8List.fromList(utf8.encode(entry.text!));
    final mod = entry.mod;
    if (mod == null) return Uint8List(0);
    return _buildJar(mod);
  }

  Future<void> download(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) async {
    final bytes = bytesOf(remotePath);
    final sink = io.File(localPath).openWrite();
    sink.add(bytes);
    await sink.flush();
    await sink.close();
    onProgress?.call(bytes.length, bytes.length);
  }

  Future<void> upload(String localPath, String remotePath) async {
    final file = io.File(localPath);
    var size = 0;
    Uint8List? raw;
    try {
      size = await file.length();
      // 演示用途：适度缓存上传内容，超过 32MB 只记录大小
      if (size <= 32 * 1024 * 1024) raw = await file.readAsBytes();
    } catch (_) {
      return;
    }
    final (dir, name) = _split(remotePath);
    final entries = _dirs.putIfAbsent(dir, () => <_DemoEntry>[]);
    entries.removeWhere((e) => e.name == name && !e.isDir);
    entries.add(
      _DemoEntry.file(name, size: size, raw: raw, mtime: DateTime.now()),
    );
  }

  void delete(String remotePath) {
    final (dir, name) = _split(remotePath);
    _dirs[dir]?.removeWhere((e) => e.name == name);
  }

  void rename(String remotePath, String newName) {
    final (dir, name) = _split(remotePath);
    for (final e in _dirs[dir] ?? const <_DemoEntry>[]) {
      if (e.name == name) e.name = newName;
    }
  }

  void mkdir(String remotePath) {
    final path = _normalize(remotePath);
    final (dir, name) = _split(path);
    final entries = _dirs.putIfAbsent(dir, () => <_DemoEntry>[]);
    if (!entries.any((e) => e.name == name && e.isDir)) {
      entries.add(_DemoEntry.dir(name, mtime: DateTime.now()));
    }
    _dirs.putIfAbsent(path, () => <_DemoEntry>[]);
  }

  // ==================== 内部实现 ====================

  String _normalize(String path) {
    var p = path.trim();
    if (p.isEmpty) return home;
    if (!p.startsWith('/')) p = '$home/$p';
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  (String, String) _split(String remotePath) {
    final path = _normalize(remotePath);
    final index = path.lastIndexOf('/');
    if (index <= 0) return ('/', path.substring(index + 1));
    return (path.substring(0, index), path.substring(index + 1));
  }

  String _longname(_DemoEntry e) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = e.mtime;
    final perms = e.isDir ? 'drwxr-xr-x' : '-rw-r--r--';
    final size = e.isDir ? 4096 : e.size;
    return '$perms 1 demo demo $size '
        '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)} ${e.name}';
  }

  Uint8List _buildJar(DemoModInfo mod) {
    final archive = Archive();
    final String fileName;
    final String content;
    if (mod.plugin) {
      fileName = 'plugin.yml';
      content = 'name: ${mod.name}\n'
          'version: ${mod.version}\n'
          'authors: [ZV Demo]\n'
          'description: ${mod.description}\n'
          'depend: [${mod.depends.join(', ')}]\n';
    } else {
      fileName = 'fabric.mod.json';
      content = jsonEncode({
        'schemaVersion': 1,
        'id': mod.id,
        'version': mod.version,
        'name': mod.name,
        'authors': ['ZV Demo'],
        'description': mod.description,
        'depends': {
          'minecraft': '1.20.1',
          for (final d in mod.depends) d: '*',
        },
      });
    }
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    return ZipEncoder().encodeBytes(archive);
  }

  void _seed() {
    final now = DateTime.now();
    DateTime ago(int days, {int hours = 0}) =>
        now.subtract(Duration(days: days, hours: hours));

    _dirs[home] = [
      _DemoEntry.dir('logs', mtime: ago(0, hours: 1)),
      _DemoEntry.dir('mods', mtime: ago(2)),
      _DemoEntry.dir('plugins', mtime: ago(2)),
      _DemoEntry.dir('world', mtime: ago(30)),
      _DemoEntry.textFile('eula.txt', 'eula=true\n', mtime: ago(30)),
      _DemoEntry.textFile(
        'server.properties',
        '#Minecraft server properties\n'
            'level-name=world\n'
            'max-players=20\n'
            'online-mode=true\n'
            'motd=ZV Manager 演示服务器\n'
            'server-port=25565\n'
            'rcon.port=25575\n'
            'enable-rcon=true\n',
        mtime: ago(5),
      ),
      _DemoEntry.textFile('whitelist.json', '[\n]\n', mtime: ago(3)),
      _DemoEntry.textFile(
        'start.sh',
        '#!/bin/sh\njava -Xmx4G -Xms2G -jar server.jar nogui\n',
        mtime: ago(30),
      ),
      _DemoEntry.file('server.jar', size: 48 * 1024 * 1024, mtime: ago(30)),
    ];

    _dirs['$home/mods'] = [
      _DemoEntry.jar(
        'fabric-api-0.92.2+1.20.1.jar',
        const DemoModInfo(
          id: 'fabric-api',
          name: 'Fabric API',
          version: '0.92.2+1.20.1',
          description: 'Fabric 模组生态的基础 API',
          depends: ['fabricloader'],
        ),
        size: 2245120,
        mtime: ago(4),
      ),
      _DemoEntry.jar(
        'jei-1.20.1-forge-15.20.0.106.jar',
        const DemoModInfo(
          id: 'jei',
          name: 'Just Enough Items',
          version: '15.20.0.106',
          description: '物品与配方查询',
          depends: ['fabricloader'],
        ),
        size: 1189376,
        mtime: ago(3),
      ),
      _DemoEntry.jar(
        'sodium-fabric-0.5.8+mc1.20.1.jar',
        const DemoModInfo(
          id: 'sodium',
          name: 'Sodium',
          version: '0.5.8+mc1.20.1',
          description: '高性能渲染优化模组',
          depends: ['fabric-api'],
        ),
        size: 862208,
        mtime: ago(2),
      ),
      _DemoEntry.jar(
        'iris-mc1.20.1-1.6.11.jar',
        const DemoModInfo(
          id: 'iris',
          name: 'Iris Shaders',
          version: '1.6.11',
          description: '光影加载器',
          depends: ['sodium'],
        ),
        size: 1048576,
        mtime: ago(1),
      ),
    ];

    _dirs['$home/plugins'] = [
      _DemoEntry.jar(
        'EssentialsX-2.20.1.jar',
        const DemoModInfo(
          id: 'essentials',
          name: 'EssentialsX',
          version: '2.20.1',
          description: '基础管理命令与传送',
          depends: ['Vault'],
          plugin: true,
        ),
        size: 1077376,
        mtime: ago(6),
      ),
      _DemoEntry.jar(
        'LuckPerms-Bukkit-5.4.102.jar',
        const DemoModInfo(
          id: 'luckperms',
          name: 'LuckPerms',
          version: '5.4.102',
          description: '权限管理',
          plugin: true,
        ),
        size: 859136,
        mtime: ago(6),
      ),
      _DemoEntry.jar(
        'Vault-1.7.3.jar',
        const DemoModInfo(
          id: 'vault',
          name: 'Vault',
          version: '1.7.3',
          description: '经济与权限 API',
          plugin: true,
        ),
        size: 145408,
        mtime: ago(6),
      ),
    ];

    _dirs['$home/logs'] = [
      _DemoEntry.textFile('latest.log', _latestLog, mtime: now),
      _DemoEntry.textFile('debug.log', _debugLog, mtime: now),
      _DemoEntry.textFile(
        '2026-11-20-1.log',
        _latestLog,
        mtime: ago(1),
      ),
    ];

    _dirs['$home/world'] = [];
  }

  static const String _latestLog =
      '[12:00:01] [Server thread/INFO]: Starting minecraft server version 1.20.1\n'
      '[12:00:03] [Server thread/INFO]: Preparing level "world"\n'
      '[12:00:05] [Server thread/INFO]: Done (3.512s)! For help, type "help"\n'
      '[12:00:10] [Server thread/INFO]: Steve joined the game\n'
      '[12:00:12] [Server thread/INFO]: Alex joined the game\n'
      '[12:00:15] [Server thread/INFO]: Notch joined the game\n'
      '[12:01:02] [Server thread/INFO]: <Steve> 演示服务器现已上线\n';

  static const String _debugLog =
      '[12:00:01] [Server thread/DEBUG]: Loaded 4 mods from mods/\n'
      '[12:00:02] [Server thread/DEBUG]: Loaded 3 plugins from plugins/\n'
      '[12:00:05] [Server thread/DEBUG]: Demo filesystem ready\n';
}

class _DemoEntry {
  String name;
  final bool isDir;
  final int size;
  final DateTime mtime;
  final String? text;
  final Uint8List? raw;
  final DemoModInfo? mod;

  _DemoEntry._({
    required this.name,
    required this.isDir,
    required this.size,
    required this.mtime,
    this.text,
    this.raw,
    this.mod,
  });

  factory _DemoEntry.dir(String name, {required DateTime mtime}) =>
      _DemoEntry._(
        name: name,
        isDir: true,
        size: 0,
        mtime: mtime,
      );

  factory _DemoEntry.textFile(String name, String content,
          {required DateTime mtime}) =>
      _DemoEntry._(
        name: name,
        isDir: false,
        size: utf8.encode(content).length,
        mtime: mtime,
        text: content,
      );

  factory _DemoEntry.file(String name,
          {required int size, required DateTime mtime, Uint8List? raw}) =>
      _DemoEntry._(
        name: name,
        isDir: false,
        size: size,
        mtime: mtime,
        raw: raw,
      );

  factory _DemoEntry.jar(String name, DemoModInfo mod,
          {required int size, required DateTime mtime}) =>
      _DemoEntry._(
        name: name,
        isDir: false,
        size: size,
        mtime: mtime,
        mod: mod,
      );
}
