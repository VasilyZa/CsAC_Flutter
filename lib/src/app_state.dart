import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'acop_client.dart';
import 'api_client.dart';
import 'api_protocol.dart';
import 'l10n.dart';
import 'local_cache.dart';
import 'models.dart';
import 'platform/app_storage.dart';
import 'preferences.dart';
import 'realtime_client.dart';

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
  CsacAppState({
    CsacApiClient? client,
    AcopApiClient? acopClient,
    CsacLocalCache? cache,
  }) : client = client ?? CsacApiClient(),
       acopClient = acopClient ?? AcopApiClient(),
       cache = cache ?? CsacLocalCache() {
    this.client.onHttpProtocolChanged = _handleHttpProtocolChanged;
    _realtimeEventSub = realtime.events.listen(_handleRealtimeEvent);
    _realtimeStatusSub = realtime.statusChanges.listen((status) {
      if (!_realtimeConnecting &&
          (status == CsacRealtimeStatus.disconnected ||
              status == CsacRealtimeStatus.error)) {
        _scheduleRealtimeReconnect();
      }
      notifyListeners();
    });
  }

  final CsacApiClient client;
  final AcopApiClient acopClient;
  final CsacLocalCache cache;
  final CsacRealtimeClient realtime = CsacRealtimeClient();
  StreamSubscription<CsacRealtimeEvent>? _realtimeEventSub;
  StreamSubscription<CsacRealtimeStatus>? _realtimeStatusSub;
  Timer? _realtimeReconnectTimer;
  Timer? _realtimeHomeRefreshDebounce;
  bool _realtimeConnecting = false;

  String get connectionProtocol => apiHttpProtocolLabel(activeHttpProtocol);

  Stream<CsacRealtimeEvent> get realtimeEvents => realtime.events;

  String get realtimeStatusLabel => !preferences.enableExperimentalWebSocket
      ? 'Disabled'
      : switch (realtime.status) {
          CsacRealtimeStatus.disabled => 'Disabled',
          CsacRealtimeStatus.disconnected => 'Disconnected',
          CsacRealtimeStatus.connecting => 'Connecting',
          CsacRealtimeStatus.connected => 'WebSocket connected',
          CsacRealtimeStatus.error => 'WebSocket error',
        };

  ApiHttpProtocol get activeHttpProtocol => client.lastHttpProtocol;

  void _handleHttpProtocolChanged(ApiHttpProtocol protocol) {
    notifyListeners();
  }

  CsacUser? user;
  AcopDeveloper? acopDeveloper;
  List<Conversation> conversations = const <Conversation>[];
  Set<int> hiddenGroupConversationIds = const <int>{};
  NotificationCounts notificationCounts = const NotificationCounts();
  CsacPreferences preferences = const CsacPreferences();
  Conversation? activeConversation;
  List<EmojiSticker> emojiStickers = const <EmojiSticker>[];
  bool bootstrapping = true;
  bool debugMode = false;
  bool loading = false;
  bool offlineMode = false;
  bool sessionExpired = false;
  bool needsEmailVerification = false;
  bool appInForeground = true;
  String restoreStatus = const CsacStrings(
    Locale('zh', 'CN'),
  ).text('Restoring session...');
  String? error;

  String get currentUserAvatar => user?.avatar.trim() ?? '';

  bool get isAcopMode => preferences.clientMode == AppClientMode.acop;

  bool get hasAcopDeveloper => acopDeveloper != null;

  String get activeServerUrl =>
      isAcopMode ? acopClient.baseUrl : client.baseUrl;

  @override
  void dispose() {
    _realtimeReconnectTimer?.cancel();
    _realtimeHomeRefreshDebounce?.cancel();
    unawaited(_realtimeEventSub?.cancel());
    unawaited(_realtimeStatusSub?.cancel());
    unawaited(realtime.close());
    super.dispose();
  }

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
      if (isAcopMode) {
        restoreStatus = CsacStrings(
          localeForLanguage(preferences.language),
        ).text('Checking saved session...');
        notifyListeners();
        await _restoreAcopSession();
        return;
      }
      await client.loadSession();
      restoreStatus = CsacStrings(
        localeForLanguage(preferences.language),
      ).text('Checking saved session...');
      notifyListeners();
      user = await client.currentUser();
      await cache.saveUser(user!);
      offlineMode = false;
      sessionExpired = false;
      needsEmailVerification = false;
      await loadCachedConversations();
      await syncConversations();
      await refreshNotificationCounts();
      unawaited(loadEmojiStickers(forceRefresh: true));
      await refreshDebugMode();
      unawaited(ensureRealtimeConnection());
    } on CsacEmailVerificationRequiredException {
      user = await cache.loadUser();
      conversations = _sortConversations(await cache.loadConversations());
      offlineMode = false;
      sessionExpired = false;
      needsEmailVerification = true;
      error = null;
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
    await _loginWith(
      usernameForRecord: username,
      loginCall: () async => client.login(
        username,
        password,
        platform: await currentClientPlatform(),
      ),
    );
  }

  Future<void> loginByEmail(String email, String password) async {
    await _loginWith(
      usernameForRecord: email,
      loginCall: () async => client.loginByEmail(
        email,
        password,
        platform: await currentClientPlatform(),
      ),
    );
  }

  Future<void> loginByEmailCode(String email, String emailCode) async {
    await _loginWith(
      usernameForRecord: email,
      loginCall: () async => client.loginByEmailCode(
        email,
        emailCode,
        platform: await currentClientPlatform(),
      ),
    );
  }

  Future<void> acopSendCode(String email, String purpose) {
    return acopClient.sendCode(email: email, purpose: purpose);
  }

  Future<void> acopLogin(String email, String password) async {
    await _acopLoginWith(
      () => acopClient.login(email: email, password: password),
    );
  }

  Future<void> acopLoginByCode(String email, String code) async {
    await _acopLoginWith(
      () => acopClient.loginByCode(email: email, code: code),
    );
  }

  Future<void> acopRegister({
    required String email,
    required String password,
    required String developerName,
    required String code,
    required String csacUsername,
    required String csacPassword,
  }) async {
    await _acopLoginWith(
      () => acopClient.register(
        email: email,
        password: password,
        developerName: developerName,
        code: code,
        csacUsername: csacUsername,
        csacPassword: csacPassword,
      ),
    );
  }

  Future<void> _acopLoginWith(
    Future<AcopDeveloper> Function() loginCall,
  ) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      acopDeveloper = await loginCall();
      error = null;
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> acopLogout() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await acopClient.logout();
    } finally {
      acopDeveloper = null;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loginWith({
    required String usernameForRecord,
    required Future<CsacUser> Function() loginCall,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await loginCall();
      await cache.saveUser(user!);
      await LoginAccountStore.upsert(
        user: user!,
        username: usernameForRecord,
        serverUrl: client.baseUrl,
        sessionCookies: client.sessionSnapshot,
      );
      offlineMode = false;
      sessionExpired = false;
      needsEmailVerification = client.needsEmailVerification;
      error = null;
      if (!needsEmailVerification) {
        await syncConversations();
        await refreshNotificationCounts();
        unawaited(loadEmojiStickers(forceRefresh: true));
        await refreshDebugMode();
        unawaited(ensureRealtimeConnection());
      }
    } on CsacEmailVerificationRequiredException {
      offlineMode = false;
      sessionExpired = false;
      needsEmailVerification = true;
      error = null;
      rethrow;
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
    required String email,
    required String emailCode,
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
        email: email,
        emailCode: emailCode,
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
      needsEmailVerification = false;
      error = null;
      await syncConversations();
      await refreshNotificationCounts();
      unawaited(loadEmojiStickers(forceRefresh: true));
      await refreshDebugMode();
      unawaited(ensureRealtimeConnection());
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<EmailCodeResponse> sendRegisterEmailCode(String email) {
    return client.sendRegisterEmailCode(email: email);
  }

  Future<EmailCodeResponse> sendLoginEmailCode(String email) {
    return client.sendLoginEmailCode(email: email);
  }

  Future<EmailCodeResponse> sendEmailBindCode(String email) {
    return client.sendEmailBindCode(email: email);
  }

  Future<void> requestAccountRestore(String email) {
    return client.requestAccountRestore(email: email);
  }

  Future<void> restoreAccount({
    required String email,
    required String restoreToken,
  }) {
    return client.restoreAccount(email: email, restoreToken: restoreToken);
  }

  Future<void> verifyEmailBindCode({
    required String email,
    required String emailCode,
  }) async {
    await client.verifyEmailBindCode(email: email, emailCode: emailCode);
    needsEmailVerification = false;
    error = null;
    notifyListeners();
    await syncConversations();
    await refreshNotificationCounts();
    unawaited(loadEmojiStickers(forceRefresh: true));
    await refreshDebugMode();
    unawaited(ensureRealtimeConnection());
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

  Future<void> updateConversationSubtitleMode(
    ConversationSubtitleMode mode,
  ) async {
    preferences = preferences.copyWith(conversationSubtitleMode: mode);
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

  Future<void> updateEnableQuickInputTriggers(bool enabled) async {
    preferences = preferences.copyWith(enableQuickInputTriggers: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateMobileEnterKeyBehavior(
    MobileEnterKeyBehavior behavior,
  ) async {
    preferences = preferences.copyWith(mobileEnterKeyBehavior: behavior);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateActionSheetStyle(CsacActionSheetStyle style) async {
    preferences = preferences.copyWith(actionSheetStyle: style);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateShowGroupMemberLevel(bool enabled) async {
    preferences = preferences.copyWith(showGroupMemberLevel: enabled);
    await preferences.save();
    notifyListeners();
  }

  Future<void> updateGroupMemberBadgeMode(GroupMemberBadgeMode mode) async {
    preferences = preferences.copyWith(groupMemberBadgeMode: mode);
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

  Future<void> updateExperimentalWebSocket(bool enabled) async {
    preferences = preferences.copyWith(enableExperimentalWebSocket: enabled);
    await preferences.save();
    notifyListeners();
    if (enabled) {
      unawaited(ensureRealtimeConnection(force: true));
    } else {
      await stopRealtimeConnection();
    }
  }

  Future<void> switchClientMode(AppClientMode mode) async {
    if (mode == preferences.clientMode) {
      return;
    }
    preferences = preferences.copyWith(clientMode: mode);
    await preferences.save();
    if (mode == AppClientMode.acop) {
      await stopRealtimeConnection();
      acopDeveloper = null;
      await _restoreAcopSession();
    } else {
      user = null;
      sessionExpired = false;
      needsEmailVerification = false;
      offlineMode = false;
      await initialize();
      return;
    }
    notifyListeners();
  }

  Future<bool> updateAcopServerUrl(String value) async {
    final normalized = AcopApiClient.normalizeServerUrl(value);
    if (normalized == preferences.acopServerUrl.trim()) {
      _applyPreferredServer();
      return false;
    }
    preferences = preferences.copyWith(acopServerUrl: normalized);
    await preferences.save();
    _applyPreferredServer();
    await acopClient.clearSession();
    acopDeveloper = null;
    error = null;
    notifyListeners();
    return true;
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
    await stopRealtimeConnection();
    _applyPreferredServer();
    await client.clearSession();
    await cache.clear();
    await EmojiStickerStore.clear();
    await EmojiRecentStore.clear();
    await EmojiPinnedStore.clear();
    user = null;
    conversations = const <Conversation>[];
    hiddenGroupConversationIds = const <int>{};
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
    await stopRealtimeConnection();
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
    await EmojiPinnedStore.clear();
    user = null;
    conversations = const <Conversation>[];
    hiddenGroupConversationIds = const <int>{};
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
      needsEmailVerification = false;
    }
  }

  Future<void> refreshCurrentUser() async {
    final previous = user;
    final loaded = await client.currentUser();
    user = _mergeCurrentUser(previous, loaded);
    await cache.saveUser(user!);
    offlineMode = false;
    sessionExpired = false;
    notifyListeners();
  }

  CsacUser _mergeCurrentUser(CsacUser? previous, CsacUser loaded) {
    if (previous == null || previous.uid != loaded.uid) {
      return loaded;
    }
    return CsacUser(
      uid: loaded.uid,
      nickname: loaded.nickname.trim().isEmpty
          ? previous.nickname
          : loaded.nickname,
      username: loaded.username.trim().isEmpty
          ? previous.username
          : loaded.username,
      avatar: loaded.avatar.trim().isEmpty ? previous.avatar : loaded.avatar,
      onlineStatus: loaded.onlineStatus.trim().isEmpty
          ? previous.onlineStatus
          : loaded.onlineStatus,
      platform: loaded.platform.trim().isEmpty || loaded.platform == 'none'
          ? previous.platform
          : loaded.platform,
      patAction: loaded.patAction.trim().isEmpty
          ? previous.patAction
          : loaded.patAction,
      isBot: loaded.isBot || previous.isBot,
    );
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
    acopClient.setBaseUrl(preferences.acopServerUrl);
  }

  Future<void> _restoreAcopSession() async {
    await acopClient.loadSession();
    try {
      acopDeveloper = await acopClient.getDeveloperInfo();
      sessionExpired = false;
      offlineMode = false;
      error = null;
    } on AcopAuthException {
      await acopClient.clearSession();
      acopDeveloper = null;
      sessionExpired = true;
      error = null;
    } on AcopApiException catch (err) {
      acopDeveloper = null;
      sessionExpired = false;
      error = err.toString();
    } catch (err) {
      acopDeveloper = null;
      sessionExpired = false;
      error = err.toString();
    }
  }

  Future<void> ensureRealtimeConnection({bool force = false}) async {
    if (!preferences.enableExperimentalWebSocket || user == null) {
      await stopRealtimeConnection();
      return;
    }
    if (_realtimeConnecting) {
      return;
    }
    if (!force && realtime.connected) {
      realtime.resubscribe(conversations);
      return;
    }
    _realtimeReconnectTimer?.cancel();
    _realtimeConnecting = true;
    notifyListeners();
    try {
      final cookie = client.sessionCookieHeader;
      await realtime.connect(
        uri: client.realtimeWebSocketUri,
        headers: <String, String>{
          if (cookie.isNotEmpty) 'Cookie': cookie,
          'Origin': client.originUrl,
          'User-Agent': 'CsAC/$csacClientBranch experimental-websocket',
        },
        conversations: conversations,
      );
      if (realtime.connected) {
        _realtimeReconnectTimer?.cancel();
        _realtimeReconnectTimer = null;
      } else {
        _scheduleRealtimeReconnect();
      }
    } finally {
      _realtimeConnecting = false;
      notifyListeners();
    }
  }

  Future<void> stopRealtimeConnection() async {
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = null;
    await realtime.disconnect();
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = null;
    notifyListeners();
  }

  void _scheduleRealtimeReconnect() {
    if (!preferences.enableExperimentalWebSocket || user == null) {
      return;
    }
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = Timer(const Duration(seconds: 12), () {
      unawaited(ensureRealtimeConnection(force: true));
    });
  }

  void _handleRealtimeEvent(CsacRealtimeEvent event) {
    if (!preferences.enableExperimentalWebSocket || user == null) {
      return;
    }
    _realtimeHomeRefreshDebounce?.cancel();
    _realtimeHomeRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refreshHome());
    });
  }

  Future<String> currentClientPlatform() async {
    var rawVersion = '0.0.0';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      final buildNumber = packageInfo.buildNumber.trim();
      if (version.isNotEmpty) {
        rawVersion = buildNumber.isEmpty ? version : '$version-$buildNumber';
      }
    } catch (_) {
      // Login should still work if package metadata is unavailable.
    }
    final version = rawVersion.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '.');
    return '$csacClientName-$csacClientBranch-$version';
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
      unawaited(ensureRealtimeConnection());
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

  bool isVisibleActiveConversation(Conversation conversation) {
    return appInForeground && isActiveConversation(conversation);
  }

  void setAppInForeground(bool value) {
    appInForeground = value;
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
    conversations = _sortConversations(
      await _hydrateConversationPreviews(await cache.loadConversations()),
    );
    notifyListeners();
  }

  Future<void> syncConversations() async {
    final loaded = await client.conversations();
    await syncHiddenGroupConversations(silent: true);
    final cachedActivity = await cache.loadConversationActivity();
    final cachedConversations = {
      for (final conversation in await cache.loadConversations())
        '${conversation.type.name}:${conversation.id}': conversation,
    };
    final normalized = _sortConversations(<Conversation>[
      for (final entry in loaded.indexed)
        () {
          final conversation = _mergeConversationDisplay(
            cachedConversations['${entry.$2.type.name}:${entry.$2.id}'],
            entry.$2.copyWith(displayOrder: entry.$1),
          );
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
    if (preferences.enableExperimentalWebSocket) {
      if (realtime.connected) {
        realtime.resubscribe(normalized);
      } else {
        unawaited(ensureRealtimeConnection());
      }
    }
    notifyListeners();
  }

  Future<void> syncHiddenGroupConversations({bool silent = false}) async {
    try {
      hiddenGroupConversationIds = await client.hiddenGroupConversations();
      if (!silent) {
        notifyListeners();
      }
    } catch (_) {}
  }

  bool isConversationHidden(Conversation conversation) {
    return conversation.type == ConversationType.group &&
        hiddenGroupConversationIds.contains(conversation.id);
  }

  Future<bool> toggleHiddenConversation(Conversation conversation) async {
    if (conversation.type != ConversationType.group) {
      throw const CsacApiException('Only group conversations can be hidden.');
    }
    final hidden = await client.toggleHiddenGroupConversation(conversation.id);
    hiddenGroupConversationIds = <int>{...hiddenGroupConversationIds};
    if (hidden) {
      hiddenGroupConversationIds.add(conversation.id);
    } else {
      hiddenGroupConversationIds.remove(conversation.id);
    }
    notifyListeners();
    return hidden;
  }

  Conversation _normalizeConversation(Conversation conversation) {
    return isVisibleActiveConversation(conversation)
        ? conversation.copyWith(unreadCount: 0)
        : conversation;
  }

  Future<List<Conversation>> _hydrateConversationPreviews(
    List<Conversation> input,
  ) async {
    if (input.isEmpty) {
      return input;
    }
    final hydrated = <Conversation>[];
    for (final conversation in input) {
      hydrated.add(await _withLatestCachedPreview(conversation));
    }
    return hydrated;
  }

  Future<Conversation> _withLatestCachedPreview(
    Conversation conversation,
  ) async {
    if (conversation.lastMessagePreview.trim().isNotEmpty) {
      return conversation;
    }
    try {
      final cached = await cache.loadMessages(conversation, limit: 1);
      if (cached.isEmpty) {
        return conversation;
      }
      final latest = cached.last;
      final text = [
        latest.sender.trim().isEmpty ? '' : latest.sender.trim(),
        compactConversationPreviewText(latest),
      ].where((part) => part.trim().isNotEmpty).join(': ');
      return conversation.copyWith(
        lastMessagePreview: [
          text,
          displayConversationPreviewTime(latest),
        ].where((part) => part.trim().isNotEmpty).join(' | '),
      );
    } catch (_) {
      return conversation;
    }
  }

  Conversation _mergeConversationDisplay(
    Conversation? cached,
    Conversation loaded,
  ) {
    if (cached == null) {
      return loaded;
    }
    return loaded.copyWith(
      name: loaded.name.trim().isEmpty ? cached.name : loaded.name,
      avatar: loaded.avatar.trim().isEmpty ? cached.avatar : loaded.avatar,
      subtitle: loaded.subtitle.trim().isEmpty
          ? cached.subtitle
          : loaded.subtitle,
      statusSubtitle: loaded.statusSubtitle.trim().isEmpty
          ? cached.statusSubtitle
          : loaded.statusSubtitle,
      lastMessagePreview: loaded.lastMessagePreview.trim().isEmpty
          ? cached.lastMessagePreview
          : loaded.lastMessagePreview,
    );
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

  Future<SpacePostPage> loadSpacePosts({int page = 1, int pageSize = 20}) {
    return client.spacePosts(page: page, pageSize: pageSize);
  }

  Future<void> sendSpacePost(
    String content, {
    List<Uint8List> imageBytes = const <Uint8List>[],
    List<String> imageFileNames = const <String>[],
  }) async {
    await client.sendSpacePost(
      content,
      imageBytes: imageBytes,
      imageFileNames: imageFileNames,
    );
  }

  Future<void> replySpacePost(
    int replyId,
    String content, {
    List<Uint8List> imageBytes = const <Uint8List>[],
    List<String> imageFileNames = const <String>[],
  }) async {
    await client.replySpacePost(
      replyId,
      content,
      imageBytes: imageBytes,
      imageFileNames: imageFileNames,
    );
  }

  Future<SpaceLikeUpdate> toggleSpaceLike(int contId) {
    return client.toggleSpaceLike(contId);
  }

  Future<void> deleteSpacePost(int contId) {
    return client.deleteSpacePost(contId);
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
      var noticeCount = baseCounts.notices;
      var mentionCount = 0;
      var replyCount = baseCounts.replies;
      var friendChangeCount = baseCounts.friendChanges;
      if (noticeCount > 0) {
        try {
          final notices = await client.notices();
          noticeCount = notices.where((notice) => !notice.isRead).length;
        } catch (_) {}
      }
      try {
        final visibleMentions = await loadVisibleMentionNotices();
        mentionCount = visibleMentions.mentionCount;
        replyCount = visibleMentions.replyCount;
      } catch (_) {
        mentionCount = notificationCounts.mentions;
        replyCount = notificationCounts.replies;
      }
      if (friendChangeCount == 0) {
        try {
          final changes = await client.friendChangeNotices();
          friendChangeCount = changes.where((notice) => !notice.isRead).length;
        } catch (_) {}
      }
      notificationCounts = NotificationCounts(
        notices: noticeCount,
        mentions: mentionCount,
        replies: replyCount,
        friendChanges: friendChangeCount,
        friendRequests: baseCounts.friendRequests,
        groupApplications: baseCounts.groupApplications,
      );
    } catch (_) {
      notificationCounts = NotificationCounts(
        notices: notificationCounts.notices,
        mentions: notificationCounts.mentions,
        replies: notificationCounts.replies,
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
    int? replies,
    int? friendChanges,
    int? friendRequests,
    int? groupApplications,
  }) {
    notificationCounts = NotificationCounts(
      notices: notices ?? notificationCounts.notices,
      mentions: mentions ?? notificationCounts.mentions,
      replies: replies ?? notificationCounts.replies,
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
    if (visible.isNotEmpty) {
      final unread = visible.where((notice) => !notice.isRead);
      return MentionNoticeBundle(
        items: visible,
        mentionCount: unread.where((notice) => !notice.isReply).length,
        replyCount: unread.where((notice) => notice.isReply).length,
      );
    }
    return MentionNoticeBundle(items: visible, mentionCount: 0, replyCount: 0);
  }

  Future<void> markMentionNoticeRead(MentionNotice notice) async {
    await MentionNoticeStore.markRead(notice);
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(
      mentions: visible.mentionCount,
      replies: visible.replyCount,
    );
  }

  Future<void> markMentionSummaryRead() async {
    final bundle = await client.mentionNotices();
    final clearedKeys = await MentionNoticeStore.loadClearedKeys();
    final visible = <MentionNotice>[
      for (final item in bundle.items)
        if (!clearedKeys.contains(MentionNoticeStore.clearedKey(item))) item,
    ];
    await MentionNoticeStore.markAllRead(visible);
    updateNotificationCounts(mentions: 0, replies: 0);
  }

  Future<void> clearMentionNotice(MentionNotice notice) async {
    await MentionNoticeStore.clear(notice);
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(
      mentions: visible.mentionCount,
      replies: visible.replyCount,
    );
  }

  Future<void> clearMentionSummary() async {
    await MentionNoticeStore.clearSummary();
    final visible = await loadVisibleMentionNotices();
    updateNotificationCounts(
      mentions: visible.mentionCount,
      replies: visible.replyCount,
    );
  }

  Future<List<FriendChangeNotice>> loadFriendChangeNotices() {
    return client.friendChangeNotices();
  }

  Future<void> markFriendChangeRead({
    int? friendId,
    bool readAll = false,
  }) async {
    await client.markFriendChangeRead(friendId: friendId, readAll: readAll);
    if (readAll) {
      updateNotificationCounts(friendChanges: 0);
    } else if (friendId != null) {
      updateNotificationCounts(
        friendChanges: math.max(0, notificationCounts.friendChanges - 1),
      );
    }
    await refreshNotificationCounts();
  }

  Future<void> markNoticeRead({int? noticeId, bool readAll = false}) async {
    await client.markNoticeRead(noticeId: noticeId, readAll: readAll);
    if (readAll) {
      updateNotificationCounts(notices: 0);
    } else if (noticeId != null) {
      updateNotificationCounts(
        notices: math.max(0, notificationCounts.notices - 1),
      );
    }
    await refreshNotificationCounts();
  }

  Future<List<FriendRequest>> loadFriendRequests() {
    return client.friendRequests();
  }

  Future<List<Friend>> loadFriends() {
    return client.friends();
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

  Future<String> sendFriendRequest(int uid, String message) async {
    final result = await client.sendFriendRequest(uid, message);
    await syncConversations();
    return result;
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
    required bool allowSearch,
  }) async {
    await client.updateGroupSettings(
      roomId,
      joinType: joinType,
      code: code,
      question: question,
      answer: answer,
      showPublic: showPublic,
      allowInvite: allowInvite,
      allowSearch: allowSearch,
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

  Future<String> inviteGroupMember(int roomId, int targetUid) async {
    final result = await client.inviteGroupMember(roomId, targetUid);
    await syncConversations();
    return result;
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
      var loaded = await client.messages(conversation);
      if (loaded.isEmpty) {
        loaded = await client.messages(conversation, limit: 20);
        if (loaded.isEmpty) {
          await cache.replaceMessages(conversation, const <ChatMessage>[]);
          await _applyConversationActivity(conversation, const <ChatMessage>[]);
          return const <ChatMessage>[];
        }
      }
      await cache.removeMessagesMissingFromWindow(conversation, loaded);
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
