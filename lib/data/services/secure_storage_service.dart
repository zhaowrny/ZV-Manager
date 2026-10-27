import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/server_provider.dart';

/// 服务器配置的加密持久化。
///
/// 服务器配置里含 RCON 密码和 SSH 密码，属于敏感信息，
/// 因此走 [FlutterSecureStorage]（Android Keystore / iOS Keychain），
/// 而不是普通的 SharedPreferences 明文存储。
class SecureStorageService {
  /// 当前使用的加密存储 key
  static const _key = 'mc_servers_encrypted';

  /// 旧版本明文存储 key（迁移用，读取一次后即删除）
  static const _legacyKey = 'mc_servers';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      // first_unlock_this_device：开机首次解锁后可读，且不随 iCloud 备份迁移到其他设备
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// 读取服务器列表，必要时把旧版明文数据迁移到加密存储。
  static Future<List<ServerConfig>> loadServers() async {
    final encrypted = await _storage.read(key: _key);
    if (encrypted != null) {
      try {
        final List<dynamic> decoded = jsonDecode(encrypted);
        return decoded.map((e) => ServerConfig.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (e) {
        // 数据解析失败（版本变更/损坏）时原样保留，绝不能当成空列表处理，
        // 否则后续任何一次保存都会把用户的服务器数据覆盖丢失。
        debugPrint('服务器数据解析失败，已保留原始数据: $e');
        return [];
      }
    }

    // 迁移路径：v1 用 SharedPreferences 明文存储，读到后转存加密存储并清理旧数据
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      final List<dynamic> decoded = jsonDecode(legacy);
      final servers = decoded.map((e) => ServerConfig.fromJson(e)).toList();
      await saveServers(servers);
      await prefs.remove(_legacyKey);
      return servers;
    }

    return [];
  }

  /// 覆盖写入全部服务器配置（列表整体序列化，非增量更新）。
  static Future<void> saveServers(List<ServerConfig> servers) async {
    final encoded = jsonEncode(servers.map((s) => s.toJson()).toList());
    await _storage.write(key: _key, value: encoded);
  }
}
