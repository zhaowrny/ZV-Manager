import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 系统通知服务：把服务器状态事件推送到 Android 通知栏。
///
/// 设计要点：
/// - **绝不阻断主流程**：所有插件调用都包了 try/catch。Web 端、用户拒绝权限、
///   厂商 ROM 屏蔽通知时静默降级，只记一条 debugPrint，不让监控逻辑崩掉；
/// - **单例**：监控服务与设置页共用同一个实例，避免重复注册通知通道；
/// - **懒初始化**：只有真正要用时才初始化，不给冷启动增加负担
///   （App 启动已经有一段 6 秒的加载兜底，不该再塞一个插件初始化进去）。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// 通知通道 id：Android 8+ 的通道一旦创建，重要性就只能由用户改，
  /// 所以这里的 id 要保持永久稳定，换名字会让旧通道失效。
  static const String _channelId = 'zv_server_monitor';
  static const String _channelName = '服务器状态监控';
  static const String _channelDesc = '服务器离线、恢复与玩家上线提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permission = false;

  /// 初始化成功且拿到通知权限，才认为可以真正弹通知。
  bool get isReady => _initialized && _permission;

  /// 初始化插件与通知通道。重复调用安全。
  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    try {
      // 图标必须指向 res/drawable 下的纯白剪影，见 ic_stat_monitor.xml
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_monitor'),
      );
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (e) {
      debugPrint('通知服务初始化失败: $e');
    }
  }

  /// 请求通知权限（Android 13+ 必须运行时授权；更低版本直接视为已授权）。
  ///
  /// 返回最终是否可用。授权被拒时不影响监控继续跑，只是不弹通知。
  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    await init();
    if (!_initialized) return false;
    if (_permission) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      // 低版本系统该方法可能返回 null，此时按「已授权」处理
      _permission = granted ?? true;
    } catch (e) {
      debugPrint('请求通知权限失败: $e');
      _permission = false;
    }
    return _permission;
  }

  /// 静默检查「现在能不能发通知」：初始化插件 + 查询系统是否已允许，
  /// **不会弹授权框**。用于 App 重启后恢复监控时判断，避免每次冷启动
  /// 都拿系统权限弹窗打扰用户。
  Future<bool> _ensureReady() async {
    if (kIsWeb) return false;
    await init();
    if (!_initialized) return false;
    if (_permission) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      _permission = enabled ?? true;
    } catch (e) {
      debugPrint('查询通知开关失败: $e');
      _permission = false;
    }
    return _permission;
  }

  /// 弹一条通知。[id] 相同会覆盖上一条，调用方应使用递增 id。
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await _ensureReady()) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        // 长文本（多个玩家同时上线）展开后能看全，而不是被截断
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('发送通知失败: $e');
    }
  }
}
