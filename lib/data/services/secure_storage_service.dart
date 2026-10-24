import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/server_provider.dart';

class SecureStorageService {
  static const _key = 'mc_servers_encrypted';
  static const _legacyKey = 'mc_servers';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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

  static Future<void> saveServers(List<ServerConfig> servers) async {
    final encoded = jsonEncode(servers.map((s) => s.toJson()).toList());
    await _storage.write(key: _key, value: encoded);
  }
}
