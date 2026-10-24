import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n/strings.dart';

/// 快速命令预设。
class QuickCommandPreset {
  final String label;
  final String command;

  const QuickCommandPreset({required this.label, required this.command});

  Map<String, dynamic> toJson() => {'label': label, 'command': command};

  factory QuickCommandPreset.fromJson(Map<String, dynamic> json) =>
      QuickCommandPreset(
        label: json['label'] as String? ?? '',
        command: json['command'] as String? ?? '',
      );
}

/// 快速命令预设的持久化存储（基于 SharedPreferences）。
class CommandPresetService {
  static const _key = 'mc_quick_commands_v1';

  /// 默认预设，首次使用或清空后恢复。
  static List<QuickCommandPreset> get defaultPresets => <QuickCommandPreset>[
    QuickCommandPreset(label: S.t('在线列表'), command: 'list'),
    QuickCommandPreset(label: S.t('立即存档'), command: 'save-all'),
    QuickCommandPreset(label: S.t('查看种子'), command: 'seed'),
    QuickCommandPreset(label: S.t('晴天'), command: 'weather clear'),
    QuickCommandPreset(label: S.t('设为白天'), command: 'time set day'),
    QuickCommandPreset(label: S.t('设为黑夜'), command: 'time set night'),
    QuickCommandPreset(label: S.t('和平难度'), command: 'difficulty peaceful'),
    QuickCommandPreset(label: S.t('白名单列表'), command: 'whitelist list'),
    QuickCommandPreset(label: S.t('在线公告'), command: 'say 服务器已在线，欢迎游玩！'),
  ];

  static Future<List<QuickCommandPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return List.of(defaultPresets);
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => QuickCommandPreset.fromJson(e as Map<String, dynamic>))
          .where((p) => p.label.isNotEmpty && p.command.isNotEmpty)
          .toList();
    } catch (_) {
      return List.of(defaultPresets);
    }
  }

  static Future<void> save(List<QuickCommandPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(presets.map((p) => p.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
