enum ConversationType { private, group }

enum SearchScope { all, private, group, image, essence }

class CsacUser {
  const CsacUser({
    required this.uid,
    required this.nickname,
    this.username = '',
    this.avatar = '',
    this.onlineStatus = '',
  });

  final int uid;
  final String nickname;
  final String username;
  final String avatar;
  final String onlineStatus;

  factory CsacUser.fromJson(Map<String, dynamic> json) {
    return CsacUser(
      uid: asInt(json['uid']),
      nickname: asString(json['nickname']).isEmpty
          ? 'UID ${asInt(json['uid'])}'
          : asString(json['nickname']),
      username: asString(json['username']),
      avatar: normalizeApiUrl(asString(json['avatar'])),
      onlineStatus: asString(json['online_status']),
    );
  }
}

class Friend {
  const Friend({
    required this.id,
    required this.uid,
    required this.name,
    this.subtitle = '',
    this.unreadCount = 0,
    this.searchText = '',
  });

  final int id;
  final int uid;
  final String name;
  final String subtitle;
  final int unreadCount;
  final String searchText;

  factory Friend.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['friend_id']) == 0
        ? asInt(json['uid'])
        : asInt(json['friend_id']);
    final remark = asString(json['remark']);
    final nickname = asString(json['nickname']);
    final last = asString(json['last_message']).isEmpty
        ? asString(json['last_msg'])
        : asString(json['last_message']);
    final online = asString(json['online_status']);
    return Friend(
      id: id,
      uid: asInt(json['uid']),
      name: remark.isEmpty
          ? (nickname.isEmpty ? 'User $id' : nickname)
          : remark,
      subtitle: [
        online,
        last,
      ].where((part) => part.trim().isNotEmpty).join(' | '),
      unreadCount: asInt(json['unread_count']),
      searchText: [
        remark,
        nickname,
        asString(json['username']),
        online,
        last,
      ].where((part) => part.trim().isNotEmpty).join(' | '),
    );
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.unreadCount = 0,
    this.searchText = '',
  });

  final int id;
  final String name;
  final String subtitle;
  final int unreadCount;
  final String searchText;

  factory Group.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['room_id']) == 0
        ? asInt(json['id'])
        : asInt(json['room_id']);
    final roomName = asString(json['room_name']).isEmpty
        ? asString(json['name'])
        : asString(json['room_name']);
    final description = asString(json['description']);
    final notice = asString(json['notice']);
    final members = asInt(json['member_count']);
    final parts = <String>[
      if (members > 0) '$members members',
      if (description.isNotEmpty) description,
      if (notice.isNotEmpty) notice,
    ];
    return Group(
      id: id,
      name: roomName.isEmpty ? 'Room $id' : roomName,
      subtitle: parts.join(' | '),
      unreadCount: asInt(json['unread_count']),
      searchText: [
        roomName,
        description,
        notice,
        asString(json['intro']),
        asString(json['room_intro']),
        asString(json['announcement']),
      ].where((part) => part.trim().isNotEmpty).join(' | '),
    );
  }
}

class Conversation {
  const Conversation({
    required this.type,
    required this.id,
    required this.name,
    this.subtitle = '',
    this.unreadCount = 0,
    this.searchText = '',
  });

  final ConversationType type;
  final int id;
  final String name;
  final String subtitle;
  final int unreadCount;
  final String searchText;

  Conversation copyWith({
    ConversationType? type,
    int? id,
    String? name,
    String? subtitle,
    int? unreadCount,
    String? searchText,
  }) {
    return Conversation(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      unreadCount: unreadCount ?? this.unreadCount,
      searchText: searchText ?? this.searchText,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nickname,
    this.username = '',
    this.avatar = '',
    this.remark = '',
    this.onlineStatus = '',
    this.isFriend = false,
    this.canAddFriend = false,
  });

  final int uid;
  final String nickname;
  final String username;
  final String avatar;
  final String remark;
  final String onlineStatus;
  final bool isFriend;
  final bool canAddFriend;

  String get displayName {
    if (remark.trim().isNotEmpty) {
      return remark.trim();
    }
    if (nickname.trim().isNotEmpty) {
      return nickname.trim();
    }
    return 'UID $uid';
  }

  String get subtitle {
    return [
      if (username.isNotEmpty) '@$username',
      if (onlineStatus.isNotEmpty) onlineStatus,
      if (isFriend) 'friend',
    ].join(' | ');
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final uid = firstInt(json, const ['uid', 'user_id', 'id']);
    return UserProfile(
      uid: uid,
      nickname: firstString(json, const ['nickname', 'name']),
      username: asString(json['username']),
      avatar: normalizeApiUrl(asString(json['avatar'])),
      remark: asString(json['remark']),
      onlineStatus: asString(json['online_status']),
      isFriend: asBool(json['is_friend']),
      canAddFriend: asBool(json['can_add_friend']),
    );
  }
}

class GroupProfile {
  const GroupProfile({
    required this.id,
    required this.name,
    this.description = '',
    this.notice = '',
    this.inviteCode = '',
    this.code = '',
    this.question = '',
    this.answer = '',
    this.joinType = '',
    this.showPublic = false,
    this.memberCount = 0,
    this.isInGroup = false,
    this.isAdmin = false,
    this.isOwner = false,
    this.ownerUid = 0,
    this.currentRole = '',
  });

  final int id;
  final String name;
  final String description;
  final String notice;
  final String inviteCode;
  final String code;
  final String question;
  final String answer;
  final String joinType;
  final bool showPublic;
  final int memberCount;
  final bool isInGroup;
  final bool isAdmin;
  final bool isOwner;
  final int ownerUid;
  final String currentRole;

  bool get hasOwnerRole => isOwner || roleTextIndicatesOwner(currentRole);

  bool get hasAdminRole =>
      hasOwnerRole || isAdmin || roleTextIndicatesAdmin(currentRole);

  String get subtitle {
    return [
      if (memberCount > 0) '$memberCount members',
      if (joinType.isNotEmpty) 'join: $joinType',
      if (hasOwnerRole) 'owner' else if (hasAdminRole) 'admin',
    ].join(' | ');
  }

  factory GroupProfile.fromJson(Map<String, dynamic> json) {
    final id = firstInt(json, const ['room_id', 'id', 'rid']);
    final name = firstString(json, const ['room_name', 'name']);
    return GroupProfile(
      id: id,
      name: name.isEmpty ? 'Room $id' : name,
      description: firstString(json, const [
        'description',
        'intro',
        'room_intro',
      ]),
      notice: firstString(json, const ['notice', 'announcement']),
      inviteCode: asString(json['invite_code']),
      code: firstString(json, const ['code', 'fixed_code', 'join_code']),
      question: firstString(json, const [
        'question',
        'apply_question',
        'audit_question',
      ]),
      answer: firstString(json, const ['answer', 'apply_answer']),
      joinType: firstString(json, const [
        'join_type',
        'join_mode',
        'join_method',
      ]),
      showPublic: firstBool(json, const ['show_public', 'is_public']),
      memberCount: asInt(json['member_count']),
      isInGroup: asBool(json['is_in_group']),
      isAdmin: firstBool(json, const [
        'is_admin',
        'is_manager',
        'is_manage',
        'is_group_admin',
        'can_manage',
      ]),
      isOwner: firstBool(json, const [
        'is_owner',
        'is_creator',
        'is_room_owner',
        'is_group_owner',
        'owner',
      ]),
      ownerUid: firstInt(json, const [
        'owner_uid',
        'owner_id',
        'creator_uid',
        'creator_id',
        'create_uid',
      ]),
      currentRole: firstString(json, const [
        'my_role',
        'current_role',
        'member_role',
        'role',
        'role_name',
        'role_label',
      ]),
    );
  }
}

class CommonGroup {
  const CommonGroup({required this.id, required this.name, this.subtitle = ''});

  final int id;
  final String name;
  final String subtitle;

  factory CommonGroup.fromJson(Map<String, dynamic> json) {
    final id = firstInt(json, const ['room_id', 'id', 'rid']);
    final name = firstString(json, const ['room_name', 'name']);
    return CommonGroup(
      id: id,
      name: name.isEmpty ? 'Room $id' : name,
      subtitle: [
        asString(json['description']),
        asString(json['notice']),
      ].where((part) => part.trim().isNotEmpty).join(' | '),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.body,
    this.time = '',
    this.imageUrl = '',
    this.canRecall = false,
    this.isRecalled = false,
    this.isEssence = false,
    this.isMentioned = false,
    this.replyTo = 0,
  });

  final int id;
  final int senderId;
  final String sender;
  final String body;
  final String time;
  final String imageUrl;
  final bool canRecall;
  final bool isRecalled;
  final bool isEssence;
  final bool isMentioned;
  final int replyTo;

  ChatMessage copyWith({
    int? id,
    int? senderId,
    String? sender,
    String? body,
    String? time,
    String? imageUrl,
    bool? canRecall,
    bool? isRecalled,
    bool? isEssence,
    bool? isMentioned,
    int? replyTo,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      time: time ?? this.time,
      imageUrl: imageUrl ?? this.imageUrl,
      canRecall: canRecall ?? this.canRecall,
      isRecalled: isRecalled ?? this.isRecalled,
      isEssence: isEssence ?? this.isEssence,
      isMentioned: isMentioned ?? this.isMentioned,
      replyTo: replyTo ?? this.replyTo,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['msg_id']) == 0
        ? asInt(json['id'])
        : asInt(json['msg_id']);
    final senderId = firstInt(json, const ['from_uid', 'uid', 'user_id']);
    final isRecalled =
        asBool(json['is_recalled']) ||
        asBool(json['recalled']) ||
        asBool(json['is_revoked']);
    final rawImage = firstString(json, const ['image_url', 'image', 'img']);
    final rawContent = asString(json['content']).trim();
    final contentLooksLikeImage = looksLikeImagePath(rawContent);
    final image = isRecalled
        ? ''
        : normalizeApiUrl(
            contentLooksLikeImage && rawImage.isEmpty ? rawContent : rawImage,
          );
    var body = asString(json['content']).trim();
    if (isRecalled) {
      body = '[recalled]';
    } else {
      if (image.isNotEmpty && contentLooksLikeImage) {
        body = '';
      }
      if (body.isEmpty && image.isNotEmpty) {
        body = '[image]';
      }
      if (body.isEmpty) {
        body = '[empty]';
      }
    }
    return ChatMessage(
      id: id,
      senderId: senderId,
      sender: firstString(json, const ['nickname', 'sender_name']).isEmpty
          ? 'UID $senderId'
          : firstString(json, const ['nickname', 'sender_name']),
      body: body,
      time: humanReadableTimestamp(
        firstString(json, const [
          'add_time',
          'created_at',
          'create_time',
          'time',
        ]),
      ),
      imageUrl: image,
      canRecall: asBool(json['can_recall']),
      isRecalled: isRecalled,
      isEssence: asBool(json['is_essence']),
      isMentioned: asBool(json['is_mentioned']),
      replyTo: firstInt(json, const ['reply_to', 'reply_msg_id']),
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.uid,
    required this.name,
    this.username = '',
    this.avatar = '',
    this.role = '',
    this.onlineStatus = '',
    this.isOwner = false,
    this.isAdmin = false,
  });

  final int uid;
  final String name;
  final String username;
  final String avatar;
  final String role;
  final String onlineStatus;
  final bool isOwner;
  final bool isAdmin;

  String get subtitle {
    return [
      if (username.isNotEmpty) '@$username',
      if (roleLabel.isNotEmpty) roleLabel,
      if (onlineStatus.isNotEmpty) onlineStatus,
    ].join(' | ');
  }

  String get roleLabel {
    if (isOwner) {
      return 'owner';
    }
    if (isAdmin) {
      return 'admin';
    }
    return role;
  }

  bool get hasOwnerRole => isOwner || roleTextIndicatesOwner(roleLabel);

  bool get hasAdminRole {
    return hasOwnerRole || isAdmin || roleTextIndicatesAdmin(roleLabel);
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final uid = firstInt(json, const ['uid', 'user_id', 'id']);
    final remark = asString(json['remark']);
    final nickname = asString(json['nickname']);
    final username = asString(json['username']);
    return GroupMember(
      uid: uid,
      name: [remark, nickname, username].firstWhere(
        (value) => value.trim().isNotEmpty,
        orElse: () => 'UID $uid',
      ),
      username: username,
      avatar: normalizeApiUrl(asString(json['avatar'])),
      role: firstString(json, const [
        'role',
        'role_name',
        'role_label',
        'member_role',
        'identity',
      ]),
      onlineStatus: asString(json['online_status']),
      isOwner: firstBool(json, const [
        'is_owner',
        'is_creator',
        'is_room_owner',
        'is_group_owner',
        'owner',
      ]),
      isAdmin: firstBool(json, const [
        'is_admin',
        'is_manager',
        'is_manage',
        'is_group_admin',
        'admin',
      ]),
    );
  }
}

class MessageSearchResult {
  const MessageSearchResult({
    required this.conversation,
    required this.message,
    required this.snippet,
  });

  final Conversation conversation;
  final ChatMessage message;
  final String snippet;
}

class NotificationCounts {
  const NotificationCounts({
    this.notices = 0,
    this.friendRequests = 0,
    this.groupApplications = 0,
  });

  final int notices;
  final int friendRequests;
  final int groupApplications;

  int get total => notices + friendRequests + groupApplications;

  factory NotificationCounts.fromJson(Map<String, dynamic> json) {
    return NotificationCounts(
      notices: firstInt(json, const [
        'notice_count',
        'notice_unread',
        'notice_unread_count',
        'unread_notice_count',
        'unread_count',
        'count',
      ]),
      friendRequests: firstInt(json, const [
        'friend_request_count',
        'friend_requests',
        'request_count',
        'friend_count',
      ]),
      groupApplications: firstInt(json, const [
        'group_application_count',
        'group_applications',
        'apply_count',
        'group_apply_count',
      ]),
    );
  }
}

class CsacNotice {
  const CsacNotice({
    required this.id,
    required this.title,
    required this.content,
    this.time = '',
    this.isRead = false,
    this.link = '',
    this.route = '',
  });

  final int id;
  final String title;
  final String content;
  final String time;
  final bool isRead;
  final String link;
  final String route;

  factory CsacNotice.fromJson(Map<String, dynamic> json) {
    final id = firstInt(json, const ['id', 'notice_id']);
    return CsacNotice(
      id: id,
      title: firstString(json, const ['title', 'name']).isEmpty
          ? 'Notice $id'
          : firstString(json, const ['title', 'name']),
      content: firstString(json, const ['content', 'message', 'body']),
      time: firstString(json, const ['add_time', 'create_time', 'time']),
      isRead: asBool(json['is_read']) || asBool(json['read']),
      link: asString(json['link']),
      route: asString(json['route']),
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.nickname,
    this.username = '',
    this.avatar = '',
    this.content = '',
    this.createTime = '',
    this.handleTime = '',
    this.status = 0,
  });

  final int id;
  final int fromUid;
  final int toUid;
  final String nickname;
  final String username;
  final String avatar;
  final String content;
  final String createTime;
  final String handleTime;
  final int status;

  bool get pending => status == 0;

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final id = firstInt(json, const ['id', 'request_id']);
    final fromUid = firstInt(json, const ['from_uid', 'uid', 'user_id']);
    return FriendRequest(
      id: id,
      fromUid: fromUid,
      toUid: asInt(json['to_uid']),
      nickname: firstString(json, const ['nickname', 'from_nickname']).isEmpty
          ? 'UID $fromUid'
          : firstString(json, const ['nickname', 'from_nickname']),
      username: asString(json['username']),
      avatar: normalizeApiUrl(asString(json['avatar'])),
      content: firstString(json, const ['content', 'message', 'reason']),
      createTime: firstString(json, const ['create_time', 'add_time', 'time']),
      handleTime: asString(json['handle_time']),
      status: asInt(json['status']),
    );
  }
}

class GroupApplication {
  const GroupApplication({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.uid,
    required this.nickname,
    this.username = '',
    this.avatar = '',
    this.content = '',
    this.answer = '',
    this.createTime = '',
    this.status = 0,
  });

  final int id;
  final int roomId;
  final String roomName;
  final int uid;
  final String nickname;
  final String username;
  final String avatar;
  final String content;
  final String answer;
  final String createTime;
  final int status;

  bool get pending => status == 0;

  factory GroupApplication.fromJson(
    Map<String, dynamic> json, {
    int fallbackRoomId = 0,
    String fallbackRoomName = '',
  }) {
    final id = firstInt(json, const ['apply_id', 'application_id', 'id']);
    final roomId = firstInt(json, const ['room_id', 'rid', 'group_id']);
    final uid = firstInt(json, const ['uid', 'from_uid', 'user_id']);
    return GroupApplication(
      id: id,
      roomId: roomId == 0 ? fallbackRoomId : roomId,
      roomName: firstString(json, const [
        'room_name',
        'group_name',
        'name',
      ]).ifEmpty(fallbackRoomName),
      uid: uid,
      nickname: firstString(json, const [
        'nickname',
        'username',
        'name',
      ]).ifEmpty('UID $uid'),
      username: asString(json['username']),
      avatar: normalizeApiUrl(asString(json['avatar'])),
      content: firstString(json, const ['content', 'message', 'reason']),
      answer: firstString(json, const ['answer', 'apply_answer']),
      createTime: firstString(json, const ['create_time', 'add_time', 'time']),
      status: asInt(json['status']),
    );
  }
}

int asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(asString(value)) ?? 0;
}

String asString(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num && value == 0) {
    return '';
  }
  return value.toString();
}

bool asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = asString(value).trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}

bool roleTextIndicatesOwner(String value) {
  final text = value.trim().toLowerCase();
  return text == 'owner' ||
      text == 'creator' ||
      text == 'host' ||
      text == 'room_owner' ||
      text == 'group_owner' ||
      text == '群主' ||
      text == '创建者' ||
      text.contains('owner') ||
      text.contains('群主');
}

bool roleTextIndicatesAdmin(String value) {
  final text = value.trim().toLowerCase();
  return roleTextIndicatesOwner(value) ||
      text == 'admin' ||
      text == 'administrator' ||
      text == 'manager' ||
      text == 'moderator' ||
      text == 'group_admin' ||
      text == '管理员' ||
      text == '管理' ||
      text.contains('admin') ||
      text.contains('管理员');
}

bool firstBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = asString(value).trim().toLowerCase();
    if (text == '1' || text == 'true' || text == 'yes' || text == 'on') {
      return true;
    }
    if (text == '0' || text == 'false' || text == 'no' || text == 'off') {
      return false;
    }
  }
  return false;
}

int firstInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = asInt(json[key]);
    if (value != 0) {
      return value;
    }
  }
  return 0;
}

String firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = asString(json[key]).trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _apiAssetBaseUrl = 'https://cschat.ccccocccc.cc';

void configureApiAssetBaseUrl(String apiBaseUrl) {
  _apiAssetBaseUrl = apiOriginFromBaseUrl(apiBaseUrl);
}

String apiOriginFromBaseUrl(String apiBaseUrl) {
  final uri = Uri.tryParse(apiBaseUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'https://cschat.ccccocccc.cc';
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}

String normalizeApiUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty ||
      value.startsWith('http://') ||
      value.startsWith('https://')) {
    return value;
  }
  return '$_apiAssetBaseUrl/${value.replaceFirst(RegExp(r'^/+'), '')}';
}

bool looksLikeImagePath(String value) {
  final text = value.trim();
  if (text.isEmpty || text.contains('\n')) {
    return false;
  }
  final uri = Uri.tryParse(text);
  final path = uri?.path.isNotEmpty == true ? uri!.path : text;
  final lower = path.toLowerCase().split('?').first.split('#').first;
  final hasImageExtension = RegExp(
    r'\.(jpg|jpeg|png|gif|webp|bmp)$',
  ).hasMatch(lower);
  if (!hasImageExtension) {
    return false;
  }
  return lower.startsWith('upload/') ||
      lower.startsWith('/upload/') ||
      uri?.hasScheme == true;
}

String humanReadableTimestamp(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  final parsed = parseFlexibleTimestamp(value);
  if (parsed == null) {
    return value;
  }
  final local = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (!diff.isNegative && diff.inSeconds < 60) {
    return '刚刚';
  }
  if (!diff.isNegative && diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final yesterday = now.subtract(const Duration(days: 1));
  final wasYesterday =
      local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day;
  final clock = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  if (sameDay) {
    return clock;
  }
  if (wasYesterday) {
    return '昨天 $clock';
  }
  if (local.year == now.year) {
    return '${_twoDigits(local.month)}-${_twoDigits(local.day)} $clock';
  }
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} $clock';
}

DateTime? parseFlexibleTimestamp(String raw) {
  final value = raw.trim();
  final numeric = int.tryParse(value);
  if (numeric != null) {
    if (numeric <= 0) {
      return null;
    }
    final milliseconds = numeric > 100000000000
        ? numeric
        : numeric > 10000000000
        ? numeric ~/ 1000
        : numeric * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  final normalized = value.contains('T') ? value : value.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

List<ChatMessage> mergeChatMessages(
  List<ChatMessage> existing,
  Iterable<ChatMessage> incoming,
) {
  final byId = <int, ChatMessage>{
    for (final message in existing) message.id: message,
  };
  for (final message in incoming) {
    byId[message.id] = message;
  }
  final merged = byId.values.toList();
  merged.sort((a, b) => a.id.compareTo(b.id));
  return merged;
}

extension StringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
