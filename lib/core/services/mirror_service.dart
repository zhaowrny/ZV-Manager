import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n/strings.dart';

/// 镜像源服务：内置 MCIM（Modrinth 国内镜像），支持自定义线路与一键测速。
class MirrorService extends ChangeNotifier {
  static const _prefKey = 'mirror_line';

  /// 内置镜像线路：id → 名称。'official' 为 Modrinth 官方源。
  static Map<String, String> get builtinMirrors => {
    'official': S.t('Modrinth 官方'),
    'mcim': S.t('MCIM 国内镜像 (mcimirror.top)'),
  };

  String _current = 'mcim';
  String _customUrl = '';
  int lastSpeedMs = -1;

  String get currentId => _current;
  String get customUrl => _customUrl;

  String get currentName {
    if (_current == 'custom') return S.f('自定义 ({0})', [_customUrl]);
    return builtinMirrors[_current] ?? _current;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _current = prefs.getString(_prefKey) ?? 'mcim';
    _customUrl = prefs.getString('${_prefKey}_custom') ?? '';
    notifyListeners();
  }

  Future<void> select(String id, {String customUrl = ''}) async {
    _current = id;
    if (customUrl.isNotEmpty) _customUrl = customUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
    await prefs.setString('${_prefKey}_custom', _customUrl);
    notifyListeners();
  }

  /// 把 Modrinth 官方域名改写为镜像域名。
  /// MCIM 镜像规则：api.modrinth.com → modrinth-api.mcimirror.top
  ///             cdn.modrinth.com → modrinth-cdn.mcimirror.top
  String rewrite(String url) {
    final uri = Uri.parse(url);
    if (_current == 'official') return url;
    if (_current == 'custom') {
      if (_customUrl.isEmpty) return url;
      final base = Uri.parse(_customUrl.endsWith('/')
          ? _customUrl.substring(0, _customUrl.length - 1)
          : _customUrl);
      // 自定义镜像：假定其结构与官方一致（api./cdn. 前缀由 base 提供，路径不变）
      if (uri.host == 'api.modrinth.com' || uri.host == 'cdn.modrinth.com') {
        return base.replace(path: uri.path, query: uri.query).toString();
      }
      return url;
    }
    // MCIM
    final newHost = uri.host == 'api.modrinth.com'
        ? 'modrinth-api.mcimirror.top'
        : uri.host == 'cdn.modrinth.com'
            ? 'modrinth-cdn.mcimirror.top'
            : uri.host;
    return uri.replace(host: newHost).toString();
  }

  /// 测速：对镜像的 api 域名发 HEAD 请求，返回毫秒数；失败返回 -1。
  Future<int> speedTest(String mirrorId) async {
    final String probe = switch (mirrorId) {
      'official' => 'https://api.modrinth.com/v2/project/sodium/version?limit=1',
      'mcim' => 'https://modrinth-api.mcimirror.top/v2/project/sodium/version?limit=1',
      _ => _customUrl,
    };
    if (probe.isEmpty) return -1;
    final sw = Stopwatch()..start();
    try {
      await Dio().head(probe, options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  /// 自动选择测速最快的线路（官方算作兜底）。
  Future<String> autoSelect() async {
    final results = <String, int>{};
    for (final id in ['mcim', 'official']) {
      results[id] = await speedTest(id);
    }
    final usable = results.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final best = usable.isNotEmpty ? usable.first.key : 'official';
    await select(best);
    return best;
  }
}
