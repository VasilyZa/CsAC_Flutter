import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum CsacLanguage { en, zh }

const defaultThemeColorValue = 0xff1f8a70;

class CsacPreferences {
  const CsacPreferences({
    this.themeMode = ThemeMode.system,
    this.themeColorValue = defaultThemeColorValue,
    this.language = CsacLanguage.zh,
    this.serverUrl = '',
    this.chat = const CsacChatPreferences(),
  });

  static const _themeKey = 'csac.theme_mode';
  static const _themeColorKey = 'csac.theme_color';
  static const _languageKey = 'csac.language';
  static const _serverUrlKey = 'csac.server_url';
  static const _chatShowSecondsKey = 'csac.chat.show_seconds';
  static const _chatCompactBubblesKey = 'csac.chat.compact_bubbles';
  static const _chatShowSenderNameKey = 'csac.chat.show_sender_name';
  static const _chatTapToDismissKeyboardKey =
      'csac.chat.tap_to_dismiss_keyboard';

  final ThemeMode themeMode;
  final int themeColorValue;
  final CsacLanguage language;
  final String serverUrl;
  final CsacChatPreferences chat;

  CsacPreferences copyWith({
    ThemeMode? themeMode,
    int? themeColorValue,
    CsacLanguage? language,
    String? serverUrl,
    CsacChatPreferences? chat,
  }) {
    return CsacPreferences(
      themeMode: themeMode ?? this.themeMode,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      language: language ?? this.language,
      serverUrl: serverUrl ?? this.serverUrl,
      chat: chat ?? this.chat,
    );
  }

  static Future<CsacPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CsacPreferences(
      themeMode: _themeModeFromName(prefs.getString(_themeKey)),
      themeColorValue: _themeColorFromPrefs(prefs),
      language: _languageFromName(prefs.getString(_languageKey)),
      serverUrl: (prefs.getString(_serverUrlKey) ?? '').trim(),
      chat: CsacChatPreferences(
        showSeconds: prefs.getBool(_chatShowSecondsKey) ?? false,
        compactBubbles: prefs.getBool(_chatCompactBubblesKey) ?? false,
        showSenderName: prefs.getBool(_chatShowSenderNameKey) ?? true,
        tapToDismissKeyboard:
            prefs.getBool(_chatTapToDismissKeyboardKey) ?? true,
      ),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
    await prefs.setInt(_themeColorKey, themeColorValue);
    await prefs.setString(_languageKey, language.name);
    await prefs.setBool(_chatShowSecondsKey, chat.showSeconds);
    await prefs.setBool(_chatCompactBubblesKey, chat.compactBubbles);
    await prefs.setBool(_chatShowSenderNameKey, chat.showSenderName);
    await prefs.setBool(
      _chatTapToDismissKeyboardKey,
      chat.tapToDismissKeyboard,
    );
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

class CsacChatPreferences {
  const CsacChatPreferences({
    this.showSeconds = false,
    this.compactBubbles = false,
    this.showSenderName = true,
    this.tapToDismissKeyboard = true,
  });

  final bool showSeconds;
  final bool compactBubbles;
  final bool showSenderName;
  final bool tapToDismissKeyboard;

  CsacChatPreferences copyWith({
    bool? showSeconds,
    bool? compactBubbles,
    bool? showSenderName,
    bool? tapToDismissKeyboard,
  }) {
    return CsacChatPreferences(
      showSeconds: showSeconds ?? this.showSeconds,
      compactBubbles: compactBubbles ?? this.compactBubbles,
      showSenderName: showSenderName ?? this.showSenderName,
      tapToDismissKeyboard: tapToDismissKeyboard ?? this.tapToDismissKeyboard,
    );
  }
}

class ConversationDraftStore {
  const ConversationDraftStore._();

  static const _draftPrefix = 'csac.draft.';

  static String _key(Conversation conversation) {
    return '$_draftPrefix${conversation.type.name}:${conversation.id}';
  }

  static Future<String> load(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(conversation)) ?? '';
  }

  static Future<void> save(Conversation conversation, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = text.trimRight();
    if (normalized.trim().isEmpty) {
      await prefs.remove(_key(conversation));
      return;
    }
    await prefs.setString(_key(conversation), normalized);
  }

  static Future<void> clear(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(conversation));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_draftPrefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

class MutedConversationStore {
  const MutedConversationStore._();

  static const _key = 'csac.muted_conversations';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> save(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, keys.toList()..sort());
  }
}

class PinnedConversationStore {
  const PinnedConversationStore._();

  static const _key = 'csac.pinned_conversations';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> save(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, keys.toList()..sort());
  }
}

class DismissedBadgeStore {
  const DismissedBadgeStore._();

  static const _key = 'csac.dismissed_badges';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> save(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    if (keys.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setStringList(_key, keys.toList()..sort());
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
