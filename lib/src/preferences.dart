import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CsacLanguage { en, zh }

class CsacPreferences {
  const CsacPreferences({
    this.themeMode = ThemeMode.system,
    this.language = CsacLanguage.zh,
    this.serverUrl = '',
  });

  static const _themeKey = 'csac.theme_mode';
  static const _languageKey = 'csac.language';
  static const _serverUrlKey = 'csac.server_url';

  final ThemeMode themeMode;
  final CsacLanguage language;
  final String serverUrl;

  CsacPreferences copyWith({
    ThemeMode? themeMode,
    CsacLanguage? language,
    String? serverUrl,
  }) {
    return CsacPreferences(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  static Future<CsacPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CsacPreferences(
      themeMode: _themeModeFromName(prefs.getString(_themeKey)),
      language: _languageFromName(prefs.getString(_languageKey)),
      serverUrl: (prefs.getString(_serverUrlKey) ?? '').trim(),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
    await prefs.setString(_languageKey, language.name);
    if (serverUrl.trim().isEmpty) {
      await prefs.remove(_serverUrlKey);
    } else {
      await prefs.setString(_serverUrlKey, serverUrl.trim());
    }
  }

  static ThemeMode _themeModeFromName(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ThemeMode.system;
  }

  static CsacLanguage _languageFromName(String? value) {
    for (final language in CsacLanguage.values) {
      if (language.name == value) {
        return language;
      }
    }
    return CsacLanguage.zh;
  }
}
