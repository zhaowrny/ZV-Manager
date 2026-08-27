import '../../core/utils/rcon_client.dart';

class PlayerInfo {
  final String name;
  final String uuid;
  final bool isOp;

  PlayerInfo({required this.name, required this.uuid, this.isOp = false});
}

class PlayerService {
  final RconClient _rcon;
  PlayerService(this._rcon);

  Future<List<PlayerInfo>> getOnlinePlayers() async {
    final response = await _rcon.executeCommand('list uuids');
    if (response == null) return [];
    final cleaned = stripMinecraftCodes(response);

    // 玩家段位于最后一个冒号（ASCII 或全角）之后，使用已清除颜色码的内容
    if (!cleaned.contains(RegExp(r'[:：]'))) return [];
    final playerSection = cleaned.split(RegExp(r'[:：]')).last.trim();
    if (playerSection.isEmpty) return [];

    return playerSection.split(', ').map((entry) {
      final entryTrimmed = entry.trim();
      if (entryTrimmed.isEmpty) return null;
      // 兼容全角（ ）与半角（()）括号
      final match = RegExp(r'(.+?)[（(]([^（）()]+)[）)]').firstMatch(entryTrimmed);
      if (match == null) return null;
      return PlayerInfo(
        name: match.group(1)!.trim(),
        uuid: match.group(2)!.trim(),
      );
    }).whereType<PlayerInfo>().toList();
  }

  Future<String?> opPlayer(String name) async {
    return _rcon.executeCommand('op $name');
  }

  Future<String?> deopPlayer(String name) async {
    return _rcon.executeCommand('deop $name');
  }

  Future<String?> kickPlayer(String name, {String reason = ''}) async {
    final cmd = reason.isEmpty ? 'kick $name' : 'kick $name $reason';
    return _rcon.executeCommand(cmd);
  }

  Future<String?> banPlayer(String name, {String reason = ''}) async {
    final cmd = reason.isEmpty ? 'ban $name' : 'ban $name $reason';
    return _rcon.executeCommand(cmd);
  }
}
