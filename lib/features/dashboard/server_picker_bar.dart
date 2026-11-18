import 'package:flutter/foundation.dart';
import '../../providers/server_provider.dart';

/// 跨页签共享的「当前选中服务器」。
/// Dashboard / 模组 / 终端 / 下载上传目标等页签共用此状态。
class SelectedServerHolder extends ChangeNotifier {
  ServerConfig? _server;

  ServerConfig? get server => _server;

  void select(ServerConfig? s) {
    _server = s;
    notifyListeners();
  }
}
