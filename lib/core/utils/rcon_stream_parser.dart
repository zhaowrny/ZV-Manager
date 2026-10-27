import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// 一条已解析的 RCON 数据包。
///
/// RCON 协议（Source RCON）线上格式为小端序：
/// ```
/// [4B 包长 length][4B 请求 id][4B 包类型 type][payload...][2B 结束符 0x00 0x00]
/// ```
/// 其中 `length` 只统计其后的部分（id + type + payload + 2 字节结束符）。
class RconPacket {
  /// 包体长度（不含开头的 4 字节自身）
  final int length;

  /// 请求 id，用于把响应与请求配对；认证失败时服务器返回 -1
  final int id;

  /// 包类型：2=执行命令，3=认证，0=响应
  final int type;

  /// 解码后的正文（已剔除末尾结束符）
  final String payload;

  RconPacket({
    required this.length,
    required this.id,
    required this.type,
    required this.payload,
  });
}

/// 把 TCP 的字节流切分成一条条 [RconPacket]。
///
/// TCP 是流式协议，一次 `data` 事件可能带来半个包，也可能带来多个包，
/// 因此这里维护一个 [BytesBuilder] 缓冲区：
/// 1. 新数据追加到缓冲区；
/// 2. 循环从头部读 4 字节长度 → 判断缓冲区是否够一整包；
/// 3. 不够就 `break` 等下一次数据；够就切出来解析，继续下一个；
/// 4. 剩余未消费的尾巴放回缓冲区。
class RconStreamParser extends StreamTransformerBase<Uint8List, RconPacket> {
  @override
  Stream<RconPacket> bind(Stream<Uint8List> stream) async* {
    BytesBuilder buffer = BytesBuilder();

    await for (final chunk in stream) {
      buffer.add(chunk);
      var bytes = buffer.toBytes();

      // 至少要有 4 字节才能读出包长
      while (bytes.length >= 4) {
        final byteData = ByteData.sublistView(bytes);
        final packetLength = byteData.getInt32(0, Endian.little);
        // 整包长度 = 长度字段自身的 4 字节 + 包体长度
        final totalSize = 4 + packetLength;

        // 半包：等更多数据到达
        if (bytes.length < totalSize) break;

        final packetBytes = bytes.sublist(4, totalSize);
        final packetData = ByteData.sublistView(packetBytes);

        // 最小合法包体为 10 字节（id 4 + type 4 + 结束符 2）
        if (packetBytes.length >= 10) {
          yield RconPacket(
            length: packetLength,
            id: packetData.getInt32(0, Endian.little),
            type: packetData.getInt32(4, Endian.little),
            // 去掉末尾 2 字节结束符；allowMalformed 防止服务端发来非 UTF-8 时整条流崩溃
            payload: utf8.decode(
              packetBytes.sublist(8, packetBytes.length - 2),
              allowMalformed: true,
            ),
          );
        }

        bytes = bytes.sublist(totalSize);
      }

      // 用剩余未消费的字节重建缓冲区
      buffer.clear();
      if (bytes.isNotEmpty) buffer.add(bytes);
    }
  }
}
