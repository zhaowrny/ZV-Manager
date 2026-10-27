import '../../core/utils/rcon_client.dart';

/// 在线玩家信息。
class PlayerInfo {
  final String name;

  /// 玩家 UUID（`list uuids` 返回的括号内内容）
  final String uuid;

  /// 是否管理员。`list uuids` 不返回此信息，需另行查询，默认 false。
  final bool isOp;

  PlayerInfo({required this.name, required this.uuid, this.isOp = false});
}

/// 玩家操作服务：基于 RCON 命令实现的玩家管理与查询。
///
/// 所有方法都只是把高层操作翻译成原版命令，因此天然兼容各类服务端，
/// 无需额外的 Server 插件。
class PlayerService {
  final RconClient _rcon;
  PlayerService(this._rcon);

  /// 获取在线玩家列表。
  ///
  /// `list uuids` 的返回形态随版本/语言而变，例如：
  /// - `There are 2 of a max of 20 players online: Steve (uuid), Alex (uuid)`
  /// - `当前有 2 名玩家在线: Steve（uuid）, Alex（uuid）`
  ///
  /// 因此解析策略是：以**最后一个冒号**（兼容全角）为界取玩家段，
  /// 再用正则按 `名字(uuid)` 逐项提取，解析不出的条目直接跳过而非整体失败。
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

  /// 给予管理员权限（需执行者本身有 op 权限）。
  Future<String?> opPlayer(String name) async {
    return _rcon.executeCommand('op $name');
  }

  /// 撤销管理员权限。
  Future<String?> deopPlayer(String name) async {
    return _rcon.executeCommand('deop $name');
  }

  /// 踢出玩家。原因含空格时原样拼接即可，服务端会把剩余部分整体当作 reason。
  Future<String?> kickPlayer(String name, {String reason = ''}) async {
    final cmd = reason.isEmpty ? 'kick $name' : 'kick $name $reason';
    return _rcon.executeCommand(cmd);
  }

  /// 封禁玩家（写入 banned-players.json，重启后仍生效）。
  Future<String?> banPlayer(String name, {String reason = ''}) async {
    final cmd = reason.isEmpty ? 'ban $name' : 'ban $name $reason';
    return _rcon.executeCommand(cmd);
  }
}
