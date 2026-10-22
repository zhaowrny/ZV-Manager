import 'package:flutter/foundation.dart';
import '../data/services/secure_storage_service.dart';

class ServerConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String password;

  /// SSH（SFTP / 终端）可选配置，纯 RCON 用户可留空。
  final bool sshEnabled;
  final int sshPort;
  final String sshUser;
  final String sshPassword;

  ServerConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.password,
    this.sshEnabled = false,
    this.sshPort = 22,
    this.sshUser = '',
    this.sshPassword = '',
  });

  /// 是否具备模组/终端功能所需的 SSH 配置。
  bool get hasSsh => sshEnabled && sshUser.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'password': password,
        'sshEnabled': sshEnabled,
        'sshPort': sshPort,
        'sshUser': sshUser,
        'sshPassword': sshPassword,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'],
        name: json['name'],
        host: json['host'],
        port: json['port'],
        password: json['password'],
        sshEnabled: json['sshEnabled'] ?? false,
        sshPort: json['sshPort'] ?? 22,
        sshUser: json['sshUser'] ?? '',
        sshPassword: json['sshPassword'] ?? '',
      );
}

class ServerProvider extends ChangeNotifier {
  List<ServerConfig> _servers = [];
  List<ServerConfig> get servers => List.unmodifiable(_servers);

  Future<void> loadServers() async {
    _servers = await SecureStorageService.loadServers();
    notifyListeners();
  }

  Future<void> addServer(ServerConfig server) async {
    _servers.add(server);
    await _save();
    notifyListeners();
  }

  Future<void> updateServer(ServerConfig server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index != -1) _servers[index] = server;
    await _save();
    notifyListeners();
  }

  Future<void> removeServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  ServerConfig? byId(String? id) {
    if (id == null) return null;
    try {
      return _servers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    await SecureStorageService.saveServers(_servers);
  }
}
