import 'dart:convert';

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
  static const _chatBackgroundColorKey = 'csac.chat.background_color';
  static const _chatBackgroundImagePathKey = 'csac.chat.background_image_path';
  static const _chatVoiceContinuousPlaybackKey =
      'csac.chat.voice_continuous_playback';
  static const _chatLinuxFfmpegVoiceFallbackKey =
      'csac.chat.linux_ffmpeg_voice_fallback';

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
        backgroundColorValue: _opaqueColorFromPrefs(
          prefs,
          _chatBackgroundColorKey,
        ),
        backgroundImagePath: prefs.getString(_chatBackgroundImagePathKey) ?? '',
        voiceContinuousPlayback:
            prefs.getBool(_chatVoiceContinuousPlaybackKey) ?? false,
        linuxFfmpegVoiceFallback:
            prefs.getBool(_chatLinuxFfmpegVoiceFallbackKey) ?? false,
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
    if (chat.backgroundColorValue == 0) {
      await prefs.remove(_chatBackgroundColorKey);
    } else {
      await prefs.setInt(
        _chatBackgroundColorKey,
        _opaqueColorValue(chat.backgroundColorValue),
      );
    }
    if (chat.backgroundImagePath.trim().isEmpty) {
      await prefs.remove(_chatBackgroundImagePathKey);
    } else {
      await prefs.setString(
        _chatBackgroundImagePathKey,
        chat.backgroundImagePath.trim(),
      );
    }
    await prefs.setBool(
      _chatVoiceContinuousPlaybackKey,
      chat.voiceContinuousPlayback,
    );
    await prefs.setBool(
      _chatLinuxFfmpegVoiceFallbackKey,
      chat.linuxFfmpegVoiceFallback,
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

  static int _opaqueColorFromPrefs(SharedPreferences prefs, String key) {
    final value = prefs.getInt(key);
    if (value == null || value == 0) {
      return 0;
    }
    return _opaqueColorValue(value);
  }

  static int _opaqueColorValue(int value) {
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
    this.backgroundColorValue = 0,
    this.backgroundImagePath = '',
    this.voiceContinuousPlayback = false,
    this.linuxFfmpegVoiceFallback = false,
  });

  final bool showSeconds;
  final bool compactBubbles;
  final bool showSenderName;
  final bool tapToDismissKeyboard;
  final int backgroundColorValue;
  final String backgroundImagePath;
  final bool voiceContinuousPlayback;
  final bool linuxFfmpegVoiceFallback;

  CsacChatPreferences copyWith({
    bool? showSeconds,
    bool? compactBubbles,
    bool? showSenderName,
    bool? tapToDismissKeyboard,
    int? backgroundColorValue,
    String? backgroundImagePath,
    bool? voiceContinuousPlayback,
    bool? linuxFfmpegVoiceFallback,
  }) {
    return CsacChatPreferences(
      showSeconds: showSeconds ?? this.showSeconds,
      compactBubbles: compactBubbles ?? this.compactBubbles,
      showSenderName: showSenderName ?? this.showSenderName,
      tapToDismissKeyboard: tapToDismissKeyboard ?? this.tapToDismissKeyboard,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      voiceContinuousPlayback:
          voiceContinuousPlayback ?? this.voiceContinuousPlayback,
      linuxFfmpegVoiceFallback:
          linuxFfmpegVoiceFallback ?? this.linuxFfmpegVoiceFallback,
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

class LoginAccountRecord {
  const LoginAccountRecord({
    required this.uid,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.serverUrl,
    required this.savedAt,
    this.sessionCookies = const <String, String>{},
  });

  final int uid;
  final String username;
  final String nickname;
  final String avatar;
  final String serverUrl;
  final int savedAt;
  final Map<String, String> sessionCookies;

  bool get hasSession => sessionCookies.isNotEmpty;

  String get displayName {
    if (nickname.trim().isNotEmpty) return nickname.trim();
    if (username.trim().isNotEmpty) return username.trim();
    return 'UID $uid';
  }

  String get subtitle {
    final parts = <String>[
      if (username.trim().isNotEmpty) '@${username.trim()}',
      if (uid > 0) 'UID $uid',
    ];
    return parts.join(' | ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uid': uid,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'serverUrl': serverUrl,
      'savedAt': savedAt,
      'sessionCookies': sessionCookies,
    };
  }

  factory LoginAccountRecord.fromJson(Map<String, dynamic> json) {
    final rawCookies = json['sessionCookies'];
    return LoginAccountRecord(
      uid: asInt(json['uid']),
      username: asString(json['username']),
      nickname: asString(json['nickname']),
      avatar: asString(json['avatar']),
      serverUrl: asString(json['serverUrl']),
      savedAt: asInt(json['savedAt']),
      sessionCookies: rawCookies is Map
          ? rawCookies.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }
}

class LoginAccountStore {
  const LoginAccountStore._();

  static const _accountsKey = 'csac.login_accounts';
  static const _maxAccounts = 12;

  static Future<List<LoginAccountRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.trim().isEmpty) return const <LoginAccountRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <LoginAccountRecord>[];
      final records = <LoginAccountRecord>[];
      for (final item in decoded) {
        if (item is Map) {
          final record = LoginAccountRecord.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (record.uid > 0 || record.username.trim().isNotEmpty) {
            records.add(record);
          }
        }
      }
      records.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return records;
    } catch (_) {
      return const <LoginAccountRecord>[];
    }
  }

  static Future<List<LoginAccountRecord>> loadForServer(
    String serverUrl,
  ) async {
    final normalized = _serverKey(serverUrl);
    final records = await loadAll();
    return records
        .where((record) => _serverKey(record.serverUrl) == normalized)
        .toList();
  }

  static Future<void> upsert({
    required CsacUser user,
    required String username,
    required String serverUrl,
    required Map<String, String> sessionCookies,
  }) async {
    final normalizedUsername = username.trim().isEmpty
        ? user.username.trim()
        : username.trim();
    if (user.uid <= 0 && normalizedUsername.isEmpty) return;
    final records = await loadAll();
    final normalizedServer = _serverKey(serverUrl);
    final filtered = records.where((record) {
      if (_serverKey(record.serverUrl) != normalizedServer) return true;
      if (user.uid > 0 && record.uid == user.uid) return false;
      return normalizedUsername.isEmpty ||
          record.username.trim().toLowerCase() !=
              normalizedUsername.toLowerCase();
    }).toList();
    filtered.insert(
      0,
      LoginAccountRecord(
        uid: user.uid,
        username: normalizedUsername,
        nickname: user.nickname,
        avatar: user.avatar,
        serverUrl: normalizedServer,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        sessionCookies: Map<String, String>.from(sessionCookies),
      ),
    );
    await _save(filtered.take(_maxAccounts).toList());
  }

  static Future<void> clearSession(LoginAccountRecord record) async {
    final records = await loadAll();
    final normalizedServer = _serverKey(record.serverUrl);
    await _save([
      for (final item in records)
        if (_sameAccount(item, record, normalizedServer))
          LoginAccountRecord(
            uid: item.uid,
            username: item.username,
            nickname: item.nickname,
            avatar: item.avatar,
            serverUrl: item.serverUrl,
            savedAt: item.savedAt,
          )
        else
          item,
    ]);
  }

  static Future<void> remove(LoginAccountRecord record) async {
    final records = await loadAll();
    final normalizedServer = _serverKey(record.serverUrl);
    await _save(
      records.where((item) {
        if (_serverKey(item.serverUrl) != normalizedServer) return true;
        if (record.uid > 0 && item.uid == record.uid) return false;
        return item.username.trim().toLowerCase() !=
            record.username.trim().toLowerCase();
      }).toList(),
    );
  }

  static Future<void> _save(List<LoginAccountRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    if (records.isEmpty) {
      await prefs.remove(_accountsKey);
      return;
    }
    await prefs.setString(
      _accountsKey,
      jsonEncode([for (final record in records) record.toJson()]),
    );
  }

  static String _serverKey(String serverUrl) => serverUrl.trim();

  static bool _sameAccount(
    LoginAccountRecord item,
    LoginAccountRecord record,
    String normalizedServer,
  ) {
    if (_serverKey(item.serverUrl) != normalizedServer) return false;
    if (record.uid > 0 && item.uid == record.uid) return true;
    return item.username.trim().toLowerCase() ==
        record.username.trim().toLowerCase();
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
