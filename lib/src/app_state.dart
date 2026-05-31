import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'l10n.dart';
import 'local_cache.dart';
import 'models.dart';
import 'platform/app_storage.dart';
import 'preferences.dart';

class PerformanceCacheStats {
  const PerformanceCacheStats({
    required this.messageCount,
    required this.conversationCount,
    required this.localDeletedMessageCount,
    required this.messageCacheBytes,
    required this.imageCacheBytes,
    required this.imageCacheEntries,
    required this.logBytes,
  });

  final int messageCount;
  final int conversationCount;
  final int localDeletedMessageCount;
  final int messageCacheBytes;
  final int imageCacheBytes;
  final int imageCacheEntries;
  final int logBytes;

  int get totalBytes => messageCacheBytes + imageCacheBytes + logBytes;
}

class AppLogFile {
  const AppLogFile({
    required this.path,
    required this.name,
    required this.bytes,
    required this.modified,
  });

  final String path;
  final String name;
  final int bytes;
  final DateTime modified;
}

class CsacAppState extends ChangeNotifier {
  CsacAppState({CsacApiClient? client, CsacLocalCache? cache})
    : client = client ?? CsacApiClient(),
      cache = cache ?? CsacLocalCache();

  final CsacApiClient client;
  final CsacLocalCache cache;

  CsacUser? user;
  List<Conversation> conversations = const <Conversation>[];
  NotificationCounts notificationCounts = const NotificationCounts();
  CsacPreferences preferences = const CsacPreferences();
  Conversation? activeConversation;
  List<EmojiSticker> emojiStickers = const <EmojiSticker>[];
  bool bootstrapping = true;
  bool debugMode = false;
  bool loading = false;
  bool offlineMode = false;
  bool sessionExpired = false;
  String restoreStatus = const CsacStrings(
    Locale('zh', 'CN'),
  ).text('Restoring session...');
  String? error;

  Future<void> initialize() async {
    bootstrapping = true;
    restoreStatus = CsacStrings(
      localeForLanguage(preferences.language),
    ).text('Restoring session...');
    error = null;
    notifyListeners();
    try {
      await cache.open();
      preferences = await CsacPreferences.load();
      _applyPreferredServer();
      await client.loadSession();
      restoreStatus = CsacStrings(
        localeForLanguage(preferences.language),
      ).text('Checking saved session...');
      notifyListeners();
      user = await client.currentUser();
      await cache.saveUser(user!);
      offlineMode = false;
      sessionExpired = false;
      await loadCachedConversations();
      await syncConversations();
      await refreshNotificationCounts();
      unawaited(loadEmojiStickers(forceRefresh: true));
      await refreshDebugMode();
    } on CsacAuthException catch (err) {
      await client.clearSession();
      user = await cache.loadUser();
      conversations = _sortConversations(await cache.loadConversations());
      sessionExpired = true;
      offlineMode = user != null;
      error = user == null
          ? err.toString()
          : CsacStrings(
              localeForLanguage(preferences.language),
            ).text('Session expired. Cached history is available offline.');
    } catch (_) {
      user = await cache.loadUser();
      conversations = _sortConversations(await cache.loadConversations());
      offlineMode = user != null;
      sessionExpired = false;
      error = user == null
          ? CsacStrings(
              localeForLanguage(preferences.language),
            ).text('Unable to restore session.')
          : null;
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await client.login(username, password);
      await cache.saveUser(user!);
      await LoginAccountStore.upsert(
        user: user!,
        username: username,
        serverUrl: client.baseUrl,
        sessionCookies: client.sessionSnapshot,
      );
      offlineMode = false;
      sessionExpired = false;
      error = null;
      await syncConversations();
      await refreshNotificationCounts();
      unawaited(loadEmojiStickers(forceRefresh: true));
      await refreshDebugMode();
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String username,
    required String nickname,
    required String password,
    required String confirmPassword,
    Uint8List? avatarBytes,
    String avatarFileName = '',
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await client.register(
        username: username,
        nickname: nickname,
        password: password,
        confirmPassword: confirmPassword,
        avatarBytes: avatarBytes,
        avatarFileName: avatarFileName,
      );
      await cache.saveUser(user!);
      await LoginAccountStore.upsert(
        user: user!,
        username: username,
        serverUrl: client.baseUrl,
        sessionCookies: client.sessionSnapshot,
      );
      offlineMode = false;
      sessionExpired = false;
      error = null;
      await syncConversations();
      await refreshNotificationCounts();
      unawaited(loadEmojiStickers(forceRefresh: true));
      await refreshDebugMode();
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    preferences = preferences.copyWith(themeMode: mode);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateThemeColor(int colorValue) async {
    preferences = preferences.copyWith(themeColorValue: colorValue);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateLanguage(CsacLanguage language) async {
    preferences = preferences.copyWith(language: language);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateFontStyle(CsacFontStyle style) async {
    preferences = preferences.copyWith(fontStyle: style);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateConversationSortMode(ConversationSortMode mode) async {
    preferences = preferences.copyWith(conversationSortMode: mode);
    if (mode == ConversationSortMode.latest) {
      await _hydrateConversationActivityFromCache();
    } else {
      conversations = _sortConversations(conversations);
    }
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateMessageTimeFormat(MessageTimeFormat format) async {
    preferences = preferences.copyWith(messageTimeFormat: format);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateChatBubbleCornerStyle(ChatBubbleCornerStyle style) async {
    preferences = preferences.copyWith(chatBubbleCornerStyle: style);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateOwnChatBubbleColor(int colorValue) async {
    preferences = preferences.copyWith(ownChatBubbleColorValue: colorValue);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateOtherChatBubbleColor(int colorValue) async {
    preferences = preferences.copyWith(otherChatBubbleColorValue: colorValue);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateChatBubbleOpacity(double opacity) async {
    preferences = preferences.copyWith(
      chatBubbleOpacity: opacity.clamp(0.45, 1.0).toDouble(),
    );
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateChatBackgroundPath(String path) async {
    preferences = preferences.copyWith(chatBackgroundPath: path);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateReduceMotion(bool enabled) async {
    preferences = preferences.copyWith(reduceMotion: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateShowChatAvatars(bool enabled) async {
    preferences = preferences.copyWith(showChatAvatars: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateEnablePat(bool enabled) async {
    preferences = preferences.copyWith(enablePat: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateShowGroupMemberLevel(bool enabled) async {
    preferences = preferences.copyWith(showGroupMemberLevel: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> enableLowPerformanceMode() async {
    preferences = preferences.copyWith(reduceMotion: true);
    await preferences.save();
    PaintingBinding.instance.imageCache.maximumSize = 120;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 24 << 20;
    await _clearImageCaches(resetBackground: false);
    notifyListeners();
  }

  Future<void> enableAppLock({
    required String pin,
    required bool biometricEnabled,
  }) async {
    final salt = AppLockPin.newSalt();
    preferences = preferences.copyWith(
      appLockEnabled: true,
      appLockPinSalt: salt,
      appLockPinHash: AppLockPin.hash(pin, salt),
      appLockBiometricEnabled: biometricEnabled,
    );
    await preferences.save();
    notifyListeners();
  }

  Future<void> disableAppLock() async {
    preferences = preferences.copyWith(
      appLockEnabled: false,
      appLockPinSalt: '',
      appLockPinHash: '',
      appLockBiometricEnabled: false,
    );
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateAppLockBiometric(bool enabled) async {
    preferences = preferences.copyWith(appLockBiometricEnabled: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateAutoCheckVersionUpdates(bool enabled) async {
    preferences = preferences.copyWith(autoCheckVersionUpdates: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateLocalSystemNotifications(bool enabled) async {
    preferences = preferences.copyWith(
      localSystemNotificationsEnabled: enabled,
    );
    await preferences.save();
    notifyListeners();
  }

  bool verifyAppLockPin(String pin) {
    return preferences.verifyAppLockPin(pin);
  }

  Future<bool> updateServerUrl(String value) async {
    final normalizedUrl = value.trim().isEmpty
        ? ''
        : CsacApiClient.normalizeServerUrl(value);
    final normalized = normalizedUrl == CsacApiClient.defaultBaseUrl
        ? ''
        : normalizedUrl;
    if (normalized == preferences.serverUrl.trim()) {
      _applyPreferredServer();
      return false;
    }
    preferences = preferences.copyWith(serverUrl: normalized);
    await preferences.save();
    _applyPreferredServer();
    await client.clearSession();
    await cache.clear();
    await EmojiStickerStore.clear();
    await EmojiRecentStore.clear();
    user = null;
    conversations = const <Conversation>[];
    notificationCounts = const NotificationCounts();
    activeConversation = null;
    emojiStickers = const <EmojiSticker>[];
    debugMode = false;
    offlineMode = false;
    sessionExpired = false;
    error = null;
    notifyListeners();
    return true;
  }

  Future<void> _clearLocalSessionState({
    CsacUser? previousUser,
    String? previousServerUrl,
    bool removeLoginRecord = false,
  }) async {
    if (removeLoginRecord &&
        previousUser != null &&
        previousServerUrl != null) {
      await LoginAccountStore.removeCurrent(
        user: previousUser,
        serverUrl: previousServerUrl,
      );
    }
    await cache.clear();
    await ConversationDraftStore.clearAll();
    await EmojiStickerStore.clear();
    await EmojiRecentStore.clear();
    user = null;
    conversations = const <Conversation>[];
    notificationCounts = const NotificationCounts();
    activeConversation = null;
    emojiStickers = const <EmojiSticker>[];
    debugMode = false;
    offlineMode = false;
    sessionExpired = false;
    error = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final previousUser = user;
    final previousServerUrl = client.baseUrl;
    try {
      await client.deleteAccount();
    } finally {
      await _clearLocalSessionState(
        previousUser: previousUser,
        previousServerUrl: previousServerUrl,
        removeLoginRecord: true,
      );
    }
  }

  Future<void> refreshCurrentUser() async {
    user = await client.currentUser();
    await cache.saveUser(user!);
    offlineMode = false;
    sessionExpired = false;
    notifyListeners();
  }

  Future<void> updateNickname(String nickname) async {
    await client.updateNickname(nickname);
    await refreshCurrentUser();
  }

  Future<void> updatePatAction(String patAction) async {
    await client.updatePatAction(patAction);
    await refreshCurrentUser();
  }

  Future<void> updateAvatar(Uint8List avatarBytes, String fileName) async {
    await client.updateAvatar(avatarBytes, fileName);
    await refreshCurrentUser();
  }

  Future<void> updatePassword(
    String oldPassword,
    String newPassword,
    String confirmPassword,
  ) {
    return client.updatePassword(oldPassword, newPassword, confirmPassword);
  }

  void _applyPreferredServer() {
    client.setBaseUrl(preferences.serverUrl);
  }

  Future<List<LoginAccountRecord>> loadLoginAccounts() {
    return LoginAccountStore.loadForServer(client.baseUrl);
  }

  Future<void> removeLoginAccount(LoginAccountRecord record) {
    return LoginAccountStore.remove(record);
  }

  Future<void> loginWithSavedSession(LoginAccountRecord record) async {
    if (!record.hasSession) {
      throw const CsacAuthException('Saved session is not available.');
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      await client.restoreSession(record.sessionCookies);
      user = await client.currentUser();
      await cache.saveUser(user!);
      await LoginAccountStore.upsert(
        user: user!,
        username: record.username,
        serverUrl: client.baseUrl,
        sessionCookies: client.sessionSnapshot,
      );
      offlineMode = false;
      sessionExpired = false;
      error = null;
      await syncConversations();
      await refreshNotificationCounts();
      unawaited(loadEmojiStickers(forceRefresh: true));
      await refreshDebugMode();
    } on CsacAuthException {
      await client.clearSession();
      await LoginAccountStore.clearSession(record);
      rethrow;
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool isActiveConversation(Conversation conversation) {
    return activeConversation?.type == conversation.type &&
        activeConversation?.id == conversation.id;
  }

  void setActiveConversation(Conversation? conversation) {
    activeConversation = conversation;
  }

  Future<void> updateConversationLocalPreference(
    Conversation conversation,
    ConversationLocalPreference Function(ConversationLocalPreference current)
    change,
  ) async {
    await ConversationPreferenceStore.update(conversation, change);
    conversations = _sortConversations(conversations);
    notifyListeners();
  }

  Future<void> loadConversations() async {
    try {
      await syncConversations();
    } catch (_) {
      conversations = _sortConversations(await cache.loadConversations());
      offlineMode = user != null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadCachedConversations() async {
    conversations = _sortConversations(await cache.loadConversations());
    notifyListeners();
  }

  Future<void> syncConversations() async {
    final loaded = await client.conversations();
    final cachedActivity = await cache.loadConversationActivity();
    final normalized = _sortConversations(<Conversation>[
      for (final entry in loaded.indexed)
        () {
          final conversation = entry.$2.copyWith(displayOrder: entry.$1);
          final cached =
              cachedActivity['${conversation.type.name}:${conversation.id}'] ??
              0;
          return _normalizeConversation(
            conversation.copyWith(
              lastMessageAt: conversation.lastMessageAt >= cached
                  ? conversation.lastMessageAt
                  : cached,
            ),
          );
        }(),
    ]);
    conversations = normalized;
    await cache.saveConversations(normalized);
    offlineMode = false;
    notifyListeners();
  }

  Conversation _normalizeConversation(Conversation conversation) {
    return isActiveConversation(conversation)
        ? conversation.copyWith(unreadCount: 0)
        : conversation;
  }

  List<Conversation> _sortConversations(List<Conversation> input) {
    final sorted = input.toList();
    switch (preferences.conversationSortMode) {
      case ConversationSortMode.latest:
        sorted.sort((a, b) {
          final byTime = b.latestSortValue.compareTo(a.latestSortValue);
          if (byTime != 0) {
            return byTime;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case ConversationSortMode.type:
        sorted.sort((a, b) {
          final byType = a.type.index.compareTo(b.type.index);
          if (byType != 0) {
            return byType;
          }
          final byOrder = a.displayOrder.compareTo(b.displayOrder);
          if (byOrder != 0) {
            return byOrder;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    return sorted;
  }

  Future<void> _hydrateConversationActivityFromCache() async {
    final activity = await cache.loadConversationActivity();
    conversations = _sortConversations([
      for (final conversation in conversations)
        _withCachedActivity(conversation, activity),
    ]);
    await cache.saveConversations(conversations);
  }

  Conversation _withCachedActivity(
    Conversation conversation,
    Map<String, int> activity,
  ) {
    final cached =
        activity['${conversation.type.name}:${conversation.id}'] ?? 0;
    return conversation.copyWith(
      lastMessageAt: conversation.lastMessageAt >= cached
          ? conversation.lastMessageAt
          : cached,
    );
  }

  Future<void> refreshHome() async {
    await Future.wait<void>([syncConversations(), refreshNotificationCounts()]);
  }

  Future<void> markConversationRead(
    Conversation conversation, {
    int lastMsgId = 0,
    bool syncServer = true,
  }) async {
    final updated = <Conversation>[
      for (final item in conversations)
        item.type == conversation.type && item.id == conversation.id
            ? item.copyWith(unreadCount: 0)
            : item,
    ];
    conversations = _sortConversations(updated);
    await cache.saveConversations(updated);
    notifyListeners();
    if (!syncServer) {
      return;
    }
    try {
      await client.markRead(conversation, lastMsgId: lastMsgId);
    } catch (_) {
      // Keep the local read state responsive even if the API call fails.
    }
  }

  Future<void> refreshNotificationCounts() async {
    try {
      final baseCounts = await client.notificationCounts();
      var mentionCount = 0;
      var friendChangeCount = baseCounts.friendChanges;
      try {
        mentionCount = (await loadVisibleMentionNotices()).unreadCount;
      } catch (_) {
        mentionCount = notificationCounts.mentions;
      }
      if (friendChangeCount == 0) {
        try {
          final changes = await client.friendChangeNotices();
          friendChangeCount = changes.where((notice) => !notice.isRead).length;
        } catch (_) {}
      }
      notificationCounts = NotificationCounts(
        notices: baseCounts.notices,
        mentions: mentionCount,
        friendChanges: friendChangeCount,
        friendRequests: baseCounts.friendRequests,
        groupApplications: baseCounts.groupApplications,
      );
    } catch (_) {
      notificationCounts = NotificationCounts(
        notices: notificationCounts.notices,
        mentions: notificationCounts.mentions,
        friendChanges: notificationCounts.friendChanges,
        friendRequests: notificationCounts.friendRequests,
        groupApplications: notificationCounts.groupApplications,
      );
    }
    notifyListeners();
  }

  void updateNotificationCounts({
    int? notices,
    int? mentions,
    int? friendChanges,
    int? friendRequests,
    int? groupApplications,
  }) {
    notificationCounts = NotificationCounts(
      notices: notices ?? notificationCounts.notices,
      mentions: mentions ?? notificationCounts.mentions,
      friendChanges: friendChanges ?? notificationCounts.friendChanges,
      friendRequests: friendRequests ?? notificationCounts.friendRequests,
      groupApplications:
          groupApplications ?? notificationCounts.groupApplications,
    );
    notifyListeners();
  }

  Future<List<CsacNotice>> loadNotices() {
    return client.notices();
  }

  Future<MentionNoticeBundle> loadMentionNotices() {
    return client.mentionNotices();
  }

  Future<MentionNoticeBundle> loadVisibleMentionNotices() async {
    final bundle = await client.mentionNotices();
    final readKeys = await MentionNoticeStore.loadReadKeys();
    final clearedKeys = await MentionNoticeStore.loadClearedKeys();
    final summaryRead = await MentionNoticeStore.summaryRead();
    final summaryCleared = await MentionNoticeStore.summaryCleared();
    final visible = <MentionNotice>[
      for (final item in bundle.items)
        if (!clearedKeys.contains(MentionNoticeStore.clearedKey(item)))
          readKeys.contains(MentionNoticeStore.readKey(item))
              ? item.copyWith(isRead: true)
              : item,
    ];
    if (visible.isEmpty && bundle.hasOnlySummary) {
      return summaryCleared
          ? const MentionNoticeBundle(items: [])
          : bundle.copyWith(
              mentionCount: summaryRead ? 0 : bundle.mentionCount,
              replyCount: summaryRead ? 0 : bundle.replyCount,
            );
    }
    return MentionNoticeBundle(
      items: visible,
      mentionCount: bundle.mentionCount,
      replyCount: bundle.replyCount,
    );
  }

  Future<void> markMentionNoticeRead(MentionNotice notice) async {
    await MentionNoticeStore.markRead(notice);
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(mentions: visible.unreadCount);
  }

  Future<void> markMentionSummaryRead() async {
    await MentionNoticeStore.markSummaryRead();
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(mentions: visible.unreadCount);
  }

  Future<void> clearMentionNotice(MentionNotice notice) async {
    await MentionNoticeStore.clear(notice);
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(mentions: visible.unreadCount);
  }

  Future<void> clearMentionSummary() async {
    await MentionNoticeStore.clearSummary();
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(mentions: visible.unreadCount);
  }

  Future<List<FriendChangeNotice>> loadFriendChangeNotices() {
    return client.friendChangeNotices();
  }

  Future<void> markNoticeRead({int? noticeId, bool readAll = false}) async {
    await client.markNoticeRead(noticeId: noticeId, readAll: readAll);
    await refreshNotificationCounts();
  }

  Future<List<FriendRequest>> loadFriendRequests() {
    return client.friendRequests();
  }

  Future<void> handleFriendRequest(int requestId, String action) async {
    await client.handleFriendRequest(requestId, action);
    await refreshNotificationCounts();
    await syncConversations();
  }

  Future<List<GroupApplication>> loadGroupApplications() async {
    final groups = conversations
        .where((conversation) => conversation.type == ConversationType.group)
        .toList();
    if (groups.isEmpty) {
      return client.groupApplications();
    }
    final batches = await Future.wait<List<GroupApplication>>(
      groups.map((group) async {
        try {
          return await client.groupApplications(
            roomId: group.id,
            roomName: group.name,
          );
        } catch (_) {
          return const <GroupApplication>[];
        }
      }),
    );
    final byId = <String, GroupApplication>{};
    for (final batch in batches) {
      for (final application in batch) {
        byId['${application.roomId}:${application.id}'] = application;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.createTime.compareTo(a.createTime));
  }

  Future<void> handleGroupApplication(int applyId, String action) async {
    await client.handleGroupApplication(applyId, action);
    await refreshNotificationCounts();
  }

  Future<List<ChatMessage>> loadCachedMessages(Conversation conversation) {
    return cache.loadMessages(conversation);
  }

  Future<List<EmojiSticker>> loadEmojiStickers({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && emojiStickers.isNotEmpty) {
      return emojiStickers;
    }
    final cached = await EmojiStickerStore.load();
    if (cached.isNotEmpty && !forceRefresh) {
      emojiStickers = cached;
      notifyListeners();
      return cached;
    }
    if (cached.isNotEmpty && emojiStickers.isEmpty) {
      emojiStickers = cached;
      notifyListeners();
    }
    try {
      final loaded = await client.emojis();
      emojiStickers = loaded;
      await EmojiStickerStore.save(loaded);
      notifyListeners();
      return loaded;
    } catch (_) {
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<void> sendEmojiMessage(Conversation conversation, EmojiSticker emoji) {
    return client.sendEmojiMessage(conversation, emoji);
  }

  Future<List<ChatMessage>> loadAllCachedMessages(Conversation conversation) {
    return cache.loadAllMessages(conversation);
  }

  Future<List<ChatMessage>> loadCachedMessagesAround(
    Conversation conversation,
    int messageId,
  ) {
    return cache.loadMessagesAround(conversation, messageId);
  }

  Future<List<ChatMessage>> loadMessagesAroundFromNetwork(
    Conversation conversation,
    ChatMessage target, {
    int before = 80,
    int after = 80,
  }) async {
    final beforeMessages = await client.messages(
      conversation,
      beforeId: target.id,
      limit: before,
    );
    final afterMessages = await client.messages(
      conversation,
      afterId: target.id,
      limit: after,
    );
    final window = mergeChatMessages(beforeMessages, <ChatMessage>[
      target,
      ...afterMessages,
    ]);
    await cache.saveMessages(conversation, window);
    return cache.filterLocallyDeletedMessages(conversation, window);
  }

  Future<bool> hasCachedMessage(Conversation conversation, int messageId) {
    return cache.hasMessage(conversation, messageId);
  }

  Future<List<MessageSearchResult>> searchMessages(
    String query,
    SearchScope scope,
  ) {
    return cache.searchMessages(query, scope);
  }

  Future<List<ConversationMediaItem>> loadConversationMedia(
    Conversation conversation, {
    ConversationMediaKind kind = ConversationMediaKind.all,
    String query = '',
  }) {
    return cache.loadConversationMedia(conversation, kind: kind, query: query);
  }

  Future<NetworkDiagnosticReport> runNetworkDiagnostics() async {
    final imageUrl = await cache.latestImageUrl();
    return client.runNetworkDiagnostics(imageUrl: imageUrl);
  }

  Future<ApiDebugResponse> runApiDebugRequest({
    required String method,
    required String route,
    required Map<String, String> values,
  }) {
    return client.runDebugRequest(method: method, route: route, values: values);
  }

  Future<List<GroupMember>> loadGroupMembers(int roomId) {
    return client.groupMembers(roomId);
  }

  Future<UserProfile> loadUserProfile(int uid) {
    return client.userProfile(uid);
  }

  Future<GroupProfile> loadGroupProfile(int roomId) {
    return client.groupProfile(roomId);
  }

  Future<List<GroupProfile>> loadPublicGroups() {
    return client.publicGroups();
  }

  Future<List<GroupProfile>> loadCreatedGroups(int uid) {
    return client.createdGroups(uid);
  }

  Future<GroupProfile> createGroup(String roomName) async {
    final group = await client.createGroup(roomName);
    await syncConversations();
    return group;
  }

  Future<void> sendFriendRequest(int uid, String message) {
    return client.sendFriendRequest(uid, message);
  }

  Future<void> updateFriendRemark(int friendId, String remark) async {
    await client.updateFriendRemark(friendId, remark);
    await syncConversations();
  }

  Future<void> deleteFriend(int friendId) async {
    await client.deleteFriend(friendId);
    await syncConversations();
  }

  Future<void> blockFriend(int friendId) async {
    await client.blockFriend(friendId);
    await syncConversations();
  }

  Future<void> recoverFriend(int friendId) async {
    await client.recoverFriend(friendId);
    await syncConversations();
  }

  Future<List<CommonGroup>> loadCommonGroups(int friendId) {
    return client.commonGroups(friendId);
  }

  Future<void> applyJoinGroup(
    int roomId, {
    String code = '',
    String answer = '',
  }) async {
    await client.applyJoinGroup(roomId, code: code, answer: answer);
    await syncConversations();
  }

  Future<void> submitReport({
    required String type,
    required int targetId,
    required String reason,
    bool anonymous = false,
    String targetName = '',
  }) {
    return client.submitReport(
      type: type,
      targetId: targetId,
      reason: reason,
      anonymous: anonymous,
      targetName: targetName,
    );
  }

  Future<void> submitBugReport({
    required String title,
    required String description,
  }) {
    return client.submitBugReport(title: title, description: description);
  }

  Future<void> leaveGroup(int roomId) async {
    await client.leaveGroup(roomId);
    await syncConversations();
  }

  Future<void> editGroupInfo(
    int roomId, {
    required String roomName,
    required String description,
    required String notice,
  }) async {
    await client.editGroupInfo(
      roomId,
      roomName: roomName,
      description: description,
      notice: notice,
    );
    await syncConversations();
  }

  Future<void> updateGroupAvatar(
    int roomId,
    Uint8List avatarBytes,
    String fileName,
  ) async {
    await client.updateGroupAvatar(roomId, avatarBytes, fileName);
    await syncConversations();
  }

  Future<void> updateGroupSettings(
    int roomId, {
    required String joinType,
    required String code,
    required String question,
    required String answer,
    required bool showPublic,
    required bool allowInvite,
  }) async {
    await client.updateGroupSettings(
      roomId,
      joinType: joinType,
      code: code,
      question: question,
      answer: answer,
      showPublic: showPublic,
      allowInvite: allowInvite,
    );
    await syncConversations();
  }

  Future<void> resetInviteCode(int roomId) async {
    await client.resetInviteCode(roomId);
  }

  Future<void> transferGroup(int roomId, int targetUid) async {
    await client.transferGroup(roomId, targetUid);
    await syncConversations();
  }

  Future<void> disbandGroup(int roomId) async {
    await client.disbandGroup(roomId);
    await syncConversations();
  }

  Future<void> muteGroupMember(int roomId, int targetUid, int minutes) {
    return client.muteGroupMember(roomId, targetUid, minutes);
  }

  Future<void> kickGroupMember(int roomId, int targetUid) async {
    await client.kickGroupMember(roomId, targetUid);
  }

  Future<void> setGroupAdmin(int roomId, int targetUid, bool set) {
    return client.setGroupAdmin(roomId, targetUid, set);
  }

  Future<void> inviteGroupMember(int roomId, int targetUid) async {
    await client.inviteGroupMember(roomId, targetUid);
    await syncConversations();
  }

  Future<void> setGroupMemberTitle(
    int roomId,
    int targetUid, {
    required String title,
    required int level,
  }) async {
    if (debugMode) {
      await refreshDebugMode();
      if (!debugMode) {
        throw const CsacApiException('Debug mode is not active.');
      }
    }
    return client.setGroupMemberTitle(
      roomId,
      targetUid,
      title: title,
      level: level,
    );
  }

  Future<void> recallMessage(Conversation conversation, int msgId) {
    return client.recallMessage(conversation, msgId);
  }

  Future<void> toggleEssence(int roomId, int msgId) {
    return client.toggleEssence(roomId, msgId);
  }

  Future<List<ChatMessage>> loadEssenceMessages(int roomId) {
    return client.essenceMessages(roomId);
  }

  Future<EssenceStats> loadEssenceStats(int roomId, {String type = 'all'}) {
    return client.essenceStats(roomId, type: type);
  }

  Future<List<ChatMessage>> syncMessages(
    Conversation conversation, {
    int afterId = 0,
  }) async {
    final baseline = afterId > 0
        ? afterId
        : await cache.latestMessageId(conversation);
    final loaded = await client.messages(conversation, afterId: baseline);
    await cache.saveMessages(conversation, loaded);
    await _applyConversationActivity(conversation, loaded);
    return cache.filterLocallyDeletedMessages(conversation, loaded);
  }

  Future<List<ChatMessage>> loadOlderMessages(
    Conversation conversation, {
    int beforeId = 0,
    int limit = 80,
  }) async {
    final baseline = beforeId > 0
        ? beforeId
        : await cache.oldestMessageId(conversation);
    if (baseline <= 0) {
      return const <ChatMessage>[];
    }
    final loaded = await client.messages(
      conversation,
      beforeId: baseline,
      limit: limit,
    );
    await cache.saveMessages(conversation, loaded);
    return cache.filterLocallyDeletedMessages(conversation, loaded);
  }

  Future<List<ChatMessage>> loadMessagesFromNetwork(
    Conversation conversation,
  ) async {
    final loaded = await client.messages(conversation);
    await cache.replaceMessages(conversation, loaded);
    await _applyConversationActivity(conversation, loaded, replace: true);
    return cache.filterLocallyDeletedMessages(conversation, loaded);
  }

  Future<List<ChatMessage>> reloadMessagesFromNetwork(
    Conversation conversation,
  ) async {
    if (conversation.type == ConversationType.private) {
      final loaded = await client.messages(conversation);
      await cache.saveMessages(conversation, loaded);
      await _applyConversationActivity(conversation, loaded);
      return cache.filterLocallyDeletedMessages(conversation, loaded);
    }
    return syncMessages(conversation);
  }

  Future<void> clearLocalCache() async {
    await cache.clearCachedData();
    await ConversationDraftStore.clearAll();
    conversations = const <Conversation>[];
    offlineMode = false;
    notifyListeners();
    try {
      await refreshHome();
    } catch (_) {
      // Keep the cache cleared even if the network refresh fails.
    }
  }

  Future<PerformanceCacheStats> loadPerformanceCacheStats() async {
    final localStats = await cache.stats();
    final imageCache = PaintingBinding.instance.imageCache;
    final diskImageBytes = await backgroundStorageBytes();
    final voiceBytes = await voiceTemporaryStorageBytes();
    final logBytes = await logStorageBytes();
    return PerformanceCacheStats(
      messageCount: localStats.messageCount,
      conversationCount: localStats.conversationCount,
      localDeletedMessageCount: localStats.localDeletedMessageCount,
      messageCacheBytes: localStats.databaseBytes,
      imageCacheBytes:
          imageCache.currentSizeBytes + diskImageBytes + voiceBytes,
      imageCacheEntries:
          imageCache.currentSize +
          imageCache.liveImageCount +
          imageCache.pendingImageCount,
      logBytes: logBytes,
    );
  }

  Future<void> clearPerformanceCaches() async {
    await clearLocalCache();
    await _clearImageCaches(resetBackground: true);
    await _clearLogCaches();
  }

  Future<List<AppLogFile>> loadAppLogFiles() async {
    final files = await loadStoredAppLogFiles();
    return [
      for (final file in files)
        AppLogFile(
          path: file.path,
          name: file.name,
          bytes: file.bytes,
          modified: file.modified,
        ),
    ];
  }

  Future<String> readAppLogFile(
    AppLogFile log, {
    int maxBytes = 256 * 1024,
  }) async {
    return readStoredTextFile(log.path, maxBytes: maxBytes);
  }

  Future<void> _clearImageCaches({required bool resetBackground}) async {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
    await clearStoredImageCaches();
    if (resetBackground && preferences.chatBackgroundPath.trim().isNotEmpty) {
      preferences = preferences.copyWith(chatBackgroundPath: '');
      await preferences.save();
      notifyListeners();
    }
  }

  Future<void> _clearLogCaches() async {
    await clearStoredLogCaches();
  }

  Future<void> logout({bool keepLoginRecord = true}) async {
    final previousUser = user;
    final previousServerUrl = client.baseUrl;
    try {
      if (keepLoginRecord) {
        await client.clearSession();
      } else {
        await client.logout();
      }
    } finally {
      await _clearLocalSessionState(
        previousUser: previousUser,
        previousServerUrl: previousServerUrl,
        removeLoginRecord: !keepLoginRecord,
      );
    }
  }

  Future<void> _applyConversationActivity(
    Conversation conversation,
    List<ChatMessage> messages, {
    bool replace = false,
  }) async {
    if (messages.isEmpty && !replace) {
      return;
    }
    var latest = 0;
    for (final message in messages) {
      final candidate = message.timeSortValue > 0
          ? message.timeSortValue
          : timestampForSort(message.time);
      if (candidate > latest) {
        latest = candidate;
      }
    }
    var changed = false;
    final updated = <Conversation>[
      for (final item in conversations)
        if (item.type == conversation.type && item.id == conversation.id)
          () {
            final nextTime = replace
                ? latest
                : latest > item.lastMessageAt
                ? latest
                : item.lastMessageAt;
            if (nextTime != item.lastMessageAt) {
              changed = true;
            }
            return item.copyWith(lastMessageAt: nextTime);
          }()
        else
          item,
    ];
    if (!changed) {
      return;
    }
    conversations = _sortConversations(updated);
    await cache.saveConversations(conversations);
    notifyListeners();
  }

  Future<void> refreshDebugMode() async {
    try {
      final status = await client.sessionExtensionStatus();
      debugMode = status.active;
    } catch (_) {
      debugMode = false;
    }
    notifyListeners();
  }

  Future<void> activateDebugMode(String key) async {
    final status = await client.activateSessionExtension(key);
    debugMode = status.active;
    notifyListeners();
  }

  Future<void> deactivateDebugMode() async {
    try {
      await client.resetSessionExtension();
    } finally {
      debugMode = false;
      notifyListeners();
    }
  }

  Future<void> banUser(int uid) async {
    await client.banUser(uid);
  }

  Future<void> unbanUser(int uid) async {
    await client.unbanUser(uid);
  }

  Future<void> banRoom(int roomId) async {
    await client.banRoom(roomId);
  }

  Future<void> unbanRoom(int roomId) async {
    await client.unbanRoom(roomId);
  }
}
