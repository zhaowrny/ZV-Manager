import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'jar_metadata.dart';
import 'sftp_service.dart';
import 'package:dartssh2/dartssh2.dart' show SftpName;
import '../../providers/server_provider.dart';

/// 本地依赖索引库（SQLite）：
/// 1. 记录服务器 mods/plugins 下每个 jar 的元数据与依赖；
/// 2. 支持依赖树查询（该模组依赖什么 / 被谁依赖）；
/// 3. 增量同步：按 (serverId, remotePath, size, mtime) 跳过未变化文件。
class DependencyIndexService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'zv_dependency_index.db'),
      version: 1,
      onCreate: (db, v) => db.execute('''
        CREATE TABLE mods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id TEXT NOT NULL,
          remote_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          size INTEGER NOT NULL,
          mtime INTEGER NOT NULL,
          name TEXT,
          version TEXT,
          authors TEXT,
          description TEXT,
          depends TEXT,
          soft_depends TEXT,
          synced_at INTEGER NOT NULL
        )
      '''),
    );
  }

  /// 增量扫描远程目录并入库。返回 {新增, 更新, 总数}。
  static Future<SyncResult> syncServer(ServerConfig server) async {
    final sftp = SftpService();
    final result = SyncResult();
    try {
      await sftp.connect(server);
      final database = await db;
      for (final dir in ['mods', 'plugins']) {
        final remotePath = '/${server.sshUser.contains('root') ? 'root' : 'home/${server.sshUser}'}/$dir';
        List<SftpName> items;
        try {
          items = await sftp.listDir(remotePath);
        } catch (_) {
          continue; // 目录不存在则跳过
        }
        for (final item in items) {
          final attr = item.attr;
          if (attr.isDirectory || !item.filename.endsWith('.jar')) continue;
          final size = attr.size ?? 0;
          final mtime = attr.modifyTime ?? 0;
          final rows = await database.query('mods',
              where: 'server_id = ? AND remote_path = ?',
              whereArgs: [server.id, item.longname.isEmpty ? '$remotePath/${item.filename}' : '$remotePath/${item.filename}']);
          if (rows.isNotEmpty) {
            final row = rows.first;
            if (row['size'] == size && row['mtime'] == mtime) {
              result.unchanged++;
              continue;
            }
            await database.delete('mods', where: 'id = ?', whereArgs: [row['id']]);
          }
          // 下载到临时文件解析元数据
          final tmp = p.join((await getDatabasesPath()), 'tmp_${DateTime.now().millisecondsSinceEpoch}.jar');
          try {
            await sftp.download('$remotePath/${item.filename}', tmp);
            final meta = JarMetadata.parse(tmp);
            await database.insert('mods', {
              'server_id': server.id,
              'remote_path': '$remotePath/${item.filename}',
              'file_name': item.filename,
              'size': size,
              'mtime': mtime,
              'name': meta.name,
              'version': meta.version,
              'authors': meta.authors,
              'description': meta.description,
              'depends': jsonEncode(meta.depends),
              'soft_depends': jsonEncode(meta.softDepends),
              'synced_at': DateTime.now().millisecondsSinceEpoch,
            });
            rows.isEmpty ? result.added++ : result.updated++;
          } finally {
            final f = File(tmp);
            if (await f.exists()) await f.delete();
          }
        }
      }
      result.total = (await database.query('mods', where: 'server_id = ?', whereArgs: [server.id])).length;
    } finally {
      await sftp.disconnect();
    }
    return result;
  }

  /// 服务器本地索引列表。
  static Future<List<IndexedMod>> listForServer(String serverId) async {
    final database = await db;
    final rows = await database.query('mods',
        where: 'server_id = ?', whereArgs: [serverId], orderBy: 'file_name');
    return rows.map(IndexedMod.fromRow).toList();
  }

  /// 依赖树查询：返回 (该模组依赖的条目列表, 依赖它的条目列表, 缺失依赖 id 列表)。
  static Future<DependencyTree> queryTree(String serverId, String modId) async {
    final database = await db;
    final all = (await database.query('mods', where: 'server_id = ?', whereArgs: [serverId]))
        .map(IndexedMod.fromRow)
        .toList();

    final self = all.firstWhere(
      (m) => m.id.toString() == modId || m.modId == modId,
      orElse: () => all.first,
    );
    final knownIds = {for (final m in all) m.modId: m};
    final missing = self.depends.where((d) => !knownIds.containsKey(_norm(d))).toList();

    final dependsOn = <IndexedMod>[];
    for (final d in self.depends) {
      final hit = knownIds[_norm(d)];
      if (hit != null) dependsOn.add(hit);
    }
    final dependents = all.where((m) => m.depends.any((d) => _norm(d) == _norm(self.modId))).toList();
    return DependencyTree(mod: self, dependsOn: dependsOn, dependents: dependents, missing: missing);
  }

  /// 检测版本冲突 / 重复 jar：同一 modId 出现多个版本。
  static Future<List<DuplicateGroup>> findDuplicates(String serverId) async {
    final all = (await (await db).query('mods', where: 'server_id = ?', whereArgs: [serverId]))
        .map(IndexedMod.fromRow)
        .toList();
    final groups = <String, List<IndexedMod>>{};
    for (final m in all) {
      groups.putIfAbsent(_norm(m.modId), () => []).add(m);
    }
    return groups.entries
        .where((e) => e.key.isNotEmpty && e.value.length > 1)
        .map((e) => DuplicateGroup(modId: e.key, items: e.value))
        .toList();
  }

  static String _norm(String s) => s.trim().toLowerCase();

  static Future<void> clearServer(String serverId) async {
    await (await db).delete('mods', where: 'server_id = ?', whereArgs: [serverId]);
  }
}

class SyncResult {
  int added = 0;
  int updated = 0;
  int unchanged = 0;
  int total = 0;
  @override
  String toString() => '新增 $added · 更新 $updated · 未变化 $unchanged · 共 $total 条';
}

class IndexedMod {
  final int id;
  final String serverId;
  final String remotePath;
  final String fileName;
  final int size;
  final String? name;
  final String? version;
  final String? authors;
  final String? description;
  final List<String> depends;
  final List<String> softDepends;

  IndexedMod({
    required this.id,
    required this.serverId,
    required this.remotePath,
    required this.fileName,
    required this.size,
    this.name,
    this.version,
    this.authors,
    this.description,
    this.depends = const [],
    this.softDepends = const [],
  });

  /// 索引中用于匹配依赖的 modId：优先取文件名去后缀，其次名称。
  String get modId => name ?? fileName.replaceAll(RegExp(r'\.jar$'), '');

  factory IndexedMod.fromRow(Map<String, dynamic> row) => IndexedMod(
        id: row['id'] as int,
        serverId: row['server_id'] as String,
        remotePath: row['remote_path'] as String,
        fileName: row['file_name'] as String,
        size: row['size'] as int? ?? 0,
        name: row['name'] as String?,
        version: row['version'] as String?,
        authors: row['authors'] as String?,
        description: row['description'] as String?,
        depends: _decode(row['depends']),
        softDepends: _decode(row['soft_depends']),
      );

  static List<String> _decode(dynamic v) {
    if (v == null) return const [];
    try {
      return List<String>.from(jsonDecode(v as String));
    } catch (_) {
      return const [];
    }
  }
}

class DependencyTree {
  final IndexedMod mod;
  final List<IndexedMod> dependsOn;
  final List<IndexedMod> dependents;
  final List<String> missing; // 缺失依赖（可一键从 Modrinth 补齐）
  DependencyTree({
    required this.mod,
    required this.dependsOn,
    required this.dependents,
    required this.missing,
  });
}

class DuplicateGroup {
  final String modId;
  final List<IndexedMod> items;
  DuplicateGroup({required this.modId, required this.items});
}
