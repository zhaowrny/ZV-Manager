import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/l10n/strings.dart';

/// 应用语言设置：跟随系统 / 简体中文 / English，持久化保存。
class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_language';
  LanguageMode _mode = LanguageMode.system;

  LanguageMode get mode => _mode;

  /// MaterialApp.locale：system 时传 null 跟随系统。
  Locale? get locale => switch (_mode) {
        LanguageMode.system => null,
        LanguageMode.zh => const Locale('zh', 'CN'),
        LanguageMode.en => const Locale('en', 'US'),
      };

  /// 当前是否英文（用于硬编码 UI 文案的双语切换）。
  bool get isEnglish => _mode == LanguageMode.en;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    _mode = LanguageMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => LanguageMode.system,
    );
    S.en = _mode == LanguageMode.en;
  }

  Future<void> setMode(LanguageMode mode) async {
    _mode = mode;
    S.en = mode == LanguageMode.en;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

enum LanguageMode { system, zh, en }
