import 'package:flutter/foundation.dart';
import '../data/services/secure_storage_service.dart';

class ServerConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String password;

  ServerConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'password': password,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'],
        name: json['name'],
        host: json['host'],
        port: json['port'],
        password: json['password'],
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

  Future<void> _save() async {
    await SecureStorageService.saveServers(_servers);
  }
}
