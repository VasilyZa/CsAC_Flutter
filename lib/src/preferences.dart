import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CsacLanguage { en, zh }

class CsacPreferences {
  const CsacPreferences({
    this.themeMode = ThemeMode.system,
    this.language = CsacLanguage.zh,
  });

  static const _themeKey = 'csac.theme_mode';
  static const _languageKey = 'csac.language';

  final ThemeMode themeMode;
  final CsacLanguage language;

  CsacPreferences copyWith({ThemeMode? themeMode, CsacLanguage? language}) {
    return CsacPreferences(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
    );
  }

  static Future<CsacPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CsacPreferences(
      themeMode: _themeModeFromName(prefs.getString(_themeKey)),
      language: _languageFromName(prefs.getString(_languageKey)),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
    await prefs.setString(_languageKey, language.name);
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
