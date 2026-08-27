import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class RconPacket {
  final int length;
  final int id;
  final int type;
  final String payload;

  RconPacket({
    required this.length,
    required this.id,
    required this.type,
    required this.payload,
  });
}

class RconStreamParser extends StreamTransformerBase<Uint8List, RconPacket> {
  @override
  Stream<RconPacket> bind(Stream<Uint8List> stream) async* {
    BytesBuilder buffer = BytesBuilder();

    await for (final chunk in stream) {
      buffer.add(chunk);
      var bytes = buffer.toBytes();

      while (bytes.length >= 4) {
        final byteData = ByteData.sublistView(bytes);
        final packetLength = byteData.getInt32(0, Endian.little);
        final totalSize = 4 + packetLength;

        if (bytes.length < totalSize) break;

        final packetBytes = bytes.sublist(4, totalSize);
        final packetData = ByteData.sublistView(packetBytes);

        if (packetBytes.length >= 10) {
          yield RconPacket(
            length: packetLength,
            id: packetData.getInt32(0, Endian.little),
            type: packetData.getInt32(4, Endian.little),
            payload: utf8.decode(
              packetBytes.sublist(8, packetBytes.length - 2),
              allowMalformed: true,
            ),
          );
        }

        bytes = bytes.sublist(totalSize);
      }

      buffer.clear();
      if (bytes.isNotEmpty) buffer.add(bytes);
    }
  }
}
