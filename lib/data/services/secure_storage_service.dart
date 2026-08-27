import 'dart:convert';
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
      final List<dynamic> decoded = jsonDecode(encrypted);
      return decoded.map((e) => ServerConfig.fromJson(e)).toList();
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
