import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/rcon_provider.dart';
import '../../providers/server_provider.dart';
import '../l10n/strings.dart';
import '../utils/rcon_client.dart';
import 'notification_service.dart';

/// 从 `list` 命令的返回里解析在线玩家名。
///
/// 只取最后一个冒号（兼容全角）之后的玩家段，再按逗号切分。
/// 零人在线时服务端返回的玩家段为空，直接得到空列表。
/// 解析不出的内容一律跳过，不抛异常 —— 监控是后台任务，不能因为
/// 某个服务端改了输出格式就把整轮检查搞崩。
List<String> parseOnlinePlayerNames(String? info) {
  if (info == null) return const <String>[];
  final cleaned = stripMinecraftCodes(info).trim();
  final parts = cleaned.split(RegExp(r'[:：]'));
  if (parts.length < 2) return const <String>[];
  final section = parts.last.trim();
  if (section.isEmpty) return const <String>[];
  return section
      .split(RegExp(r'[,，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 单台服务器的上一次观测快照。
class _ServerSnapshot {
  bool online;
  Set<String> players;

  /// 最近一次弹通知的时间，用于抖动保护（避免网络抖动导致刷屏）。
  DateTime? lastAlertAt;

  _ServerSnapshot({
    required this.online,
    required this.players,
    this.lastAlertAt,
  });
}

/// 服务器状态监控：定时轮询所有已配置服务器，在状态变化时推送系统通知。
///
/// 监控规则（只对「状态变化」发通知，避免重复打扰）：
/// - 在线 → 离线：服务器离线提醒；
/// - 离线 → 在线：服务器恢复提醒；
/// - 在线且出现新玩家：玩家上线提醒（一次轮询内多人同时上线会合并成一条）；
/// - **首次观测只建立基线**，不发通知 —— 否则一开开关就会收到一串噪音。
///
/// 生命周期：由 App 层注册为 Provider，设置页开关控制启停。
class ServerMonitorService extends ChangeNotifier {
  ServerMonitorService({required this.servers, required this.rcon});

  final ServerProvider servers;
  final RconProvider rcon;

  // ---------- 持久化 key（一旦发布就不要改名，否则老用户设置会丢） ----------
  static const String _kEnabled = 'monitor_enabled';
  static const String _kOffline = 'monitor_notify_offline';
  static const String _kRecovered = 'monitor_notify_recovered';
  static const String _kJoin = 'monitor_notify_join';
  static const String _kInterval = 'monitor_interval_sec';

  /// 可选轮询间隔（秒）。太短的间隔会给服务器 RCON 带来无谓压力。
  static const List<int> intervalOptions = <int>[30, 60, 120, 300];

  bool _enabled = false;
  bool _notifyOffline = true;
  bool _notifyRecovered = true;
  bool _notifyJoin = true;
  int _intervalSec = 60;

  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;
  DateTime? _lastCheckAt;
  int _onlineCount = 0;
  int _notifySeq = 0;

  final Map<String, _ServerSnapshot> _snapshots = {};

  bool get enabled => _enabled;
  bool get notifyOffline => _notifyOffline;
  bool get notifyRecovered => _notifyRecovered;
  bool get notifyJoin => _notifyJoin;
  int get intervalSec => _intervalSec;
  bool get isChecking => _checking;
  DateTime? get lastCheckAt => _lastCheckAt;

  /// 最近一轮检查中被判定为在线的服务器数量。
  int get onlineCount => _onlineCount;

  /// 当前间隔的展示文案。
  String get intervalLabel => labelForInterval(_intervalSec);

  /// 把间隔秒数翻译成展示文案（设置页的选项弹层也用这一份，避免两处文案走偏）。
  static String labelForInterval(int seconds) {
    switch (seconds) {
      case 30:
        return S.t('30 秒');
      case 120:
        return S.t('2 分钟');
      case 300:
        return S.t('5 分钟');
      default:
        return S.t('1 分钟');
    }
  }

  /// 从本地读取设置；若上次开启了监控则自动恢复运行。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? false;
      _notifyOffline = prefs.getBool(_kOffline) ?? true;
      _notifyRecovered = prefs.getBool(_kRecovered) ?? true;
      _notifyJoin = prefs.getBool(_kJoin) ?? true;
      final saved = prefs.getInt(_kInterval) ?? 60;
      _intervalSec = intervalOptions.contains(saved) ? saved : 60;
    } catch (e) {
      debugPrint('读取监控设置失败: $e');
    }
    if (_enabled) _startTimer();
    _notify();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    _notify();
    await _persistBool(_kEnabled, value);
    if (value) {
      _startTimer();
      // 开启后立刻检查一次，用户能马上看到效果，不用干等一个周期
      await checkNow();
    } else {
      _timer?.cancel();
      _timer = null;
      // 关掉后清空快照：下次开启重新建立基线，避免拿旧状态误报离线
      _snapshots.clear();
      _onlineCount = 0;
      _notify();
    }
  }

  Future<void> setNotifyOffline(bool value) async {
    _notifyOffline = value;
    _notify();
    await _persistBool(_kOffline, value);
  }

  Future<void> setNotifyRecovered(bool value) async {
    _notifyRecovered = value;
    _notify();
    await _persistBool(_kRecovered, value);
  }

  Future<void> setNotifyJoin(bool value) async {
    _notifyJoin = value;
    _notify();
    await _persistBool(_kJoin, value);
  }

  Future<void> setInterval(int seconds) async {
    if (!intervalOptions.contains(seconds) || seconds == _intervalSec) return;
    _intervalSec = seconds;
    _notify();
    await _persistInt(_kInterval, seconds);
    if (_enabled) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _intervalSec),
      (_) => checkNow(),
    );
  }

  /// 立即执行一轮检查。
  ///
  /// 每台服务器单独 try/catch：一台超时不能影响其余服务器的检查。
  Future<void> checkNow() async {
    if (_checking || _disposed) return;
    _checking = true;
    _notify();
    try {
      final list = servers.servers;
      final seen = <String>{};
      var online = 0;
      for (final server in list) {
        if (_disposed) return;
        seen.add(server.id);
        try {
          final status = await rcon.checkStatus(server);
          if (status.online) online++;
          await _evaluate(server, status);
        } catch (e) {
          debugPrint('检查服务器「${server.name}」失败: $e');
        }
      }
      // 已删除的服务器不再保留快照，避免内存里堆积僵尸条目
      _snapshots.removeWhere((id, _) => !seen.contains(id));
      _onlineCount = online;
      _lastCheckAt = DateTime.now();
    } finally {
      _checking = false;
      _notify();
    }
  }

  /// 对比上一轮快照，决定是否需要发通知。
  Future<void> _evaluate(ServerConfig server, ServerStatus status) async {
    final players = status.online
        ? parseOnlinePlayerNames(status.playerInfo).toSet()
        : <String>{};
    final prev = _snapshots[server.id];

    if (prev == null) {
      // 首次观测：只记基线。否则刚开启监控就会收到「X 进入服务器」的假通知
      _snapshots[server.id] = _ServerSnapshot(
        online: status.online,
        players: players,
      );
      return;
    }

    final now = DateTime.now();
    final canAlert = prev.lastAlertAt == null ||
        now.difference(prev.lastAlertAt!) >= const Duration(minutes: 2);

    if (prev.online && !status.online) {
      if (_notifyOffline && canAlert) {
        await _send(
          title: S.t('服务器离线'),
          body: S.f('「{0}」已离线，可能已停止运行', <Object>[server.name]),
        );
        prev.lastAlertAt = now;
      }
    } else if (!prev.online && status.online) {
      if (_notifyRecovered && canAlert) {
        await _send(
          title: S.t('服务器恢复'),
          body: S.f('「{0}」已恢复在线', <Object>[server.name]),
        );
        prev.lastAlertAt = now;
      }
    } else if (status.online && _notifyJoin) {
      final joined = players.difference(prev.players).toList()..sort();
      if (joined.isNotEmpty) {
        await _send(
          title: S.t('玩家上线'),
          body: S.f(
            '「{0}」：{1} 进入服务器',
            <Object>[server.name, joined.join('、')],
          ),
        );
        prev.lastAlertAt = now;
      }
    }

    prev.online = status.online;
    prev.players = players;
  }

  Future<void> _send({required String title, required String body}) async {
    await NotificationService.instance.show(
      id: ++_notifySeq,
      title: title,
      body: body,
    );
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('保存监控设置失败: $e');
    }
  }

  Future<void> _persistInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('保存监控设置失败: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
