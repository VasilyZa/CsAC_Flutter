import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CsacLanguage { en, zh }

const defaultThemeColorValue = 0xff1f8a70;

class CsacPreferences {
  const CsacPreferences({
    this.themeMode = ThemeMode.system,
    this.themeColorValue = defaultThemeColorValue,
    this.language = CsacLanguage.zh,
    this.serverUrl = '',
  });

  static const _themeKey = 'csac.theme_mode';
  static const _themeColorKey = 'csac.theme_color';
  static const _languageKey = 'csac.language';
  static const _serverUrlKey = 'csac.server_url';

  final ThemeMode themeMode;
  final int themeColorValue;
  final CsacLanguage language;
  final String serverUrl;

  CsacPreferences copyWith({
    ThemeMode? themeMode,
    int? themeColorValue,
    CsacLanguage? language,
    String? serverUrl,
  }) {
    return CsacPreferences(
      themeMode: themeMode ?? this.themeMode,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      language: language ?? this.language,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  static Future<CsacPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CsacPreferences(
      themeMode: _themeModeFromName(prefs.getString(_themeKey)),
      themeColorValue: _themeColorFromPrefs(prefs),
      language: _languageFromName(prefs.getString(_languageKey)),
      serverUrl: (prefs.getString(_serverUrlKey) ?? '').trim(),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
    await prefs.setInt(_themeColorKey, themeColorValue);
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

  static int _themeColorFromPrefs(SharedPreferences prefs) {
    final value = prefs.getInt(_themeColorKey);
    if (value == null) {
      return defaultThemeColorValue;
    }
    return 0xff000000 | (value & 0x00ffffff);
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
