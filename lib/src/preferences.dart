import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum CsacLanguage { en, zh }

enum ThemeMode { system, light, dark }

enum ConversationSortMode { latest, type }

enum ConversationSubtitleMode { recentMessage, status }

enum MessageTimeFormat { slash, dash, compact, timeOnly }

enum CsacFontStyle { system, serif, rounded, monospace }

enum ChatBubbleCornerStyle { telegram, ios, qq }

enum GroupMemberBadgeMode { title, role }

const defaultThemeColorValue = 0xff2563eb;
const defaultChatBubbleColorValue = 0;
const defaultChatBubbleOpacity = 1.0;

class CsacPreferences {
  const CsacPreferences({
    this.themeMode = ThemeMode.system,
    this.themeColorValue = defaultThemeColorValue,
    this.language = CsacLanguage.zh,
    this.fontStyle = CsacFontStyle.system,
    this.conversationSortMode = ConversationSortMode.latest,
    this.conversationSubtitleMode = ConversationSubtitleMode.recentMessage,
    this.messageTimeFormat = MessageTimeFormat.slash,
    this.chatBubbleCornerStyle = ChatBubbleCornerStyle.telegram,
    this.ownChatBubbleColorValue = defaultChatBubbleColorValue,
    this.otherChatBubbleColorValue = defaultChatBubbleColorValue,
    this.chatBubbleOpacity = defaultChatBubbleOpacity,
    this.chatBackgroundPath = '',
    this.serverUrl = '',
    this.reduceMotion = false,
    this.showChatAvatars = true,
    this.enablePat = true,
    this.enableQuickInputTriggers = true,
    this.showGroupMemberLevel = true,
    this.groupMemberBadgeMode = GroupMemberBadgeMode.title,
    this.appLockEnabled = false,
    this.appLockPinSalt = '',
    this.appLockPinHash = '',
    this.appLockBiometricEnabled = false,
    this.autoCheckVersionUpdates = true,
    this.localSystemNotificationsEnabled = true,
  });

  static const _themeKey = 'csac.theme_mode';
  static const _themeColorKey = 'csac.theme_color';
  static const _languageKey = 'csac.language';
  static const _fontStyleKey = 'csac.font_style';
  static const _conversationSortModeKey = 'csac.conversation_sort_mode';
  static const _conversationSubtitleModeKey = 'csac.conversation_subtitle_mode';
  static const _messageTimeFormatKey = 'csac.message_time_format';
  static const _chatBubbleCornerStyleKey = 'csac.chat.bubble_corner_style';
  static const _ownChatBubbleColorKey = 'csac.chat.own_bubble_color';
  static const _otherChatBubbleColorKey = 'csac.chat.other_bubble_color';
  static const _chatBubbleOpacityKey = 'csac.chat.bubble_opacity';
  static const _chatBackgroundPathKey = 'csac.chat_background_path';
  static const _serverUrlKey = 'csac.server_url';
  static const _reduceMotionKey = 'csac.reduce_motion';
  static const _showChatAvatarsKey = 'csac.chat.show_avatars';
  static const _enablePatKey = 'csac.chat.enable_pat';
  static const _enableQuickInputTriggersKey =
      'csac.chat.enable_quick_input_triggers';
  static const _showGroupMemberLevelKey = 'csac.chat.show_group_member_level';
  static const _groupMemberBadgeModeKey = 'csac.chat.group_member_badge_mode';
  static const _appLockEnabledKey = 'csac.app_lock.enabled';
  static const _appLockPinSaltKey = 'csac.app_lock.pin_salt';
  static const _appLockPinHashKey = 'csac.app_lock.pin_hash';
  static const _appLockBiometricEnabledKey = 'csac.app_lock.biometric_enabled';
  static const _autoCheckVersionUpdatesKey = 'csac.updates.auto_check_version';
  static const _localSystemNotificationsKey = 'csac.notifications.local_system';

  final ThemeMode themeMode;
  final int themeColorValue;
  final CsacLanguage language;
  final CsacFontStyle fontStyle;
  final ConversationSortMode conversationSortMode;
  final ConversationSubtitleMode conversationSubtitleMode;
  final MessageTimeFormat messageTimeFormat;
  final ChatBubbleCornerStyle chatBubbleCornerStyle;
  final int ownChatBubbleColorValue;
  final int otherChatBubbleColorValue;
  final double chatBubbleOpacity;
  final String chatBackgroundPath;
  final String serverUrl;
  final bool reduceMotion;
  final bool showChatAvatars;
  final bool enablePat;
  final bool enableQuickInputTriggers;
  final bool showGroupMemberLevel;
  final GroupMemberBadgeMode groupMemberBadgeMode;
  final bool appLockEnabled;
  final String appLockPinSalt;
  final String appLockPinHash;
  final bool appLockBiometricEnabled;
  final bool autoCheckVersionUpdates;
  final bool localSystemNotificationsEnabled;

  bool get hasAppLockPin =>
      appLockPinSalt.trim().isNotEmpty && appLockPinHash.trim().isNotEmpty;

  bool get effectiveAppLockEnabled => appLockEnabled && hasAppLockPin;

  bool verifyAppLockPin(String pin) {
    if (!hasAppLockPin) {
      return false;
    }
    return AppLockPin.hash(pin, appLockPinSalt) == appLockPinHash;
  }

  CsacPreferences copyWith({
    ThemeMode? themeMode,
    int? themeColorValue,
    CsacLanguage? language,
    CsacFontStyle? fontStyle,
    ConversationSortMode? conversationSortMode,
    ConversationSubtitleMode? conversationSubtitleMode,
    MessageTimeFormat? messageTimeFormat,
    ChatBubbleCornerStyle? chatBubbleCornerStyle,
    int? ownChatBubbleColorValue,
    int? otherChatBubbleColorValue,
    double? chatBubbleOpacity,
    String? chatBackgroundPath,
    String? serverUrl,
    bool? reduceMotion,
    bool? showChatAvatars,
    bool? enablePat,
    bool? enableQuickInputTriggers,
    bool? showGroupMemberLevel,
    GroupMemberBadgeMode? groupMemberBadgeMode,
    bool? appLockEnabled,
    String? appLockPinSalt,
    String? appLockPinHash,
    bool? appLockBiometricEnabled,
    bool? autoCheckVersionUpdates,
    bool? localSystemNotificationsEnabled,
  }) {
    return CsacPreferences(
      themeMode: themeMode ?? this.themeMode,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      language: language ?? this.language,
      fontStyle: fontStyle ?? this.fontStyle,
      conversationSortMode: conversationSortMode ?? this.conversationSortMode,
      conversationSubtitleMode:
          conversationSubtitleMode ?? this.conversationSubtitleMode,
      messageTimeFormat: messageTimeFormat ?? this.messageTimeFormat,
      chatBubbleCornerStyle:
          chatBubbleCornerStyle ?? this.chatBubbleCornerStyle,
      ownChatBubbleColorValue:
          ownChatBubbleColorValue ?? this.ownChatBubbleColorValue,
      otherChatBubbleColorValue:
          otherChatBubbleColorValue ?? this.otherChatBubbleColorValue,
      chatBubbleOpacity: chatBubbleOpacity ?? this.chatBubbleOpacity,
      chatBackgroundPath: chatBackgroundPath ?? this.chatBackgroundPath,
      serverUrl: serverUrl ?? this.serverUrl,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      showChatAvatars: showChatAvatars ?? this.showChatAvatars,
      enablePat: enablePat ?? this.enablePat,
      enableQuickInputTriggers:
          enableQuickInputTriggers ?? this.enableQuickInputTriggers,
      showGroupMemberLevel: showGroupMemberLevel ?? this.showGroupMemberLevel,
      groupMemberBadgeMode: groupMemberBadgeMode ?? this.groupMemberBadgeMode,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPinSalt: appLockPinSalt ?? this.appLockPinSalt,
      appLockPinHash: appLockPinHash ?? this.appLockPinHash,
      appLockBiometricEnabled:
          appLockBiometricEnabled ?? this.appLockBiometricEnabled,
      autoCheckVersionUpdates:
          autoCheckVersionUpdates ?? this.autoCheckVersionUpdates,
      localSystemNotificationsEnabled:
          localSystemNotificationsEnabled ??
          this.localSystemNotificationsEnabled,
    );
  }

  static Future<CsacPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CsacPreferences(
      themeMode: _themeModeFromName(prefs.getString(_themeKey)),
      themeColorValue: _themeColorFromPrefs(prefs),
      language: _languageFromName(prefs.getString(_languageKey)),
      fontStyle: _fontStyleFromName(prefs.getString(_fontStyleKey)),
      conversationSortMode: _conversationSortModeFromName(
        prefs.getString(_conversationSortModeKey),
      ),
      conversationSubtitleMode: _conversationSubtitleModeFromName(
        prefs.getString(_conversationSubtitleModeKey),
      ),
      messageTimeFormat: _messageTimeFormatFromName(
        prefs.getString(_messageTimeFormatKey),
      ),
      chatBubbleCornerStyle: _chatBubbleCornerStyleFromName(
        prefs.getString(_chatBubbleCornerStyleKey),
      ),
      ownChatBubbleColorValue: _chatBubbleColorFromPrefs(
        prefs,
        _ownChatBubbleColorKey,
      ),
      otherChatBubbleColorValue: _chatBubbleColorFromPrefs(
        prefs,
        _otherChatBubbleColorKey,
      ),
      chatBubbleOpacity: _chatBubbleOpacityFromPrefs(prefs),
      chatBackgroundPath: prefs.getString(_chatBackgroundPathKey) ?? '',
      serverUrl: _serverUrlFromPrefs(prefs.getString(_serverUrlKey)),
      reduceMotion: prefs.getBool(_reduceMotionKey) ?? false,
      showChatAvatars: prefs.getBool(_showChatAvatarsKey) ?? true,
      enablePat: prefs.getBool(_enablePatKey) ?? true,
      enableQuickInputTriggers:
          prefs.getBool(_enableQuickInputTriggersKey) ?? true,
      showGroupMemberLevel: prefs.getBool(_showGroupMemberLevelKey) ?? true,
      groupMemberBadgeMode: _groupMemberBadgeModeFromName(
        prefs.getString(_groupMemberBadgeModeKey),
      ),
      appLockEnabled: prefs.getBool(_appLockEnabledKey) ?? false,
      appLockPinSalt: prefs.getString(_appLockPinSaltKey) ?? '',
      appLockPinHash: prefs.getString(_appLockPinHashKey) ?? '',
      appLockBiometricEnabled:
          prefs.getBool(_appLockBiometricEnabledKey) ?? false,
      autoCheckVersionUpdates:
          prefs.getBool(_autoCheckVersionUpdatesKey) ?? true,
      localSystemNotificationsEnabled:
          prefs.getBool(_localSystemNotificationsKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
    await prefs.setInt(_themeColorKey, themeColorValue);
    await prefs.setString(_languageKey, language.name);
    await prefs.setString(_fontStyleKey, fontStyle.name);
    await prefs.setString(_conversationSortModeKey, conversationSortMode.name);
    await prefs.setString(
      _conversationSubtitleModeKey,
      conversationSubtitleMode.name,
    );
    await prefs.setString(_messageTimeFormatKey, messageTimeFormat.name);
    await prefs.setString(
      _chatBubbleCornerStyleKey,
      chatBubbleCornerStyle.name,
    );
    if (ownChatBubbleColorValue == defaultChatBubbleColorValue) {
      await prefs.remove(_ownChatBubbleColorKey);
    } else {
      await prefs.setInt(_ownChatBubbleColorKey, ownChatBubbleColorValue);
    }
    if (otherChatBubbleColorValue == defaultChatBubbleColorValue) {
      await prefs.remove(_otherChatBubbleColorKey);
    } else {
      await prefs.setInt(_otherChatBubbleColorKey, otherChatBubbleColorValue);
    }
    await prefs.setDouble(_chatBubbleOpacityKey, chatBubbleOpacity);
    if (chatBackgroundPath.trim().isEmpty) {
      await prefs.remove(_chatBackgroundPathKey);
    } else {
      await prefs.setString(_chatBackgroundPathKey, chatBackgroundPath.trim());
    }
    if (serverUrl.trim().isEmpty) {
      await prefs.remove(_serverUrlKey);
    } else {
      await prefs.setString(_serverUrlKey, serverUrl.trim());
    }
    await prefs.setBool(_reduceMotionKey, reduceMotion);
    await prefs.setBool(_showChatAvatarsKey, showChatAvatars);
    await prefs.setBool(_enablePatKey, enablePat);
    await prefs.setBool(_enableQuickInputTriggersKey, enableQuickInputTriggers);
    await prefs.setBool(_showGroupMemberLevelKey, showGroupMemberLevel);
    await prefs.setString(_groupMemberBadgeModeKey, groupMemberBadgeMode.name);
    await prefs.setBool(_appLockEnabledKey, appLockEnabled);
    if (appLockPinSalt.trim().isEmpty || appLockPinHash.trim().isEmpty) {
      await prefs.remove(_appLockPinSaltKey);
      await prefs.remove(_appLockPinHashKey);
    } else {
      await prefs.setString(_appLockPinSaltKey, appLockPinSalt.trim());
      await prefs.setString(_appLockPinHashKey, appLockPinHash.trim());
    }
    await prefs.setBool(_appLockBiometricEnabledKey, appLockBiometricEnabled);
    await prefs.setBool(_autoCheckVersionUpdatesKey, autoCheckVersionUpdates);
    await prefs.setBool(
      _localSystemNotificationsKey,
      localSystemNotificationsEnabled,
    );
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

  static int _chatBubbleColorFromPrefs(SharedPreferences prefs, String key) {
    final value = prefs.getInt(key);
    if (value == null || value == defaultChatBubbleColorValue) {
      return defaultChatBubbleColorValue;
    }
    return 0xff000000 | (value & 0x00ffffff);
  }

  static double _chatBubbleOpacityFromPrefs(SharedPreferences prefs) {
    final value = prefs.getDouble(_chatBubbleOpacityKey);
    if (value == null) {
      return defaultChatBubbleOpacity;
    }
    return value.clamp(0.45, 1.0).toDouble();
  }

  static String _serverUrlFromPrefs(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return '';
    }
    final normalized = value.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    const oldHosts = <String>{
      'http://103.40.14.14:24582',
      'http://103.40.14.14:24582/rpc',
      'http://103.40.14.14:24582/rpc/unicsac.php',
    };
    return oldHosts.contains(normalized) ? '' : value;
  }

  static CsacLanguage _languageFromName(String? value) {
    for (final language in CsacLanguage.values) {
      if (language.name == value) {
        return language;
      }
    }
    return CsacLanguage.zh;
  }

  static CsacFontStyle _fontStyleFromName(String? value) {
    for (final style in CsacFontStyle.values) {
      if (style.name == value) {
        return style;
      }
    }
    return CsacFontStyle.system;
  }

  static ConversationSortMode _conversationSortModeFromName(String? value) {
    for (final mode in ConversationSortMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ConversationSortMode.latest;
  }

  static ConversationSubtitleMode _conversationSubtitleModeFromName(
    String? value,
  ) {
    for (final mode in ConversationSubtitleMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ConversationSubtitleMode.recentMessage;
  }

  static MessageTimeFormat _messageTimeFormatFromName(String? value) {
    for (final format in MessageTimeFormat.values) {
      if (format.name == value) {
        return format;
      }
    }
    return MessageTimeFormat.slash;
  }

  static ChatBubbleCornerStyle _chatBubbleCornerStyleFromName(String? value) {
    for (final style in ChatBubbleCornerStyle.values) {
      if (style.name == value) {
        return style;
      }
    }
    return ChatBubbleCornerStyle.telegram;
  }

  static GroupMemberBadgeMode _groupMemberBadgeModeFromName(String? value) {
    if (value == 'level') {
      return GroupMemberBadgeMode.title;
    }
    for (final mode in GroupMemberBadgeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return GroupMemberBadgeMode.title;
  }
}

class AppLockPin {
  const AppLockPin._();

  static bool isValid(String pin) {
    return RegExp(r'^\d{4,8}$').hasMatch(pin);
  }

  static String newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return _toHex(bytes);
  }

  static String hash(String pin, String salt) {
    final digest = Digest('SHA-256');
    final input = Uint8List.fromList(utf8.encode('$salt:$pin'));
    return _toHex(digest.process(input));
  }

  static String _toHex(Iterable<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class ConversationDraftStore {
  const ConversationDraftStore._();

  static const _draftPrefix = 'csac.draft.';
  static final changes = ValueNotifier<int>(0);

  static String _key(Conversation conversation) {
    return '$_draftPrefix${conversation.type.name}:${conversation.id}';
  }

  static Future<ConversationDraft> load(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(conversation));
    if (raw == null || raw.isEmpty) {
      return ConversationDraft.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ConversationDraft.fromJson(decoded);
      }
    } catch (_) {}
    return ConversationDraft(text: raw);
  }

  static Future<Map<String, ConversationDraft>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = <String, ConversationDraft>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_draftPrefix)) {
        continue;
      }
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      ConversationDraft draft;
      try {
        final decoded = jsonDecode(raw);
        draft = decoded is Map<String, dynamic>
            ? ConversationDraft.fromJson(decoded)
            : ConversationDraft(text: raw);
      } catch (_) {
        draft = ConversationDraft(text: raw);
      }
      if (draft.hasContent) {
        drafts[key.substring(_draftPrefix.length)] = draft;
      }
    }
    return drafts;
  }

  static Future<void> save(
    Conversation conversation,
    String text, {
    ChatMessage? replyTarget,
  }) async {
    return saveDraft(
      conversation,
      ConversationDraft.fromParts(text: text, replyTarget: replyTarget),
    );
  }

  static Future<void> saveDraft(
    Conversation conversation,
    ConversationDraft draft,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!draft.hasContent) {
      await prefs.remove(_key(conversation));
      _notifyChanged();
      return;
    }
    await prefs.setString(_key(conversation), jsonEncode(draft.toJson()));
    _notifyChanged();
  }

  static Future<void> clear(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(conversation));
    _notifyChanged();
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
    if (keys.isNotEmpty) {
      _notifyChanged();
    }
  }

  static void _notifyChanged() {
    changes.value = changes.value + 1;
  }
}

class ConversationLocalPreference {
  const ConversationLocalPreference({
    this.pinned = false,
    this.muted = false,
    this.archived = false,
  });

  static const defaults = ConversationLocalPreference();

  final bool pinned;
  final bool muted;
  final bool archived;

  bool get isDefault => !pinned && !muted && !archived;

  ConversationLocalPreference copyWith({
    bool? pinned,
    bool? muted,
    bool? archived,
  }) {
    return ConversationLocalPreference(
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      archived: archived ?? this.archived,
    );
  }

  factory ConversationLocalPreference.fromJson(Map<String, dynamic> json) {
    return ConversationLocalPreference(
      pinned: json['pinned'] == true,
      muted: json['muted'] == true,
      archived: json['archived'] == true,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'pinned': pinned,
      'muted': muted,
      'archived': archived,
    };
  }
}

class ConversationPreferenceStore {
  const ConversationPreferenceStore._();

  static const _prefix = 'csac.conversation_pref.';
  static final changes = ValueNotifier<int>(0);

  static String keyFor(Conversation conversation) {
    return '${conversation.type.name}:${conversation.id}';
  }

  static String _storageKey(Conversation conversation) {
    return '$_prefix${keyFor(conversation)}';
  }

  static Future<Map<String, ConversationLocalPreference>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, ConversationLocalPreference>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) {
        continue;
      }
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final value = ConversationLocalPreference.fromJson(decoded);
          if (!value.isDefault) {
            result[key.substring(_prefix.length)] = value;
          }
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<ConversationLocalPreference> load(
    Conversation conversation,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(conversation));
    if (raw == null || raw.isEmpty) {
      return ConversationLocalPreference.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ConversationLocalPreference.fromJson(decoded);
      }
    } catch (_) {}
    return ConversationLocalPreference.defaults;
  }

  static Future<void> update(
    Conversation conversation,
    ConversationLocalPreference Function(ConversationLocalPreference current)
    change,
  ) async {
    final current = await load(conversation);
    await save(conversation, change(current));
  }

  static Future<void> save(
    Conversation conversation,
    ConversationLocalPreference value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isDefault) {
      await prefs.remove(_storageKey(conversation));
    } else {
      await prefs.setString(_storageKey(conversation), jsonEncode(value));
    }
    _notifyChanged();
  }

  static void _notifyChanged() {
    changes.value = changes.value + 1;
  }
}

class EmojiStickerStore {
  const EmojiStickerStore._();

  static const _key = 'csac.emoji.stickers';

  static Future<List<EmojiSticker>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const <EmojiSticker>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <EmojiSticker>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => EmojiSticker.fromJson(Map<String, dynamic>.from(item)))
          .where((emoji) => emoji.abbr.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const <EmojiSticker>[];
    }
  }

  static Future<void> save(List<EmojiSticker> stickers) async {
    final prefs = await SharedPreferences.getInstance();
    if (stickers.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(
      _key,
      jsonEncode(stickers.map((emoji) => emoji.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class EmojiRecentStore {
  const EmojiRecentStore._();

  static const _key = 'csac.emoji.recent';
  static const _maxEntries = 24;

  static Future<List<EmojiSticker>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const <EmojiSticker>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <EmojiSticker>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => EmojiSticker.fromJson(Map<String, dynamic>.from(item)))
          .where((emoji) => emoji.abbr.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const <EmojiSticker>[];
    }
  }

  static Future<void> record(EmojiSticker sticker) async {
    if (sticker.abbr.trim().isEmpty) {
      return;
    }
    final current = await load();
    final next = <EmojiSticker>[
      sticker,
      for (final item in current)
        if (item.abbr != sticker.abbr) item,
    ].take(_maxEntries).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.map((emoji) => emoji.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class EmojiPinnedStore {
  const EmojiPinnedStore._();

  static const _key = 'csac.emoji.pinned';
  static const _maxEntries = 48;

  static Future<List<EmojiSticker>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const <EmojiSticker>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <EmojiSticker>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => EmojiSticker.fromJson(Map<String, dynamic>.from(item)))
          .where((emoji) => emoji.abbr.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const <EmojiSticker>[];
    }
  }

  static Future<void> save(List<EmojiSticker> stickers) async {
    final prefs = await SharedPreferences.getInstance();
    final next = <EmojiSticker>[];
    final seen = <String>{};
    for (final sticker in stickers) {
      final abbr = sticker.abbr.trim();
      if (abbr.isEmpty || seen.contains(abbr)) {
        continue;
      }
      seen.add(abbr);
      next.add(sticker);
      if (next.length >= _maxEntries) {
        break;
      }
    }
    if (next.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(
      _key,
      jsonEncode(next.map((emoji) => emoji.toJson()).toList()),
    );
  }

  static Future<bool> toggle(EmojiSticker sticker) async {
    final abbr = sticker.abbr.trim();
    if (abbr.isEmpty) {
      return false;
    }
    final current = await load();
    final exists = current.any((item) => item.abbr == abbr);
    if (exists) {
      await save([
        for (final item in current)
          if (item.abbr != abbr) item,
      ]);
      return false;
    }
    await save([sticker, ...current]);
    return true;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class CommandPaletteUsage {
  const CommandPaletteUsage({
    required this.id,
    required this.count,
    required this.lastUsedAt,
  });

  final String id;
  final int count;
  final int lastUsedAt;

  factory CommandPaletteUsage.fromJson(Map<String, dynamic> json) {
    return CommandPaletteUsage(
      id: asString(json['id']),
      count: asInt(json['count']),
      lastUsedAt: asInt(json['last_used_at']),
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'count': count,
      'last_used_at': lastUsedAt,
    };
  }
}

class CommandPaletteUsageStore {
  const CommandPaletteUsageStore._();

  static const _key = 'csac.command_palette.usage';
  static const _maxEntries = 64;

  static Future<Map<String, CommandPaletteUsage>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const <String, CommandPaletteUsage>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String, CommandPaletteUsage>{};
      }
      final result = <String, CommandPaletteUsage>{};
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final usage = CommandPaletteUsage.fromJson(item);
          if (usage.id.trim().isNotEmpty) {
            result[usage.id] = usage;
          }
        }
      }
      return result;
    } catch (_) {
      return const <String, CommandPaletteUsage>{};
    }
  }

  static Future<void> record(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return;
    }
    final usage = Map<String, CommandPaletteUsage>.of(await loadAll());
    final current = usage[normalized];
    usage[normalized] = CommandPaletteUsage(
      id: normalized,
      count: (current?.count ?? 0) + 1,
      lastUsedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final values = usage.values.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    final limited = values.take(_maxEntries).map((item) => item.toJson());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(limited.toList()));
  }
}

class ConversationDraft {
  const ConversationDraft({
    this.text = '',
    this.replyMessageId = 0,
    this.replySender = '',
    this.replyBody = '',
  });

  static const empty = ConversationDraft();

  final String text;
  final int replyMessageId;
  final String replySender;
  final String replyBody;

  bool get hasReply => replyMessageId > 0;
  bool get hasContent => text.trim().isNotEmpty || hasReply;

  String get previewText {
    final normalized = text.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    if (hasReply) {
      final body = replyBody.trim();
      final sender = replySender.trim();
      if (body.isEmpty) {
        return sender.isEmpty ? '#$replyMessageId' : sender;
      }
      return sender.isEmpty ? body : '$sender: $body';
    }
    return '';
  }

  factory ConversationDraft.fromParts({
    required String text,
    ChatMessage? replyTarget,
  }) {
    final reply = replyTarget;
    return ConversationDraft(
      text: text.trimRight(),
      replyMessageId: reply?.id ?? 0,
      replySender: reply?.sender ?? '',
      replyBody: reply == null
          ? ''
          : compactDraftText(_draftMessageText(reply)),
    );
  }

  factory ConversationDraft.fromJson(Map<String, dynamic> json) {
    return ConversationDraft(
      text: '${json['text'] ?? ''}'.trimRight(),
      replyMessageId: json['replyMessageId'] is int
          ? json['replyMessageId'] as int
          : int.tryParse('${json['replyMessageId'] ?? ''}') ?? 0,
      replySender: '${json['replySender'] ?? ''}',
      replyBody: '${json['replyBody'] ?? ''}',
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'text': text.trimRight(),
      'replyMessageId': replyMessageId,
      'replySender': replySender,
      'replyBody': replyBody,
    };
  }
}

String _draftMessageText(ChatMessage message) {
  if (message.isRecalled) {
    return '[recalled]';
  }
  if (message.emojiAddress.isNotEmpty || message.messageType == 5) {
    return message.emojiAbbr.trim().isEmpty
        ? '[emoji]'
        : '[emoji] ${message.emojiAbbr.trim()}';
  }
  return message.body;
}

String compactDraftText(String text, {int max = 96}) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length <= max) {
    return value;
  }
  return '${value.substring(0, max - 3)}...';
}

class ChatHintStore {
  const ChatHintStore._();

  static const _seenKey = 'csac.chat_hint.seen';

  static Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}

class MentionNoticeStore {
  const MentionNoticeStore._();

  static const _readPrefix = 'csac.mention_notice.read.';
  static const _clearedPrefix = 'csac.mention_notice.cleared.';
  static const _summaryReadKey = 'csac.mention_notice.summary_read';
  static const _summaryClearedKey = 'csac.mention_notice.summary_cleared';

  static String _key(String prefix, MentionNotice notice) {
    return '$prefix${notice.conversation.type.name}:'
        '${notice.conversation.id}:${notice.message.id}:${notice.id}';
  }

  static Future<Set<String>> loadReadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().where((key) => key.startsWith(_readPrefix)).toSet();
  }

  static Future<Set<String>> loadClearedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((key) => key.startsWith(_clearedPrefix))
        .toSet();
  }

  static Future<bool> summaryRead() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_summaryReadKey) ?? false;
  }

  static Future<bool> summaryCleared() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_summaryClearedKey) ?? false;
  }

  static String readKey(MentionNotice notice) {
    return _key(_readPrefix, notice);
  }

  static String clearedKey(MentionNotice notice) {
    return _key(_clearedPrefix, notice);
  }

  static Future<void> markRead(MentionNotice notice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(readKey(notice), true);
  }

  static Future<void> markSummaryRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_summaryReadKey, true);
  }

  static Future<void> markAllRead(Iterable<MentionNotice> notices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_summaryReadKey, true);
    for (final notice in notices) {
      await prefs.setBool(readKey(notice), true);
    }
  }

  static Future<void> clear(MentionNotice notice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(readKey(notice), true);
    await prefs.setBool(clearedKey(notice), true);
  }

  static Future<void> clearSummary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_summaryReadKey, true);
    await prefs.setBool(_summaryClearedKey, true);
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
    if (nickname.trim().isNotEmpty) {
      return nickname.trim();
    }
    if (username.trim().isNotEmpty) {
      return username.trim();
    }
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
    if (raw == null || raw.trim().isEmpty) {
      return const <LoginAccountRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LoginAccountRecord>[];
      }
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
    Map<String, String> sessionCookies = const <String, String>{},
  }) async {
    final normalizedUsername = username.trim().isEmpty
        ? user.username.trim()
        : username.trim();
    if (user.uid <= 0 && normalizedUsername.isEmpty) {
      return;
    }
    final records = await loadAll();
    final normalizedServer = _serverKey(serverUrl);
    final filtered = records.where((record) {
      if (_serverKey(record.serverUrl) != normalizedServer) {
        return true;
      }
      if (user.uid > 0 && record.uid == user.uid) {
        return false;
      }
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
        if (_serverKey(item.serverUrl) != normalizedServer) {
          return true;
        }
        if (record.uid > 0 && item.uid == record.uid) {
          return false;
        }
        return item.username.trim().toLowerCase() !=
            record.username.trim().toLowerCase();
      }).toList(),
    );
  }

  static Future<void> removeCurrent({
    required CsacUser user,
    required String serverUrl,
  }) async {
    await remove(
      LoginAccountRecord(
        uid: user.uid,
        username: user.username,
        nickname: user.nickname,
        avatar: user.avatar,
        serverUrl: _serverKey(serverUrl),
        savedAt: 0,
      ),
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

  static String _serverKey(String serverUrl) {
    return serverUrl.trim();
  }

  static bool _sameAccount(
    LoginAccountRecord item,
    LoginAccountRecord record,
    String normalizedServer,
  ) {
    if (_serverKey(item.serverUrl) != normalizedServer) {
      return false;
    }
    if (record.uid > 0 && item.uid == record.uid) {
      return true;
    }
    return item.username.trim().toLowerCase() ==
        record.username.trim().toLowerCase();
  }
}
