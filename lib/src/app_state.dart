import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'l10n.dart';
import 'local_cache.dart';
import 'models.dart';
import 'notification_service.dart';
import 'preferences.dart';

class CsacAppState extends ChangeNotifier {
  CsacAppState({
    CsacApiClient? client,
    CsacLocalCache? cache,
    CsacNotificationService? notifications,
  }) : notifications = notifications ?? CsacNotificationService(),
       client = client ?? CsacApiClient(),
       cache = cache ?? CsacLocalCache();

  final CsacApiClient client;
  final CsacLocalCache cache;
  final CsacNotificationService notifications;

  CsacUser? user;
  List<Conversation> conversations = const <Conversation>[];
  NotificationCounts notificationCounts = const NotificationCounts();
  CsacPreferences preferences = const CsacPreferences();
  Conversation? activeConversation;
  Set<String> mutedConversationKeys = const <String>{};

  /// 用户已查看过的通知类型，刷新时这些计数保持为 0
  final Set<String> _dismissedBadges = <String>{};

  bool bootstrapping = true;
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
      mutedConversationKeys = await MutedConversationStore.load();
      _dismissedBadges.addAll(await DismissedBadgeStore.load());
      unawaited(notifications.initialize());
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
    } on CsacAuthException catch (err) {
      await client.clearSession();
      user = await cache.loadUser();
      conversations = await cache.loadConversations();
      sessionExpired = true;
      offlineMode = user != null;
      error = user == null
          ? err.toString()
          : CsacStrings(
              localeForLanguage(preferences.language),
            ).text('Session expired. Cached history is available offline.');
    } catch (_) {
      user = await cache.loadUser();
      conversations = await cache.loadConversations();
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
      offlineMode = false;
      sessionExpired = false;
      error = null;
      await syncConversations();
      await refreshNotificationCounts();
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
    String? avatarFileName,
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
      offlineMode = false;
      sessionExpired = false;
      error = null;
      await syncConversations();
      await refreshNotificationCounts();
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
    user = null;
    conversations = const <Conversation>[];
    notificationCounts = const NotificationCounts();
    activeConversation = null;
    offlineMode = false;
    sessionExpired = false;
    error = null;
    notifyListeners();
    return true;
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

  Future<void> upgradePassword(
    String oldPassword,
    String newPassword,
    String confirmPassword,
  ) {
    return client.upgradePassword(oldPassword, newPassword, confirmPassword);
  }

  Future<void> deleteAccount() async {
    try {
      await client.deleteAccount();
    } finally {
      await cache.clear();
      await ConversationDraftStore.clearAll();
      user = null;
      conversations = const <Conversation>[];
      notificationCounts = const NotificationCounts();
      activeConversation = null;
      offlineMode = false;
      sessionExpired = false;
      error = null;
      notifyListeners();
    }
  }

  void _applyPreferredServer() {
    client.setBaseUrl(preferences.serverUrl);
  }

  bool isActiveConversation(Conversation conversation) {
    return activeConversation?.type == conversation.type &&
        activeConversation?.id == conversation.id;
  }

  void setActiveConversation(Conversation? conversation) {
    activeConversation = conversation;
  }

  bool isConversationMuted(Conversation conversation) {
    return mutedConversationKeys.contains(_conversationKey(conversation));
  }

  Future<void> setConversationMuted(
    Conversation conversation,
    bool muted,
  ) async {
    final updated = mutedConversationKeys.toSet();
    final key = _conversationKey(conversation);
    if (muted) {
      updated.add(key);
    } else {
      updated.remove(key);
    }
    mutedConversationKeys = updated;
    await MutedConversationStore.save(updated);
    notifyListeners();
  }

  String _conversationKey(Conversation conversation) {
    return '${conversation.type.name}:${conversation.id}';
  }

  Future<void> loadConversations() async {
    try {
      await syncConversations();
    } catch (_) {
      conversations = await cache.loadConversations();
      offlineMode = user != null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadCachedConversations() async {
    conversations = await cache.loadConversations();
    notifyListeners();
  }

  Future<void> syncConversations() async {
    final loaded = await client.conversations();
    final normalized = <Conversation>[
      for (final conversation in loaded)
        isActiveConversation(conversation)
            ? conversation.copyWith(unreadCount: 0)
            : conversation,
    ];
    conversations = normalized;
    await cache.saveConversations(normalized);
    offlineMode = false;
    notifyListeners();
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
    conversations = updated;
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
      final results = await Future.wait<NotificationCounts>([
        client.notificationCounts(),
        client.mentionCounts(),
      ]);
      final base = results[0];
      final mentions = results[1];
      // 服务器计数归零时自动清除 dismissed 标记
      if (base.notices == 0) _dismissedBadges.remove('notices');
      if (base.friendRequests == 0) _dismissedBadges.remove('friendRequests');
      if (base.groupApplications == 0) _dismissedBadges.remove('groupApplications');
      if (mentions.mentions == 0) _dismissedBadges.remove('mentions');
      if (mentions.replies == 0) _dismissedBadges.remove('replies');
      unawaited(DismissedBadgeStore.save(_dismissedBadges));
      notificationCounts = NotificationCounts(
        notices: _dismissedBadges.contains('notices') ? 0 : base.notices,
        friendRequests: _dismissedBadges.contains('friendRequests') ? 0 : base.friendRequests,
        groupApplications: _dismissedBadges.contains('groupApplications') ? 0 : base.groupApplications,
        mentions: _dismissedBadges.contains('mentions') ? 0 : mentions.mentions,
        replies: _dismissedBadges.contains('replies') ? 0 : mentions.replies,
      );
    } catch (_) {
      notificationCounts = NotificationCounts(
        notices: _dismissedBadges.contains('notices') ? 0 : notificationCounts.notices,
        friendRequests: _dismissedBadges.contains('friendRequests') ? 0 : notificationCounts.friendRequests,
        groupApplications: _dismissedBadges.contains('groupApplications') ? 0 : notificationCounts.groupApplications,
        mentions: _dismissedBadges.contains('mentions') ? 0 : notificationCounts.mentions,
        replies: _dismissedBadges.contains('replies') ? 0 : notificationCounts.replies,
      );
    }
    notifyListeners();
  }

  Future<NotificationCounts> refreshMentionCounts() async {
    final mentions = await client.mentionCounts();
    notificationCounts = NotificationCounts(
      notices: notificationCounts.notices,
      friendRequests: notificationCounts.friendRequests,
      groupApplications: notificationCounts.groupApplications,
      mentions: _dismissedBadges.contains('mentions') ? 0 : mentions.mentions,
      replies: _dismissedBadges.contains('replies') ? 0 : mentions.replies,
    );
    notifyListeners();
    return notificationCounts;
  }

  void updateNotificationCounts({
    int? notices,
    int? friendRequests,
    int? groupApplications,
    int? mentions,
    int? replies,
  }) {
    notificationCounts = NotificationCounts(
      notices: notices ?? notificationCounts.notices,
      friendRequests: friendRequests ?? notificationCounts.friendRequests,
      groupApplications:
          groupApplications ?? notificationCounts.groupApplications,
      mentions: mentions ?? notificationCounts.mentions,
      replies: replies ?? notificationCounts.replies,
    );
    notifyListeners();
  }

  /// 标记某类通知红点为已消除，后续定时刷新不再恢复
  void dismissBadges(Set<String> keys) {
    _dismissedBadges.addAll(keys);
    unawaited(DismissedBadgeStore.save(_dismissedBadges));
  }

  /// 清除所有 dismissed 标记，下次刷新恢复服务器数据
  void restoreAllBadges() {
    _dismissedBadges.clear();
    unawaited(DismissedBadgeStore.clear());
  }

  Future<void> markConversationUnread(Conversation conversation) async {
    final updated = <Conversation>[
      for (final item in conversations)
        item.type == conversation.type && item.id == conversation.id
            ? item.copyWith(
                unreadCount: item.unreadCount > 0 ? item.unreadCount : 1,
              )
            : item,
    ];
    conversations = updated;
    await cache.saveConversations(updated);
    notifyListeners();
  }

  Future<void> clearConversationLocalCache(Conversation conversation) async {
    await cache.clearConversationMessages(conversation);
    await ConversationDraftStore.clear(conversation);
  }

  Future<List<CsacNotice>> loadNotices() {
    return client.notices();
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

  Future<List<FriendDeletedNotice>> loadDeletedFriendNotices() {
    return client.deletedFriendNotices();
  }

  Future<void> handleGroupApplication(int applyId, String action) async {
    await client.handleGroupApplication(applyId, action);
    await refreshNotificationCounts();
  }

  Future<List<ChatMessage>> loadCachedMessages(Conversation conversation) {
    return cache.loadMessages(conversation);
  }

  Future<List<ChatMessage>> loadCachedMessagesAround(
    Conversation conversation,
    int messageId,
  ) {
    return cache.loadMessagesAround(conversation, messageId);
  }

  Future<List<MessageSearchResult>> searchMessages(
    String query,
    SearchScope scope,
  ) {
    return cache.searchMessages(query, scope);
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

  Future<CreatedGroup> createGroup(String roomName) async {
    final created = await client.createGroup(roomName);
    await syncConversations();
    return created;
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

  Future<void> updateGroupSettings(
    int roomId, {
    required String joinType,
    required String code,
    required String question,
    required String answer,
    required bool showPublic,
  }) async {
    await client.updateGroupSettings(
      roomId,
      joinType: joinType,
      code: code,
      question: question,
      answer: answer,
      showPublic: showPublic,
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

  Future<void> recallMessage(Conversation conversation, int msgId) {
    return client.recallMessage(conversation, msgId);
  }

  Future<void> toggleEssence(int roomId, int msgId) {
    return client.toggleEssence(roomId, msgId);
  }

  Future<List<ChatMessage>> loadEssenceMessages(int roomId) {
    return client.essenceMessages(roomId);
  }

  Future<EssenceStats> loadEssenceStats(int roomId, String type) {
    return client.essenceStats(roomId, type);
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
    return cache.filterLocallyDeletedMessages(conversation, loaded);
  }

  Future<List<ChatMessage>> loadMessagesFromNetwork(
    Conversation conversation,
  ) async {
    final loaded = await client.messages(conversation);
    await cache.replaceMessages(conversation, loaded);
    return cache.filterLocallyDeletedMessages(conversation, loaded);
  }

  Future<List<ChatMessage>> reloadMessagesFromNetwork(
    Conversation conversation,
  ) {
    return loadMessagesFromNetwork(conversation);
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

  Future<void> logout() async {
    try {
      await client.logout();
    } finally {
      await cache.clear();
      await ConversationDraftStore.clearAll();
      await DismissedBadgeStore.clear();
      _dismissedBadges.clear();
      user = null;
      conversations = const <Conversation>[];
      notificationCounts = const NotificationCounts();
      activeConversation = null;
      offlineMode = false;
      notifyListeners();
    }
  }
}
