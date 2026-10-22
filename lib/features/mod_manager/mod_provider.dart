import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/jar_metadata.dart';
import '../../core/services/sftp_service.dart';
import '../../providers/server_provider.dart';

enum ModSortMode { name, size, mtime }

/// 模组/插件管理状态：通过 SFTP 列出 mods/plugins 目录的 jar 文件，
/// 本地缓存元数据解析结果。
class ModProvider extends ChangeNotifier {
  ServerConfig? server;
  String currentDir = 'mods'; // mods | plugins
  final Map<String, RemoteJarFile> _files = {};
  bool loading = false;
  String? error;
  ModSortMode sortMode = ModSortMode.name;

  void setSortMode(ModSortMode mode) {
    sortMode = mode;
    notifyListeners();
  }

  final SftpService _sftp = SftpService();

  List<RemoteJarFile> get files {
    final list = _files.values.toList();
    list.sort((a, b) => switch (sortMode) {
          ModSortMode.name => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
          ModSortMode.size => b.size.compareTo(a.size),
          ModSortMode.mtime => b.mtime.compareTo(a.mtime),
        });
    return list;
  }

  Future<void> open(ServerConfig s, {String dir = 'mods'}) async {
    server = s;
    currentDir = dir;
    await refresh();
  }

  String get _remoteBase {
    final user = server!.sshUser;
    final home = user == 'root' ? '/root' : '/home/$user';
    return '$home/$currentDir';
  }

  Future<void> refresh() async {
    final s = server;
    if (s == null || !s.hasSsh) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _sftp.connect(s);
      final items = await _sftp.listDir(_remoteBase);
      _files.clear();
      for (final item in items) {
        if (item.attr.isDirectory || !item.filename.endsWith('.jar')) continue;
        _files[item.filename] = RemoteJarFile(
          fileName: item.filename,
          remotePath: '$_remoteBase/${item.filename}',
          size: item.attr.size ?? 0,
          mtime: DateTime.fromMillisecondsSinceEpoch((item.attr.modifyTime ?? 0) * 1000),
        );
      }
      // 后台解析元数据（复用本地缓存）
      final cacheDir = await _cacheDir();
      for (final f in _files.values) {
        final meta = await _metadataFor(f, cacheDir);
        f.meta = meta;
      }
      loading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  /// 首次进入时下载 jar 解析元数据并缓存到本地，之后按 (name,size,mtime) 复用。
  Future<JarMetadata> _metadataFor(RemoteJarFile f, Directory cacheDir) async {
    final cacheFile = File('${cacheDir.path}/${f.cacheKey}.meta.json');
    if (await cacheFile.exists()) {
      try {
        return JarMetaCache.fromJsonString(await cacheFile.readAsString());
      } catch (_) {}
    }
    try {
      final tmp = File('${cacheDir.path}/${f.cacheKey}.jar');
      await _sftp.download(f.remotePath, tmp.path);
      final meta = JarMetadata.parse(tmp.path);
      await tmp.delete();
      await cacheFile.writeAsString(meta.toJsonString());
      return meta;
    } catch (_) {
      return JarMetadata.empty;
    }
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/jar_meta_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 上传本地 jar。
  Future<void> uploadJar(String localPath) async {
    final name = localPath.split(Platform.pathSeparator).last;
    await _sftp.upload(localPath, '$_remoteBase/$name');
    await refresh();
  }

  /// 删除远程 jar。
  Future<void> deleteJar(String fileName) async {
    await _sftp.delete('$_remoteBase/$fileName');
    _files.remove(fileName);
    notifyListeners();
  }

  /// 重命名远程 jar。
  Future<void> renameJar(String oldName, String newName) async {
    await _sftp.rename('$_remoteBase/$oldName', newName);
    await refresh();
  }

  Future<void> disconnect() => _sftp.disconnect();
}

/// 远程 jar 文件描述。
class RemoteJarFile {
  final String fileName;
  final String remotePath;
  final int size;
  final DateTime mtime;
  JarMetadata meta = JarMetadata.empty;

  RemoteJarFile({
    required this.fileName,
    required this.remotePath,
    required this.size,
    required this.mtime,
  });

  String get cacheKey =>
      '${fileName.hashCode}_${size}_${mtime.millisecondsSinceEpoch ~/ 1000}';
}

extension JarMetaCache on JarMetadata {
  String toJsonString() => jsonEncode({
        'name': name,
        'version': version,
        'authors': authors,
        'description': description,
        'depends': depends,
        'softDepends': softDepends,
        'source': source,
      });

  static JarMetadata fromJsonString(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return JarMetadata(
      name: m['name'],
      version: m['version'],
      authors: m['authors'],
      description: m['description'],
      depends: List<String>.from(m['depends'] ?? const []),
      softDepends: List<String>.from(m['softDepends'] ?? const []),
      source: m['source'] ?? 'cache',
    );
  }
}
