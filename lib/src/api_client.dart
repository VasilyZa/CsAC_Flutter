import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'platform/platform_support.dart';

class CsacApiException implements Exception {
  const CsacApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CsacAuthException extends CsacApiException {
  const CsacAuthException(super.message);
}

class NetworkDiagnosticReport {
  const NetworkDiagnosticReport({
    required this.serverUrl,
    required this.originUrl,
    required this.startedAt,
    required this.totalMs,
    required this.checks,
  });

  final String serverUrl;
  final String originUrl;
  final DateTime startedAt;
  final int totalMs;
  final List<NetworkDiagnosticCheck> checks;

  bool get passed => checks.every((check) => check.ok);
}

class NetworkDiagnosticCheck {
  const NetworkDiagnosticCheck({
    required this.name,
    required this.ok,
    required this.elapsedMs,
    this.detail = '',
  });

  final String name;
  final bool ok;
  final int elapsedMs;
  final String detail;
}

class ApiDebugResponse {
  const ApiDebugResponse({
    required this.method,
    required this.route,
    required this.statusCode,
    required this.elapsedMs,
    required this.body,
    required this.decoded,
  });

  final String method;
  final String route;
  final int statusCode;
  final int elapsedMs;
  final String body;
  final Object? decoded;

  String get prettyBody {
    if (decoded != null) {
      try {
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {}
    }
    return body;
  }
}

class SessionExtensionStatus {
  const SessionExtensionStatus({
    required this.active,
    required this.expiresAt,
    required this.expiresIn,
  });

  final bool active;
  final int expiresAt;
  final int expiresIn;

  factory SessionExtensionStatus.fromJson(Map<String, dynamic> json) {
    final expiresIn = asInt(json['expires_in']);
    final expiresAt = asInt(json['expires_at']);
    return SessionExtensionStatus(
      active: asBool(json['active']) || expiresIn > 0 || expiresAt > 0,
      expiresAt: expiresAt,
      expiresIn: expiresIn,
    );
  }
}

class CsacApiClient {
  CsacApiClient({http.Client? httpClient, String baseUrl = defaultBaseUrl})
    : _http = httpClient ?? createPlatformHttpClient(),
      _baseUrl = normalizeServerUrl(baseUrl) {
    configureApiAssetBaseUrl(_baseUrl);
  }

  static const defaultBaseUrl = 'https://103.40.14.14:14660/rpc/UniCsAC.php';
  static const _defaultApiPath = '/rpc/UniCsAC.php';
  static const _sessionKey = 'csac.cookies';

  final http.Client _http;
  String _baseUrl;
  final Map<String, String> _cookies = <String, String>{};

  String get baseUrl => _baseUrl;

  String get originUrl => apiOriginFromBaseUrl(_baseUrl);

  String get connectionProtocol => lastPlatformHttpProtocol(_http) ?? '';

  Map<String, String> get sessionSnapshot => Map<String, String>.from(_cookies);

  void setBaseUrl(String value) {
    _baseUrl = normalizeServerUrl(value);
    configureApiAssetBaseUrl(_baseUrl);
  }

  static String normalizeServerUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return defaultBaseUrl;
    }
    final withScheme = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.trim().isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Invalid CsAC server address.');
    }

    var path = uri.path;
    if (path.isEmpty || path == '/') {
      path = _defaultApiPath;
    } else if (path.endsWith('/rpc/')) {
      path = '${path}UniCsAC.php';
    } else if (path.endsWith('/rpc')) {
      path = '$path/UniCsAC.php';
    } else if (path.endsWith('/')) {
      path = '${path}rpc/UniCsAC.php';
    }

    return uri
        .replace(
          path: path,
          query: uri.query.isEmpty ? null : uri.query,
          fragment: null,
        )
        .toString();
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _cookies
        ..clear()
        ..addAll(decoded.map((key, value) => MapEntry(key, value.toString())));
    }
  }

  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(_cookies));
  }

  Future<void> restoreSession(Map<String, String> cookies) async {
    _cookies
      ..clear()
      ..addAll(cookies);
    await saveSession();
  }

  Future<void> clearSession() async {
    _cookies.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<CsacUser> login(
    String username,
    String password, {
    String? platform,
  }) async {
    final clientPlatform = platform ?? await _clientPlatformIdentifier();
    final data = await postForm('auth/login', <String, String>{
      'username': username,
      'pwd': password,
      'platform': clientPlatform,
    });
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const CsacApiException('Login succeeded but no user was returned.');
    }
    await saveSession();
    await refreshPlatform(platform: clientPlatform);
    return CsacUser.fromJson(user);
  }

  Future<void> refreshPlatform({String? platform}) async {
    await get('user/get_info', <String, String>{
      'platform': platform ?? await _clientPlatformIdentifier(),
    });
  }

  Future<String> _clientPlatformIdentifier() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version.trim().isEmpty
        ? '0.0.0'
        : packageInfo.version.trim();
    return '$csacClientName-$csacClientBranch-$version';
  }

  Future<CsacUser> register({
    required String username,
    required String nickname,
    required String password,
    required String confirmPassword,
    Uint8List? avatarBytes,
    String avatarFileName = '',
  }) async {
    final fields = <String, String>{
      'username': username.trim(),
      'nickname': nickname.trim(),
      'pwd': password,
      'confirm_pwd': confirmPassword,
    };
    final data = avatarBytes == null
        ? await postForm('auth/register', fields)
        : await postMultipart(
            'auth/register',
            fields,
            fileField: 'avatar',
            fileBytes: avatarBytes,
            fileName: avatarFileName.isEmpty ? 'avatar.png' : avatarFileName,
          );
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const CsacApiException(
        'Register succeeded but no user was returned.',
      );
    }
    await saveSession();
    return CsacUser.fromJson(user);
  }

  Future<void> logout() async {
    try {
      await postForm('auth/logout');
    } finally {
      await clearSession();
    }
  }

  Future<void> deleteAccount() async {
    try {
      await postForm('user/delete_account');
    } finally {
      await clearSession();
    }
  }

  Future<CsacUser> currentUser() async {
    final data = await get('user/get_info', <String, String>{
      'platform': await _clientPlatformIdentifier(),
    });
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const CsacApiException('Server did not return user info.');
    }
    return CsacUser.fromJson(user);
  }

  Future<NetworkDiagnosticReport> runNetworkDiagnostics({
    String? imageUrl,
  }) async {
    final startedAt = DateTime.now();
    final total = Stopwatch()..start();
    final checks = <NetworkDiagnosticCheck>[];
    checks.add(
      await _diagnosticCheck('Server latency', () async {
        final response = await _sendOnce(
          http.Request('GET', Uri.parse(originUrl)),
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode < 200 || response.statusCode >= 500) {
          throw CsacApiException('HTTP ${response.statusCode}');
        }
        return 'HTTP ${response.statusCode}';
      }),
    );
    checks.add(
      await _diagnosticCheck('API availability', () async {
        final data = await get('user/get_info');
        return data['success'] == true
            ? 'API returned success'
            : 'API reachable';
      }),
    );
    checks.add(
      await _diagnosticCheck('Login status', () async {
        final user = await currentUser();
        final name = user.nickname.isNotEmpty ? user.nickname : user.username;
        return name.isEmpty ? 'UID ${user.uid}' : '$name / UID ${user.uid}';
      }),
    );
    final targetImage = imageUrl?.trim();
    checks.add(
      targetImage == null || targetImage.isEmpty
          ? const NetworkDiagnosticCheck(
              name: 'Image domain',
              ok: true,
              elapsedMs: 0,
              detail: 'No image URL cached yet',
            )
          : await _diagnosticCheck('Image domain', () async {
              final uri = Uri.parse(targetImage);
              final response = await _sendOnce(
                _binaryRequest(uri, 'image/*, */*'),
              ).timeout(const Duration(seconds: 8));
              if (response.statusCode < 200 || response.statusCode >= 400) {
                throw CsacApiException('HTTP ${response.statusCode} $uri');
              }
              final type = response.headers['content-type'] ?? 'unknown';
              return '$type, ${response.bodyBytes.length} B, $uri';
            }),
    );
    total.stop();
    return NetworkDiagnosticReport(
      serverUrl: baseUrl,
      originUrl: originUrl,
      startedAt: startedAt,
      totalMs: total.elapsedMilliseconds,
      checks: checks,
    );
  }

  Future<void> updateNickname(String nickname) {
    return postForm('user/update_profile', <String, String>{
      'action': 'nickname',
      'nickname': nickname.trim(),
    });
  }

  Future<void> updatePatAction(String patAction) {
    return postForm('user/update_profile', <String, String>{
      'action': 'pat_action',
      'pat_action': patAction.trim(),
    });
  }

  Future<void> updatePassword(
    String oldPassword,
    String newPassword,
    String confirmPassword,
  ) {
    return postForm('user/update_profile', <String, String>{
      'action': 'password',
      'old_password': oldPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }

  Future<void> updateAvatar(Uint8List avatarBytes, String fileName) {
    return postMultipart(
      'user/update_profile',
      <String, String>{'action': 'avatar'},
      fileField: 'avatar',
      fileBytes: avatarBytes,
      fileName: fileName,
    );
  }

  Future<UserProfile> userProfile(int uid) async {
    final data = await get('user/get_info', <String, String>{'uid': '$uid'});
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const CsacApiException('Server did not return user info.');
    }
    return UserProfile.fromJson(user);
  }

  Future<List<GroupProfile>> createdGroups(int uid) async {
    final data = await get(
      'user/get_created_groups',
      uid > 0 ? <String, String>{'uid': '$uid'} : null,
    );
    return _firstList(data, const [
      'groups',
      'rooms',
      'list',
      'data',
    ]).map(GroupProfile.fromJson).toList();
  }

  Future<List<Friend>> friends() async {
    final data = await get('user/get_friends');
    return _list(data, 'friends').map(Friend.fromJson).toList();
  }

  Future<List<Group>> groups() async {
    final data = await get('user/get_groups');
    return _list(data, 'groups').map(Group.fromJson).toList();
  }

  Future<List<GroupProfile>> publicGroups() async {
    final data = await get('group/get_public_list');
    return _firstList(data, const [
      'groups',
      'rooms',
      'list',
      'data',
    ]).map(GroupProfile.fromJson).toList();
  }

  Future<GroupProfile> createGroup(String roomName) async {
    final data = await postForm('group/create', <String, String>{
      'room_name': roomName.trim(),
    });
    final roomId = firstInt(data, const ['room_id', 'id', 'rid']);
    final inviteCode = firstString(data, const ['invite_code', 'code']);
    if (roomId <= 0) {
      throw const CsacApiException('Server did not return group id.');
    }
    return GroupProfile(
      id: roomId,
      name: roomName.trim().isEmpty ? 'Room $roomId' : roomName.trim(),
      inviteCode: inviteCode,
      isInGroup: true,
      isOwner: true,
    );
  }

  Future<GroupProfile> groupProfile(int roomId) async {
    final data = await get('group/get_group_view_info', <String, String>{
      'room_id': '$roomId',
    });
    final raw = _firstMap(data, const ['room', 'group', 'data']);
    if (raw == null) {
      throw const CsacApiException('Server did not return group info.');
    }
    return GroupProfile.fromJson(raw);
  }

  Future<List<GroupMember>> groupMembers(int roomId) async {
    final data = await get('group/get_members', <String, String>{
      'room_id': '$roomId',
    });
    return _firstList(data, const [
      'members',
      'list',
      'data',
    ]).map(GroupMember.fromJson).toList();
  }

  Future<NotificationCounts> notificationCounts() async {
    final data = await get('user/get_notifications');
    final nested = data['data'];
    if (nested is Map) {
      return NotificationCounts.fromJson({
        ...data,
        ...Map<String, dynamic>.from(nested),
      });
    }
    return NotificationCounts.fromJson(data);
  }

  Future<MentionNoticeBundle> mentionNotices() async {
    final data = await get('message/get_mentions');
    final mentionRows = _firstList(data, const [
      'mentions',
      'mention_list',
      'mention_items',
      'mention_messages',
      'mention_msgs',
      'at_list',
      'at_items',
      'at_messages',
      'messages',
      'items',
      'list',
      'data',
    ]);
    final replyRows = _firstList(data, const [
      'replies',
      'reply_list',
      'reply_items',
      'reply_messages',
      'reply_msgs',
      'reply_notices',
    ]);
    final items = <MentionNotice>[
      for (final row in mentionRows)
        MentionNotice.fromJson(row, fallbackKind: 'mention'),
      for (final row in replyRows)
        MentionNotice.fromJson(row, fallbackKind: 'reply'),
    ];
    items.sort((a, b) => b.message.time.compareTo(a.message.time));
    final nested = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;
    return MentionNoticeBundle(
      items: items,
      mentionCount: firstInt(nested, const [
        'mention_count',
        'mentions_count',
        'mention_unread',
        'unread_mentions',
        'at_count',
      ]),
      replyCount: firstInt(nested, const [
        'reply_count',
        'replies_count',
        'reply_unread',
        'unread_replies',
      ]),
    );
  }

  Future<List<CsacNotice>> notices() async {
    final data = await get('user/get_notice_list');
    return _firstList(data, const [
      'notices',
      'notice_list',
      'list',
      'data',
    ]).map(CsacNotice.fromJson).toList();
  }

  Future<void> markNoticeRead({int? noticeId, bool readAll = false}) {
    return postForm('user/mark_notice_read', <String, String>{
      if (readAll) 'read_all': '1',
      if (!readAll && noticeId != null) 'notice_id': '$noticeId',
    });
  }

  Future<List<FriendChangeNotice>> friendChangeNotices() async {
    final data = await get('friend/get_deleted_notices');
    return _firstList(data, const [
        'notices',
        'deleted_notices',
        'deleted_friends',
        'friends',
        'list',
        'data',
      ]).map(FriendChangeNotice.fromJson).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  Future<List<FriendRequest>> friendRequests() async {
    final data = await get('friend/get_friend_requests');
    return _firstList(data, const [
      'requests',
      'friend_requests',
      'list',
      'data',
    ]).map(FriendRequest.fromJson).toList();
  }

  Future<void> handleFriendRequest(int requestId, String action) {
    return postForm('friend/handle_request', <String, String>{
      'request_id': '$requestId',
      'action': action,
    });
  }

  Future<void> sendFriendRequest(int uid, String message) {
    return postForm('friend/send_request', <String, String>{
      'to_uid': '$uid',
      if (message.trim().isNotEmpty) 'message': message.trim(),
    });
  }

  Future<void> updateFriendRemark(int friendId, String remark) {
    return postForm('friend/update_remark', <String, String>{
      'friend_id': '$friendId',
      'remark': remark,
    });
  }

  Future<void> deleteFriend(int friendId) {
    return postForm('friend/delete_friend', <String, String>{
      'friend_id': '$friendId',
    });
  }

  Future<void> blockFriend(int friendId) {
    return postForm('friend/block_friend', <String, String>{
      'friend_id': '$friendId',
    });
  }

  Future<void> recoverFriend(
    int friendId, {
    bool direct = true,
    String message = '',
  }) {
    return postForm('friend/recover_friend', <String, String>{
      'friend_id': '$friendId',
      if (direct) 'direct': '1',
      if (message.trim().isNotEmpty) 'message': message.trim(),
    });
  }

  Future<List<CommonGroup>> commonGroups(int friendId) async {
    final data = await get('friend/get_common_groups', <String, String>{
      'friend_id': '$friendId',
    });
    return _firstList(data, const [
      'groups',
      'common_groups',
      'list',
      'data',
    ]).map(CommonGroup.fromJson).toList();
  }

  Future<List<GroupApplication>> groupApplications({
    int? roomId,
    String roomName = '',
  }) async {
    final data = await get('group/get_applications', <String, String>{
      if (roomId != null) 'room_id': '$roomId',
    });
    return _firstList(data, const [
      'applications',
      'applies',
      'apply_list',
      'list',
      'data',
    ]).map((item) {
      return GroupApplication.fromJson(
        item,
        fallbackRoomId: roomId ?? 0,
        fallbackRoomName: roomName,
      );
    }).toList();
  }

  Future<void> handleGroupApplication(int applyId, String action) {
    return postForm('group/handle_apply', <String, String>{
      'apply_id': '$applyId',
      'action': action,
    });
  }

  Future<void> applyJoinGroup(
    int roomId, {
    String code = '',
    String answer = '',
  }) {
    return postForm('group/apply_join', <String, String>{
      'room_id': '$roomId',
      if (code.trim().isNotEmpty) 'code': code.trim(),
      if (answer.trim().isNotEmpty) 'answer': answer.trim(),
    });
  }

  Future<void> submitReport({
    required String type,
    required int targetId,
    required String reason,
    bool anonymous = false,
    String targetName = '',
  }) {
    return postForm('report/submit_report', <String, String>{
      'type': type,
      if (type == 'user') 'uid': '$targetId',
      if (type == 'group') 'rid': '$targetId',
      'reason': reason.trim(),
      'anonymous': anonymous ? '1' : '0',
      if (targetName.trim().isNotEmpty) 'target_name': targetName.trim(),
    });
  }

  Future<void> submitBugReport({
    required String title,
    required String description,
  }) {
    return postForm('bug_report', <String, String>{
      'title': title.trim(),
      'description': description.trim(),
    });
  }

  Future<void> leaveGroup(int roomId) {
    return postForm('group/leave', <String, String>{'room_id': '$roomId'});
  }

  Future<void> editGroupInfo(
    int roomId, {
    required String roomName,
    required String description,
    required String notice,
  }) {
    return postForm('group/edit_info', <String, String>{
      'room_id': '$roomId',
      'room_name': roomName.trim(),
      'intro': description,
      'description': description,
      'notice': notice,
    });
  }

  Future<void> updateGroupAvatar(
    int roomId,
    Uint8List avatarBytes,
    String fileName,
  ) {
    return postMultipart(
      'group/edit_info',
      <String, String>{'room_id': '$roomId', 'action': 'avatar'},
      fileField: 'avatar',
      fileBytes: avatarBytes,
      fileName: fileName,
    );
  }

  Future<void> updateGroupSettings(
    int roomId, {
    required String joinType,
    required String code,
    required String question,
    required String answer,
    required bool showPublic,
    required bool allowInvite,
  }) {
    return postForm('group/update_settings', <String, String>{
      'room_id': '$roomId',
      'join_type': joinType.trim(),
      'code': code.trim(),
      'fixed_code': code.trim(),
      'question': question.trim(),
      'answer': answer.trim(),
      'show_public': showPublic ? '1' : '0',
      'show_in_list': showPublic ? '1' : '0',
      'allow_invite': allowInvite ? '1' : '0',
    });
  }

  Future<void> inviteGroupMember(int roomId, int targetUid) {
    return postForm('group/invite_member', <String, String>{
      'room_id': '$roomId',
      'rid': '$roomId',
      'target_uid': '$targetUid',
      'uid': '$targetUid',
    });
  }

  Future<void> setGroupMemberTitle(
    int roomId,
    int targetUid, {
    required String title,
    required int level,
  }) {
    return postForm('group/set_member_title', <String, String>{
      'room_id': '$roomId',
      'rid': '$roomId',
      'target_uid': '$targetUid',
      'uid': '$targetUid',
      'title': title.trim(),
      'level': '$level',
    });
  }

  Future<void> resetInviteCode(int roomId) {
    return postForm('group/reset_invite_code', <String, String>{
      'room_id': '$roomId',
    });
  }

  Future<void> transferGroup(int roomId, int targetUid) {
    return postForm('group/transfer', <String, String>{
      'room_id': '$roomId',
      'target_uid': '$targetUid',
    });
  }

  Future<void> disbandGroup(int roomId) {
    return postForm('group/disband', <String, String>{'room_id': '$roomId'});
  }

  Future<void> muteGroupMember(int roomId, int targetUid, int minutes) {
    return postForm('group/mute_member', <String, String>{
      'room_id': '$roomId',
      'target_uid': '$targetUid',
      'action': minutes > 0 ? 'mute' : 'unmute',
      if (minutes > 0) 'minutes': '$minutes',
    });
  }

  Future<void> kickGroupMember(int roomId, int targetUid) {
    return postForm('group/kick_member', <String, String>{
      'room_id': '$roomId',
      'target_uid': '$targetUid',
    });
  }

  Future<void> setGroupAdmin(int roomId, int targetUid, bool set) {
    return postForm('group/set_admin', <String, String>{
      'room_id': '$roomId',
      'target_uid': '$targetUid',
      'action': set ? 'set' : 'remove',
    });
  }

  Future<List<Conversation>> conversations() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      friends(),
      groups(),
    ]);
    final friendsList = results[0] as List<Friend>;
    final groupsList = results[1] as List<Group>;
    return <Conversation>[
      for (final friend in friendsList)
        Conversation(
          type: ConversationType.private,
          id: friend.id,
          name: friend.name,
          avatar: friend.avatar,
          subtitle: friend.subtitle,
          statusSubtitle: friend.statusSubtitle,
          lastMessagePreview: friend.lastMessagePreview,
          unreadCount: friend.unreadCount,
          searchText: friend.searchText,
          lastMessageAt: friend.lastMessageAt,
        ),
      for (final group in groupsList)
        Conversation(
          type: ConversationType.group,
          id: group.id,
          name: group.name,
          avatar: group.avatar,
          subtitle: group.subtitle,
          statusSubtitle: group.statusSubtitle,
          lastMessagePreview: group.lastMessagePreview,
          unreadCount: group.unreadCount,
          searchText: group.searchText,
          lastMessageAt: group.lastMessageAt,
        ),
    ];
  }

  Future<List<ChatMessage>> messages(
    Conversation conversation, {
    int afterId = 0,
    int beforeId = 0,
    int limit = 80,
  }) async {
    final route = conversation.type == ConversationType.group
        ? 'message/get_group_msg'
        : 'message/get_private_msg';
    final values = <String, String>{
      if (conversation.type == ConversationType.group)
        'room_id': '${conversation.id}',
      if (conversation.type == ConversationType.private)
        'friend_id': '${conversation.id}',
      if (afterId > 0 && conversation.type == ConversationType.group)
        'after_id': '$afterId',
      if (afterId > 0 && conversation.type == ConversationType.private)
        'last_id': '$afterId',
      if (beforeId > 0) 'before_id': '$beforeId',
      'limit': '$limit',
    };
    final data = await get(route, values);
    final messages = _messageList(data).map(ChatMessage.fromJson).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return messages;
  }

  Future<List<EmojiSticker>> emojis() async {
    final data = await get('emoji/get_list');
    final rows = _firstList(data, const [
      'emojis',
      'emoji',
      'emoji_list',
      'list',
      'data',
    ]);
    final stickers = rows
        .map(EmojiSticker.fromJson)
        .where((emoji) => emoji.abbr.trim().isNotEmpty)
        .toList();
    final seen = <String>{};
    return <EmojiSticker>[
      for (final sticker in stickers)
        if (seen.add(sticker.abbr)) sticker,
    ];
  }

  Future<void> markRead(Conversation conversation, {int lastMsgId = 0}) {
    return postForm('message/mark_read', <String, String>{
      if (conversation.type == ConversationType.group)
        'room_id': '${conversation.id}',
      if (conversation.type == ConversationType.private)
        'friend_id': '${conversation.id}',
      if (lastMsgId > 0) 'last_msg_id': '$lastMsgId',
    });
  }

  Future<void> sendMessage(
    Conversation conversation,
    String content, {
    int replyTo = 0,
    List<int> mentionUids = const <int>[],
  }) {
    final fields = _sendFields(
      content: content,
      replyTo: replyTo,
      mentionUids: mentionUids,
    );
    if (conversation.type == ConversationType.group) {
      fields['room_id'] = '${conversation.id}';
      return postForm('message/send_group_msg', fields);
    }
    fields['friend_id'] = '${conversation.id}';
    return postForm('message/send_private_msg', fields);
  }

  Future<void> sendEmojiMessage(Conversation conversation, EmojiSticker emoji) {
    final abbr = emoji.abbr.trim();
    if (abbr.isEmpty) {
      throw const CsacApiException('Emoji abbr is empty.');
    }
    return postForm('message/send_emoji_msg', <String, String>{
      if (conversation.type == ConversationType.group)
        'room_id': '${conversation.id}',
      if (conversation.type == ConversationType.private)
        'friend_id': '${conversation.id}',
      'abbr': abbr,
    });
  }

  Future<void> sendImageMessage(
    Conversation conversation,
    Uint8List imageBytes,
    String fileName, {
    String caption = '',
    int replyTo = 0,
    List<int> mentionUids = const <int>[],
  }) {
    final fields = _sendFields(
      content: caption,
      replyTo: replyTo,
      mentionUids: mentionUids,
    );
    if (conversation.type == ConversationType.group) {
      fields['room_id'] = '${conversation.id}';
    } else {
      fields['friend_id'] = '${conversation.id}';
    }
    final route = conversation.type == ConversationType.group
        ? 'message/send_group_msg'
        : 'message/send_private_msg';
    return postMultipart(
      route,
      fields,
      fileField: 'img',
      fileBytes: imageBytes,
      fileName: fileName,
    );
  }

  Future<void> sendVoiceMessage(
    Conversation conversation,
    Uint8List voiceBytes,
    String fileName, {
    int duration = 0,
    int replyTo = 0,
  }) {
    final fields = <String, String>{
      if (conversation.type == ConversationType.group)
        'room_id': '${conversation.id}',
      if (conversation.type == ConversationType.private)
        'friend_id': '${conversation.id}',
      'duration': '$duration',
      if (replyTo > 0) 'reply_to': '$replyTo',
    };
    return postMultipart(
      'message/send_voice_msg',
      fields,
      fileField: 'voice',
      fileBytes: voiceBytes,
      fileName: fileName,
    );
  }

  Future<void> sendPatMessage(Conversation conversation, int targetUid) {
    if (conversation.type != ConversationType.group) {
      throw const CsacApiException('Pat is only available in group chats.');
    }
    return postForm('message/send_pat_msg', <String, String>{
      'room_id': '${conversation.id}',
      'target_uid': '$targetUid',
    });
  }

  Future<void> recallMessage(Conversation conversation, int msgId) {
    return postForm('message/recall_msg', <String, String>{
      'msg_id': '$msgId',
      'type': conversation.type == ConversationType.group ? 'group' : 'private',
      if (conversation.type == ConversationType.group)
        'room_id': '${conversation.id}',
    });
  }

  Future<void> toggleEssence(int roomId, int msgId) {
    return postForm('essence/set_essence', <String, String>{
      'room_id': '$roomId',
      'msg_id': '$msgId',
    });
  }

  Future<List<ChatMessage>> essenceMessages(int roomId) async {
    final data = await get('essence/get_essence', <String, String>{
      'room_id': '$roomId',
    });
    return _firstList(data, const [
      'essence_list',
      'messages',
      'list',
      'data',
    ]).map(ChatMessage.fromJson).toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<EssenceStats> essenceStats(int roomId, {String type = 'all'}) async {
    final data = await get('essence/get_essence_stats', <String, String>{
      'room_id': '$roomId',
      'type': type,
    });
    return EssenceStats.fromJson(data, type: type);
  }

  Future<SessionExtensionStatus> activateSessionExtension(String key) async {
    final data = await postForm('utils/session_extend', <String, String>{
      'key': key,
    });
    await saveSession();
    return SessionExtensionStatus.fromJson(data);
  }

  Future<void> resetSessionExtension() async {
    await postForm('utils/session_reset');
    await saveSession();
  }

  Future<SessionExtensionStatus> sessionExtensionStatus() async {
    final data = await get('utils/session_info');
    return SessionExtensionStatus.fromJson(data);
  }

  Future<String> generateAdminToken() async {
    final data = await postForm('admin/generate_token');
    final token = firstString(data, const ['token', 'admin_token']);
    if (token.isEmpty) {
      throw const CsacApiException('Server did not return admin token.');
    }
    return token;
  }

  Future<void> banUser(
    int uid, {
    int days = 3650,
    String reason = 'Managed from CsAC client',
  }) async {
    final token = await generateAdminToken();
    await postForm('admin/admin_ban', <String, String>{
      'token': token,
      'action': 'ban_user',
      'user_id': '$uid',
      'ban_days': '$days',
      'ban_reason': reason,
    });
  }

  Future<void> unbanUser(int uid) async {
    final token = await generateAdminToken();
    await postForm('admin/admin_ban', <String, String>{
      'token': token,
      'action': 'unban_user',
      'user_id': '$uid',
    });
  }

  Future<void> banRoom(
    int roomId, {
    int days = 3650,
    String reason = 'Managed from CsAC client',
  }) async {
    final token = await generateAdminToken();
    await postForm('admin/admin_ban', <String, String>{
      'token': token,
      'action': 'ban_room',
      'room_id': '$roomId',
      'ban_days': '$days',
      'ban_reason': reason,
    });
  }

  Future<void> unbanRoom(int roomId) async {
    final token = await generateAdminToken();
    await postForm('admin/admin_ban', <String, String>{
      'token': token,
      'action': 'unban_room',
      'room_id': '$roomId',
    });
  }

  Future<Map<String, dynamic>> get(
    String route, [
    Map<String, String>? values,
  ]) {
    final uri = _routeUri(route, values);
    return _send(() => http.Request('GET', uri));
  }

  Future<Uint8List> getBinary(String url, {String accept = '*/*'}) async {
    final uri = Uri.parse(url);
    http.Response response = await _sendOnce(_binaryRequest(uri, accept));
    for (var attempt = 0; _looksLikeHtml(response); attempt++) {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (!_isChallenge(body)) {
        break;
      }
      if (attempt >= 3) {
        throw CsacApiException(
          'Server returned JavaScript challenge while downloading media.',
        );
      }
      final retryUri = _solveChallenge(response.request?.url ?? uri, body);
      response = await _sendOnce(_binaryRequest(retryUri, accept));
    }
    if (response.statusCode == 401) {
      throw const CsacAuthException('Not logged in.');
    }
    if (response.statusCode == 403) {
      throw const CsacApiException('Access forbidden.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CsacApiException('HTTP ${response.statusCode}');
    }
    if (_looksLikeHtml(response)) {
      throw const CsacApiException(
        'Media download returned HTML instead of a file.',
      );
    }
    return response.bodyBytes;
  }

  Future<NetworkDiagnosticCheck> _diagnosticCheck(
    String name,
    Future<String> Function() run,
  ) async {
    final timer = Stopwatch()..start();
    try {
      final detail = await run();
      timer.stop();
      return NetworkDiagnosticCheck(
        name: name,
        ok: true,
        elapsedMs: timer.elapsedMilliseconds,
        detail: detail,
      );
    } catch (err) {
      timer.stop();
      return NetworkDiagnosticCheck(
        name: name,
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: err.toString(),
      );
    }
  }

  http.Request _binaryRequest(Uri uri, String accept) {
    final request = http.Request('GET', uri);
    request.headers['Accept'] = accept;
    return request;
  }

  Future<Map<String, dynamic>> postForm(
    String route, [
    Map<String, String>? values,
  ]) {
    final uri = _routeUri(route);
    return _send(() {
      final request = http.Request('POST', uri);
      request.bodyFields = values ?? <String, String>{};
      return request;
    });
  }

  Future<ApiDebugResponse> runDebugRequest({
    required String method,
    required String route,
    required Map<String, String> values,
  }) async {
    final normalizedMethod = method.toUpperCase() == 'POST' ? 'POST' : 'GET';
    final cleanRoute = route.trim();
    final cleanValues = <String, String>{
      for (final entry in values.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    };
    final timer = Stopwatch()..start();
    http.Response response = await _sendDebugOnce(
      normalizedMethod,
      cleanRoute,
      cleanValues,
    );
    var body = response.body;
    for (var attempt = 0; _isChallenge(body); attempt++) {
      if (attempt >= 3) {
        throw CsacApiException(
          'Server returned JavaScript challenge again after setting __test cookie.',
        );
      }
      final retryUri = _solveChallenge(
        response.request?.url ?? Uri.parse(baseUrl),
        body,
      );
      response = await _sendOnce(
        _debugRequest(
          normalizedMethod,
          retryUri,
          normalizedMethod == 'POST' ? cleanValues : null,
        ),
      );
      body = response.body;
    }
    timer.stop();
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {}
    return ApiDebugResponse(
      method: normalizedMethod,
      route: cleanRoute,
      statusCode: response.statusCode,
      elapsedMs: timer.elapsedMilliseconds,
      body: body,
      decoded: decoded,
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String route,
    Map<String, String> fields, {
    required String fileField,
    required Uint8List fileBytes,
    required String fileName,
  }) {
    final uri = _routeUri(route);
    return _send(() {
      final request = http.MultipartRequest('POST', uri);
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName),
      );
      return request;
    });
  }

  Map<String, String> _sendFields({
    required String content,
    required int replyTo,
    required List<int> mentionUids,
  }) {
    final fields = <String, String>{};
    if (content.trim().isNotEmpty) {
      fields['content'] = content;
    }
    if (replyTo > 0) {
      fields['reply_to'] = '$replyTo';
    }
    final mentions = mentionUids.where((uid) => uid > 0).toSet().toList();
    if (mentions.isNotEmpty) {
      fields['mention_uids'] = mentions.join(',');
    }
    return fields;
  }

  Future<Map<String, dynamic>> _send(
    http.BaseRequest Function() buildRequest,
  ) async {
    http.Response response = await _sendOnce(buildRequest());
    var body = response.body;
    for (var attempt = 0; _isChallenge(body); attempt++) {
      if (attempt >= 3) {
        throw CsacApiException(
          'Server returned JavaScript challenge again after setting __test cookie.',
        );
      }
      final retryUri = _solveChallenge(
        response.request?.url ?? Uri.parse(baseUrl),
        body,
      );
      final retry = buildRequest();
      retry.url.replace(
        scheme: retryUri.scheme,
        host: retryUri.host,
        path: retryUri.path,
        query: retryUri.query,
      );
      response = await _sendOnce(_cloneWithUrl(retry, retryUri));
      body = response.body;
    }

    final decoded = _decodeMap(body);
    if (response.statusCode == 401) {
      throw CsacAuthException(_message(decoded, 'Not logged in.'));
    }
    if (response.statusCode == 403) {
      throw CsacApiException(_message(decoded, 'Access forbidden.'));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CsacApiException(
        'HTTP ${response.statusCode}: ${_message(decoded, body)}',
      );
    }
    if (decoded['success'] != true) {
      throw CsacApiException(_message(decoded, 'Request failed.'));
    }
    return decoded;
  }

  http.BaseRequest _cloneWithUrl(http.BaseRequest original, Uri uri) {
    if (original is http.MultipartRequest) {
      final request = http.MultipartRequest(original.method, uri);
      request.headers.addAll(original.headers);
      request.fields.addAll(original.fields);
      request.files.addAll(original.files);
      return request;
    }
    original as http.Request;
    final request = http.Request(original.method, uri);
    request.headers.addAll(original.headers);
    request.bodyBytes = original.bodyBytes;
    return request;
  }

  Future<http.Response> _sendOnce(http.BaseRequest request) async {
    _prepareHeaders(request);
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    _storeCookies(response);
    return response;
  }

  Future<http.Response> _sendDebugOnce(
    String method,
    String route,
    Map<String, String> values,
  ) {
    final uri = method == 'POST' ? _routeUri(route) : _routeUri(route, values);
    return _sendOnce(
      _debugRequest(method, uri, method == 'POST' ? values : null),
    );
  }

  http.Request _debugRequest(
    String method,
    Uri uri,
    Map<String, String>? bodyFields,
  ) {
    final request = http.Request(method, uri);
    if (method == 'POST') {
      request.bodyFields = bodyFields ?? <String, String>{};
    }
    return request;
  }

  bool _looksLikeHtml(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().contains('text/html')) {
      return true;
    }
    final text = utf8
        .decode(response.bodyBytes.take(256).toList(), allowMalformed: true)
        .trimLeft()
        .toLowerCase();
    return text.startsWith('<!doctype html') ||
        text.startsWith('<html') ||
        text.startsWith('<script');
  }

  void _prepareHeaders(http.BaseRequest request) {
    request.headers.putIfAbsent(
      'User-Agent',
      () =>
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    );
    request.headers.putIfAbsent(
      'Accept',
      () => 'application/json, text/plain, */*',
    );
    request.headers.putIfAbsent(
      'Accept-Language',
      () => 'zh-CN,zh;q=0.9,en;q=0.8',
    );
    request.headers.putIfAbsent('Referer', () => '$originUrl/');
    if (request.method == 'POST') {
      request.headers.putIfAbsent('Origin', () => originUrl);
    }
    if (_cookies.isNotEmpty) {
      request.headers['Cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
  }

  void _storeCookies(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) {
      return;
    }
    for (final cookie in _splitSetCookie(raw)) {
      final first = cookie.split(';').first.trim();
      final index = first.indexOf('=');
      if (index <= 0) {
        continue;
      }
      _cookies[first.substring(0, index)] = first.substring(index + 1);
    }
  }

  Uri _routeUri(String route, [Map<String, String>? values]) {
    final base = Uri.parse(_baseUrl);
    return base.replace(
      queryParameters: <String, String>{
        ...base.queryParameters,
        'route': route,
        ...?values,
      },
    );
  }

  bool _isChallenge(String body) {
    return body.contains('document.cookie="__test=') &&
        body.contains('/aes.js') &&
        body.contains('slowAES.decrypt');
  }

  Uri _solveChallenge(Uri requestUri, String body) {
    final match = RegExp(
      r'var\s+a=toNumbers\("([0-9a-fA-F]+)"\),b=toNumbers\("([0-9a-fA-F]+)"\),c=toNumbers\("([0-9a-fA-F]+)"\)',
    ).firstMatch(body);
    if (match == null) {
      throw const CsacApiException('Challenge variables were not found.');
    }
    final key = _hexBytes(match.group(1)!);
    final iv = _hexBytes(match.group(2)!);
    final encrypted = _hexBytes(match.group(3)!);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));
    final output = Uint8List(encrypted.length);
    for (
      var offset = 0;
      offset < encrypted.length;
      offset += cipher.blockSize
    ) {
      cipher.processBlock(encrypted, offset, output, offset);
    }
    _cookies['__test'] = _toHex(output);

    final location = RegExp(
      r'location\.href="([^"]+)"',
    ).firstMatch(body)?.group(1);
    final retry = location == null ? requestUri : requestUri.resolve(location);
    final query = Map<String, String>.from(retry.queryParameters);
    query.putIfAbsent('i', () => '1');
    return retry.replace(queryParameters: query);
  }

  Uint8List _hexBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  String _toHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  String _message(Map<String, dynamic> data, String fallback) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return fallback;
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _firstList(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (value is Map) {
        final nested = _firstList(Map<String, dynamic>.from(value), keys);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _firstMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map) {
        final mapped = Map<String, dynamic>.from(value);
        for (final nestedKey in keys) {
          final nested = mapped[nestedKey];
          if (nested is Map) {
            return Map<String, dynamic>.from(nested);
          }
        }
        return mapped;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _messageList(Map<String, dynamic> data) {
    for (final key in const [
      'messages',
      'msg',
      'message_list',
      'list',
      'data',
    ]) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<String> _splitSetCookie(String raw) {
    final parts = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == ',' && i + 1 < raw.length) {
        final rest = raw.substring(i + 1);
        if (RegExp(r'^\s*[^=;,]+=').hasMatch(rest)) {
          parts.add(buffer.toString());
          buffer.clear();
          continue;
        }
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    return parts;
  }
}
