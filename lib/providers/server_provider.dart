import 'package:flutter/foundation.dart';
import '../data/services/secure_storage_service.dart';

/// 一台 Minecraft 服务器的连接配置。
///
/// 包含两组凭据：
/// - **RCON**（host / port / password）：控制台命令、玩家管理；
/// - **SSH**（ssh* 字段）：SFTP 文件操作、终端、日志。
///
/// 两组凭据相互独立，只填 RCON 也能正常使用控制台与玩家功能。
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

  /// 是否为内置的演示服务器：连接时走本地模拟，不会访问网络。
  final bool isDemo;

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
    this.isDemo = false,
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
        'isDemo': isDemo,
      };

  /// 从旧版本存档反序列化时，SSH 字段可能不存在，全部给默认值以兼容升级。
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
        isDemo: json['isDemo'] ?? false,
      );
}

/// 服务器列表状态：增删改查 + 持久化。
///
/// 所有写操作都会立即落盘（[SecureStorageService]），
/// 保证进程被杀后配置不丢。
class ServerProvider extends ChangeNotifier {
  List<ServerConfig> _servers = [];

  /// 对外暴露不可变视图，防止 UI 层直接修改内部列表导致状态不同步。
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

  /// 按 id 匹配替换（id 由创建时生成，编辑不改变 id）。
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

  /// 按 id 查找；找不到（如服务器已被删除）返回 null。
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
