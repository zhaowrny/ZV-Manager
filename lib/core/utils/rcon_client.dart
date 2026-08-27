import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'rcon_stream_parser.dart';

/// 去除 Minecraft 消息中的颜色/格式码（§ 后跟一个有效字符）。
String stripMinecraftCodes(String input) {
  return input.replaceAll(RegExp(r'\u00a7[0-9A-Fa-fK-ORk-or]'), '');
}

class RconClient {
  Socket? _socket;
  int _requestId = 0;
  bool _isAuthenticated = false;
  final Map<int, Completer<RconPacket?>> _pendingRequests = {};

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;
  static const _heartbeatInterval = Duration(seconds: 30);

  VoidCallback? onDisconnected;
  VoidCallback? onReconnected;

  String? _host;
  int? _port;
  String? _password;
  bool _autoReconnect = true;

  bool get isConnected => _isAuthenticated && _socket != null;

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
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      _socket!.transform(RconStreamParser()).listen((parsed) {
        final completer = _pendingRequests.remove(parsed.id);
        completer?.complete(parsed);
      });

      final authResponse = await _sendPacket(3, password);
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

  Future<String?> executeCommand(String command) async {
    if (!_isAuthenticated || _socket == null) {
      throw Exception('RCON 未连接或未认证');
    }
    final response = await _sendPacket(2, command);
    return response?.payload;
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _socket?.destroy();
    _socket = null;
    _isAuthenticated = false;
  }

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

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    onDisconnected?.call();

    if (!_autoReconnect || _reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
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
    buffer.add([0, 0]);

    return buffer.toBytes();
  }
}
