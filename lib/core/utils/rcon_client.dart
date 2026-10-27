import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'rcon_stream_parser.dart';
import '../../core/l10n/strings.dart';

/// 去除 Minecraft 消息中的颜色/格式码（§ 后跟一个有效字符）。
///
/// 服务端命令回显常带 `§a`（绿）、`§l`（加粗）等格式符，
/// 直接显示在 Flutter 文本里会变成乱码方块，这里统一剥掉。
String stripMinecraftCodes(String input) {
  return input.replaceAll(RegExp(r'\u00a7[0-9A-Fa-fK-ORk-or]'), '');
}

/// RCON 客户端：与 Minecraft 服务端建立长连接，发送控制台命令。
///
/// 生命周期：
/// ```
/// connect() → executeCommand(...) × N → disconnect()
///               ↑______ 心跳失败自动重连 ______|
/// ```
///
/// 关键设计：
/// - **请求配对**：每条命令分配自增 id，响应按 id 找回对应的 Completer；
/// - **心跳保活**：每 30 秒发一次 `list`，失败即判定掉线；
/// - **指数退避重连**：1s → 2s → 4s … 封顶 60s，最多 10 次。
class RconClient {
  Socket? _socket;

  /// 请求 id 自增计数器，用于把响应和请求配对
  int _requestId = 0;

  bool _isAuthenticated = false;

  /// 在途请求表：id → 等待响应的 Completer
  final Map<int, Completer<RconPacket?>> _pendingRequests = {};

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;

  /// 心跳间隔：太短会给服务端造成无谓负担，太长则掉线发现不及时
  static const _heartbeatInterval = Duration(seconds: 30);

  /// 连接断开 / 重连成功的外部回调，供 UI 层更新状态
  VoidCallback? onDisconnected;
  VoidCallback? onReconnected;

  // 缓存连接参数，用于自动重连
  String? _host;
  int? _port;
  String? _password;
  bool _autoReconnect = true;

  bool get isConnected => _isAuthenticated && _socket != null;

  /// 建立 TCP 连接并完成 RCON 认证。
  ///
  /// 返回 true 表示认证成功；抛异常表示网络层连不上。
  Future<bool> connect(
    String host,
    int port,
    String password, {
    bool autoReconnect = true,
  }) async {
    _host = host;
    _port = port;
    _password = password;
    _autoReconnect = autoReconnect;

    try {
      // 5 秒超时：避免弱网下界面长时间卡在加载态
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      // 绑定解析器：收到完整包后，按 id 唤醒等待中的请求
      _socket!.transform(RconStreamParser()).listen((parsed) {
        final completer = _pendingRequests.remove(parsed.id);
        completer?.complete(parsed);
      });

      // type=3 为认证包，payload 即密码（明文，故 RCON 必须走内网或 SSH 隧道）
      final authResponse = await _sendPacket(3, password);
      // 认证失败时服务端返回 id = -1，这是协议层的约定
      _isAuthenticated = authResponse != null && authResponse.id != -1;

      if (_isAuthenticated) {
        _reconnectAttempts = 0;
        _startHeartbeat();
      }
      return _isAuthenticated;
    } catch (e) {
      disconnect();
      rethrow;
    }
  }

  /// 执行一条控制台命令，返回服务端原文（可能为 null 表示超时）。
  Future<String?> executeCommand(String command) async {
    if (!_isAuthenticated || _socket == null) {
      throw Exception(S.t('RCON 未连接或未认证'));
    }
    // type=2 为命令包
    final response = await _sendPacket(2, command);
    return response?.payload;
  }

  /// 主动断开：取消定时器、销毁 socket、清空认证状态。
  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _socket?.destroy();
    _socket = null;
    _isAuthenticated = false;
  }

  /// 启动心跳：周期性发 `list`（最轻量的命令），失败即视为掉线。
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        await executeCommand('list');
      } catch (_) {
        _handleDisconnect();
      }
    });
  }

  /// 掉线处理：通知 UI，并按指数退避安排重连。
  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    onDisconnected?.call();

    if (!_autoReconnect || _reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
    // 指数退避：2^(n-1) 秒，最长 60 秒；避免服务端刚崩溃时被反复重连打爆
    final delay = Duration(
      seconds: min(60, pow(2, _reconnectAttempts - 1).toInt()),
    );

    _reconnectTimer = Timer(delay, () async {
      try {
        final success = await connect(
          _host!,
          _port!,
          _password!,
          autoReconnect: true,
        );
        if (success) onReconnected?.call();
      } catch (_) {}
    });
  }

  /// 发送一个包并等待对应 id 的响应（5 秒超时）。
  ///
  /// 超时说明连接已不可用，直接销毁连接，由调用方或重连机制重建。
  Future<RconPacket?> _sendPacket(int type, String payload) async {
    final id = ++_requestId;
    final packet = _buildPacket(id, type, payload);
    final completer = Completer<RconPacket?>();

    _pendingRequests[id] = completer;
    _socket!.add(packet);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(id);
        // 请求超时：连接已失效，销毁后由下次调用重新建立
        disconnect();
        return null;
      },
    );
  }

  /// 按协议拼装二进制包（小端序）。
  ///
  /// 结构：length | id | type | payload | 0x00 0x00
  /// 其中 length = 4(id) + 4(type) + payload 长度 + 2(结束符)。
  Uint8List _buildPacket(int id, int type, String payload) {
    final payloadBytes = utf8.encode(payload);
    final length = 4 + 4 + payloadBytes.length + 2;
    final buffer = BytesBuilder();

    final lengthData = ByteData(4);
    lengthData.setInt32(0, length, Endian.little);
    buffer.add(lengthData.buffer.asUint8List());

    final idData = ByteData(4);
    idData.setInt32(0, id, Endian.little);
    buffer.add(idData.buffer.asUint8List());

    final typeData = ByteData(4);
    typeData.setInt32(0, type, Endian.little);
    buffer.add(typeData.buffer.asUint8List());

    buffer.add(payloadBytes);
    // 协议要求以两个 0x00 结尾
    buffer.add([0, 0]);

    return buffer.toBytes();
  }
}
