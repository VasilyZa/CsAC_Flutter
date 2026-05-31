enum ConversationType { private, group }

enum SearchScope { all, private, group, image, essence }

enum ConversationMediaKind { all, image, voice, file }

enum CsacTimestampPattern { slash, dash, compact, timeOnly }

const defaultPatAction = '\u62cd\u4e86\u62cd';

class CsacUser {
  const CsacUser({
    required this.uid,
    required this.nickname,
    this.username = '',
    this.avatar = '',
    this.onlineStatus = '',
    this.patAction = defaultPatAction,
  });

  final int uid;
  final String nickname;
  final String username;
  final String avatar;
  final String onlineStatus;
  final String patAction;

  factory CsacUser.fromJson(Map<String, dynamic> json) {
    return CsacUser(
      uid: asInt(json['uid']),
      nickname: asString(json['nickname']).isEmpty
          ? 'UID ${asInt(json['uid'])}'
          : asString(json['nickname']),
      username: asString(json['username']),
      avatar: normalizeApiUrl(asString(json['avatar'])),
      onlineStatus: asString(json['online_status']),
      patAction: firstString(json, const ['pat_action', 'patAction']).isEmpty
          ? defaultPatAction
          : firstString(json, const ['pat_action', 'patAction']),
    );
  }
}

class Friend {
  const Friend({
    required this.id,
    required this.uid,
    required this.name,
    this.avatar = '',
    this.subtitle = '',
    this.unreadCount = 0,
    this.searchText = '',
  });

  final int id;
  final int uid;
  final String name;
  final String avatar;
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
    final lastTime = firstReadableTime(json, const [
      'last_time',
      'last_msg_time',
      'last_message_time',
      'updated_at',
    ]);
    final online = asString(json['online_status']);
    return Friend(
      id: id,
      uid: asInt(json['uid']),
      name: remark.isEmpty
          ? (nickname.isEmpty ? 'User $id' : nickname)
          : remark,
      avatar: normalizeApiUrl(asString(json['avatar'])),
      subtitle: [
        online,
        last,
        lastTime,
      ].where((part) => part.trim().isNotEmpty).join(' | '),
      unreadCount: asInt(json['unread_count']),
      searchText: [
        remark,
        nickname,
        asString(json['username']),
        online,
        last,
        lastTime,
      ].where((part) => part.trim().isNotEmpty).join(' | '),
    );
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    this.avatar = '',
    this.subtitle = '',
    this.unreadCount = 0,
    this.searchText = '',
  });

  final int id;
  final String name;
  final String avatar;
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
    final lastTime = firstReadableTime(json, const [
      'last_time',
      'last_msg_time',
      'last_message_time',
      'updated_at',
    ]);
    final parts = <String>[
      if (members > 0) '$members members',
      if (lastTime.isNotEmpty) lastTime,
      if (description.isNotEmpty) description,
      if (notice.isNotEmpty) notice,
    ];
    return Group(
      id: id,
      name: roomName.isEmpty ? 'Room $id' : roomName,
      avatar: normalizeApiUrl(
        firstString(json, const [
          'avatar',
          'room_avatar',
          'group_avatar',
          'icon',
          'image',
        ]),
      ),
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
    this.avatar = '',
    this.subtitle = '',
    this.unreadCount = 0,
    this.searchText = '',
    this.lastMessageAt = 0,
    this.displayOrder = 0,
  });

  final ConversationType type;
  final int id;
  final String name;
  final String avatar;
  final String subtitle;
  final int unreadCount;
  final String searchText;
  final int lastMessageAt;
  final int displayOrder;

  Conversation copyWith({
    ConversationType? type,
    int? id,
    String? name,
    String? avatar,
    String? subtitle,
    int? unreadCount,
    String? searchText,
    int? lastMessageAt,
    int? displayOrder,
  }) {
    return Conversation(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      subtitle: subtitle ?? this.subtitle,
      unreadCount: unreadCount ?? this.unreadCount,
      searchText: searchText ?? this.searchText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  int get latestSortValue => lastMessageAt > 0 ? lastMessageAt : -displayOrder;
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
    this.avatar = '',
    this.description = '',
    this.notice = '',
    this.inviteCode = '',
    this.code = '',
    this.question = '',
    this.answer = '',
    this.joinType = '',
    this.showPublic = false,
    this.allowInvite = true,
    this.memberCount = 0,
    this.isInGroup = false,
    this.isAdmin = false,
    this.isOwner = false,
    this.ownerUid = 0,
    this.currentRole = '',
  });

  final int id;
  final String name;
  final String avatar;
  final String description;
  final String notice;
  final String inviteCode;
  final String code;
  final String question;
  final String answer;
  final String joinType;
  final bool showPublic;
  final bool allowInvite;
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
      avatar: normalizeApiUrl(
        firstString(json, const [
          'avatar',
          'room_avatar',
          'group_avatar',
          'icon',
          'image',
        ]),
      ),
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
        'ask_question',
        'apply_question',
        'audit_question',
      ]),
      answer: firstString(json, const ['answer', 'ask_answer', 'apply_answer']),
      joinType: firstString(json, const [
        'join_type',
        'join_mode',
        'join_method',
      ]),
      showPublic: firstBool(json, const [
        'show_public',
        'is_public',
        'show_in_list',
      ]),
      allowInvite: json.containsKey('allow_invite')
          ? firstBool(json, const ['allow_invite'])
          : true,
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

class EmojiSticker {
  const EmojiSticker({
    required this.fullName,
    required this.address,
    required this.abbr,
  });

  final String fullName;
  final String address;
  final String abbr;

  factory EmojiSticker.fromJson(Map<String, dynamic> json) {
    final abbr = firstString(json, const [
      'abbr',
      'emoji_abbr',
      'code',
      'name',
      'id',
    ]);
    final fullName = firstString(json, const [
      'full_name',
      'fullName',
      'display_name',
      'title',
      'name',
    ]);
    return EmojiSticker(
      fullName: fullName.isEmpty ? abbr : fullName,
      address: normalizeApiUrl(
        firstString(json, const [
          'address',
          'emoji_address',
          'emojiAddress',
          'url',
          'image_url',
          'preview',
        ]),
      ),
      abbr: abbr,
    );
  }

  Map<String, String> toJson() {
    return <String, String>{
      'full_name': fullName,
      'address': address,
      'abbr': abbr,
    };
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.body,
    this.senderAvatar = '',
    this.messageType = 1,
    this.isRead = false,
    this.memberLevel = 0,
    this.memberTitle = '',
    this.time = '',
    this.timeSortValue = 0,
    this.imageUrl = '',
    this.voiceUrl = '',
    this.voiceDuration = 0,
    this.fileUrl = '',
    this.fileName = '',
    this.emojiAddress = '',
    this.emojiAbbr = '',
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
  final String senderAvatar;
  final int messageType;
  final bool isRead;
  final int memberLevel;
  final String memberTitle;
  final String time;
  final int timeSortValue;
  final String imageUrl;
  final String voiceUrl;
  final int voiceDuration;
  final String fileUrl;
  final String fileName;
  final String emojiAddress;
  final String emojiAbbr;
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
    String? senderAvatar,
    int? messageType,
    bool? isRead,
    int? memberLevel,
    String? memberTitle,
    String? time,
    int? timeSortValue,
    String? imageUrl,
    String? voiceUrl,
    int? voiceDuration,
    String? fileUrl,
    String? fileName,
    String? emojiAddress,
    String? emojiAbbr,
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
      senderAvatar: senderAvatar ?? this.senderAvatar,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      memberLevel: memberLevel ?? this.memberLevel,
      memberTitle: memberTitle ?? this.memberTitle,
      time: time ?? this.time,
      timeSortValue: timeSortValue ?? this.timeSortValue,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      emojiAddress: emojiAddress ?? this.emojiAddress,
      emojiAbbr: emojiAbbr ?? this.emojiAbbr,
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
    final messageType = firstInt(json, const ['msg_type', 'message_type']);
    final normalizedMessageType = messageType <= 0 ? 1 : messageType;
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
    final voice = isRecalled
        ? ''
        : normalizeApiUrl(firstString(json, const ['voice_url', 'voice']));
    final file = isRecalled
        ? ''
        : normalizeApiUrl(
            firstString(json, const [
              'file_url',
              'file',
              'file_path',
              'attachment_url',
              'document_url',
              'download_url',
            ]),
          );
    final fileName = firstString(json, const [
      'file_name',
      'filename',
      'attachment_name',
      'document_name',
    ]);
    final emojiAbbr = normalizedMessageType == 5
        ? firstString(json, const [
            'abbr',
            'emoji_abbr',
            'emojiAbbr',
            'content',
          ])
        : '';
    final emojiAddress = isRecalled || normalizedMessageType != 5
        ? ''
        : normalizeApiUrl(
            firstString(json, const [
              'emoji_address',
              'emojiAddress',
              'address',
              'emoji_url',
              'emoji',
              'image_url',
              'url',
            ]),
          );
    final duration = firstInt(json, const [
      'duration',
      'voice_duration',
      'voice_seconds',
    ]);
    var body = asString(json['content']).trim();
    if (isRecalled) {
      body = body.isEmpty ? '[recalled]' : body;
    } else {
      if (image.isNotEmpty && contentLooksLikeImage) {
        body = '';
      }
      if (body.isEmpty && image.isNotEmpty) {
        body = '[image]';
      }
      if (body.isEmpty && voice.isNotEmpty) {
        body = '[voice]';
      }
      if (body.isEmpty && file.isNotEmpty) {
        body = '[file]';
      }
      if (normalizedMessageType == 5) {
        body = '[emoji]';
      }
      if (body.isEmpty) {
        body = '[empty]';
      }
    }
    final rawTime = firstTimestampValue(json, const [
      'add_time',
      'created_at',
      'create_time',
      'time',
    ]);
    return ChatMessage(
      id: id,
      senderId: senderId,
      sender: firstString(json, const ['nickname', 'sender_name']).isEmpty
          ? 'UID $senderId'
          : firstString(json, const ['nickname', 'sender_name']),
      body: body,
      senderAvatar: normalizeApiUrl(
        firstString(json, const [
          'avatar',
          'sender_avatar',
          'user_avatar',
          'from_avatar',
        ]),
      ),
      messageType: normalizedMessageType,
      isRead:
          firstBool(json, const [
            'is_read',
            'read',
            'read_status',
            'has_read',
            'isRead',
          ]) ||
          firstTimestampValue(json, const ['read_at', 'read_time']) != null,
      memberLevel: firstInt(json, const ['member_level', 'level']),
      memberTitle: firstString(json, const ['member_title', 'title']),
      time: readableTimestamp(rawTime),
      timeSortValue: timestampForSort(rawTime),
      imageUrl: image,
      voiceUrl: voice,
      voiceDuration: duration,
      fileUrl: file,
      fileName: fileName,
      emojiAddress: emojiAddress,
      emojiAbbr: emojiAbbr,
      canRecall: asBool(json['can_recall']),
      isRecalled: isRecalled,
      isEssence: asBool(json['is_essence']),
      isMentioned: asBool(json['is_mentioned']),
      replyTo: firstInt(json, const ['reply_to', 'reply_msg_id']),
    );
  }
}

class EssenceStats {
  const EssenceStats({
    required this.type,
    required this.total,
    required this.categories,
    required this.contributors,
    this.remote = true,
  });

  final String type;
  final int total;
  final List<EssenceCategoryCount> categories;
  final List<EssenceContributor> contributors;
  final bool remote;

  factory EssenceStats.fromJson(
    Map<String, dynamic> json, {
    String type = 'all',
  }) {
    final root =
        firstMap(json, const ['stats', 'stat', 'data', 'result']) ?? json;
    final categories = _parseEssenceCategories(root);
    final contributors = _parseEssenceContributors(root);
    final categoryTotal = categories.fold<int>(
      0,
      (sum, category) => sum + category.count,
    );
    final total = firstInt(root, const [
      'total',
      'total_count',
      'count',
      'essence_count',
      'all_count',
    ]);
    return EssenceStats(
      type: firstString(root, const ['type', 'range']).ifEmpty(type),
      total: total > 0 ? total : categoryTotal,
      categories: categories,
      contributors: contributors,
    );
  }

  factory EssenceStats.fromMessages(
    Iterable<ChatMessage> messages, {
    String type = 'local',
  }) {
    final categoryCounts = <String, int>{};
    final contributorCounts = <int, _EssenceContributorAccumulator>{};
    var total = 0;
    for (final message in messages) {
      total++;
      final category = essenceCategoryForMessage(message);
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      final key = message.senderId;
      final existing = contributorCounts[key];
      if (existing == null) {
        contributorCounts[key] = _EssenceContributorAccumulator(
          uid: message.senderId,
          name: message.sender,
          count: 1,
        );
      } else {
        contributorCounts[key] = existing.copyWith(count: existing.count + 1);
      }
    }
    return EssenceStats(
      type: type,
      total: total,
      categories: _sortedEssenceCategories(categoryCounts),
      contributors:
          contributorCounts.values
              .map(
                (item) => EssenceContributor(
                  uid: item.uid,
                  name: item.name,
                  count: item.count,
                ),
              )
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count)),
      remote: false,
    );
  }
}

class EssenceCategoryCount {
  const EssenceCategoryCount({required this.category, required this.count});

  final String category;
  final int count;
}

class EssenceContributor {
  const EssenceContributor({
    required this.uid,
    required this.name,
    required this.count,
    this.avatar = '',
  });

  final int uid;
  final String name;
  final int count;
  final String avatar;
}

class _EssenceContributorAccumulator {
  const _EssenceContributorAccumulator({
    required this.uid,
    required this.name,
    required this.count,
  });

  final int uid;
  final String name;
  final int count;

  _EssenceContributorAccumulator copyWith({int? count}) {
    return _EssenceContributorAccumulator(
      uid: uid,
      name: name,
      count: count ?? this.count,
    );
  }
}

String essenceCategoryForMessage(ChatMessage message) {
  if (message.imageUrl.isNotEmpty) {
    return 'image';
  }
  if (message.voiceUrl.isNotEmpty) {
    return 'voice';
  }
  if (message.fileUrl.isNotEmpty) {
    return 'file';
  }
  if (message.emojiAddress.isNotEmpty || message.messageType == 5) {
    return 'emoji';
  }
  return 'text';
}

List<EssenceCategoryCount> _parseEssenceCategories(Map<String, dynamic> root) {
  final counts = <String, int>{};
  final rawMap = firstMap(root, const [
    'category_counts',
    'category_count',
    'categories',
    'type_counts',
    'type_count',
    'counts',
    'by_type',
  ]);
  if (rawMap != null) {
    for (final entry in rawMap.entries) {
      final category = _normalizeEssenceCategory(entry.key);
      final value = entry.value is Map
          ? firstInt(Map<String, dynamic>.from(entry.value as Map), const [
              'count',
              'total',
              'num',
              'value',
            ])
          : asInt(entry.value);
      if (value > 0) {
        counts[category] = (counts[category] ?? 0) + value;
      }
    }
  }
  for (final key in const ['categories', 'category_list', 'type_list']) {
    final value = root[key];
    if (value is List) {
      for (final item in value.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final category = _normalizeEssenceCategory(
          firstString(row, const ['category', 'type', 'name', 'label', 'key']),
        );
        final count = firstInt(row, const [
          'count',
          'total',
          'num',
          'value',
          'essence_count',
        ]);
        if (count > 0) {
          counts[category] = (counts[category] ?? 0) + count;
        }
      }
    }
  }
  for (final entry in const <String, List<String>>{
    'text': ['text_count', 'content_count', 'message_count'],
    'image': ['image_count', 'img_count', 'picture_count'],
    'voice': ['voice_count', 'audio_count'],
    'file': ['file_count', 'attachment_count', 'document_count'],
  }.entries) {
    final count = firstInt(root, entry.value);
    if (count > 0) {
      counts[entry.key] = (counts[entry.key] ?? 0) + count;
    }
  }
  return _sortedEssenceCategories(counts);
}

List<EssenceCategoryCount> _sortedEssenceCategories(Map<String, int> counts) {
  const order = ['text', 'image', 'voice', 'file'];
  return [
    for (final key in order)
      if ((counts[key] ?? 0) > 0)
        EssenceCategoryCount(category: key, count: counts[key]!),
    for (final entry in counts.entries)
      if (!order.contains(entry.key) && entry.value > 0)
        EssenceCategoryCount(category: entry.key, count: entry.value),
  ];
}

List<EssenceContributor> _parseEssenceContributors(Map<String, dynamic> root) {
  final rows = <Map<String, dynamic>>[];
  for (final key in const [
    'contributors',
    'contributor_rank',
    'contribution_rank',
    'rank',
    'ranking',
    'rankings',
    'top_users',
    'users',
  ]) {
    final value = root[key];
    if (value is List) {
      rows.addAll(
        value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
      );
    }
  }
  final contributors = rows
      .map((row) {
        final uid = firstInt(row, const ['uid', 'user_id', 'from_uid', 'id']);
        final name = firstString(row, const [
          'nickname',
          'name',
          'username',
          'user_name',
        ]).ifEmpty(uid > 0 ? 'UID $uid' : 'Unknown');
        return EssenceContributor(
          uid: uid,
          name: name,
          avatar: normalizeApiUrl(asString(row['avatar'])),
          count: firstInt(row, const [
            'count',
            'total',
            'num',
            'value',
            'essence_count',
            'contribution',
          ]),
        );
      })
      .where((item) => item.count > 0)
      .toList();
  contributors.sort((a, b) => b.count.compareTo(a.count));
  return contributors;
}

String _normalizeEssenceCategory(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) {
    return 'text';
  }
  if (value.contains('image') ||
      value.contains('img') ||
      value.contains('picture') ||
      value.contains('photo') ||
      value.contains('图片')) {
    return 'image';
  }
  if (value.contains('voice') ||
      value.contains('audio') ||
      value.contains('sound') ||
      value.contains('语音')) {
    return 'voice';
  }
  if (value.contains('file') ||
      value.contains('attachment') ||
      value.contains('document') ||
      value.contains('文件')) {
    return 'file';
  }
  if (value.contains('text') ||
      value.contains('message') ||
      value.contains('content') ||
      value.contains('文本')) {
    return 'text';
  }
  return value;
}

class ConversationMediaItem {
  const ConversationMediaItem({
    required this.conversation,
    required this.message,
    required this.kind,
    required this.url,
    this.title = '',
  });

  final Conversation conversation;
  final ChatMessage message;
  final ConversationMediaKind kind;
  final String url;
  final String title;

  String get displayTitle {
    final value = title.trim();
    if (value.isNotEmpty) {
      return value;
    }
    final name = fileNameFromUrl(url);
    if (name.isNotEmpty) {
      return name;
    }
    switch (kind) {
      case ConversationMediaKind.image:
        return 'Image';
      case ConversationMediaKind.voice:
        return 'Voice message';
      case ConversationMediaKind.file:
        return 'File';
      case ConversationMediaKind.all:
        return 'Media';
    }
  }

  String get searchableText {
    return [
      conversation.name,
      message.sender,
      message.body,
      message.time,
      url,
      title,
      fileNameFromUrl(url),
    ].where((value) => value.trim().isNotEmpty).join(' | ').toLowerCase();
  }
}

class GroupMember {
  const GroupMember({
    required this.uid,
    required this.name,
    this.username = '',
    this.nickname = '',
    this.remark = '',
    this.avatar = '',
    this.role = '',
    this.onlineStatus = '',
    this.memberTitle = '',
    this.memberLevel = 0,
    this.isOwner = false,
    this.isAdmin = false,
  });

  final int uid;
  final String name;
  final String username;
  final String nickname;
  final String remark;
  final String avatar;
  final String role;
  final String onlineStatus;
  final String memberTitle;
  final int memberLevel;
  final bool isOwner;
  final bool isAdmin;

  String get subtitle {
    return [
      if (username.isNotEmpty) '@$username',
      if (memberLevel > 0) 'Lv.$memberLevel',
      if (memberTitle.isNotEmpty) memberTitle,
      if (roleLabel.isNotEmpty) roleLabel,
      if (onlineStatus.isNotEmpty) onlineStatus,
    ].join(' | ');
  }

  String get searchableText {
    return [
      name,
      nickname,
      remark,
      username,
      role,
      roleLabel,
      memberTitle,
      if (memberLevel > 0) 'Lv.$memberLevel',
      if (memberLevel > 0) '$memberLevel',
      onlineStatus,
      '$uid',
      'UID $uid',
    ].where((value) => value.trim().isNotEmpty).join(' | ').toLowerCase();
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
      nickname: nickname,
      remark: remark,
      avatar: normalizeApiUrl(asString(json['avatar'])),
      role: firstString(json, const [
        'role',
        'role_name',
        'role_label',
        'member_role',
        'identity',
      ]),
      onlineStatus: asString(json['online_status']),
      memberTitle: firstString(json, const [
        'title',
        'member_title',
        'group_title',
      ]),
      memberLevel: firstInt(json, const [
        'level',
        'member_level',
        'group_level',
      ]),
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
    this.mentions = 0,
    this.friendChanges = 0,
    this.friendRequests = 0,
    this.groupApplications = 0,
  });

  final int notices;
  final int mentions;
  final int friendChanges;
  final int friendRequests;
  final int groupApplications;

  int get total =>
      notices + mentions + friendChanges + friendRequests + groupApplications;

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
      mentions: firstInt(json, const [
        'mention_count',
        'mentions',
        'mention_unread',
        'mention_unread_count',
        'reply_count',
        'reply_unread',
        'reply_unread_count',
        'at_count',
      ]),
      friendChanges: firstInt(json, const [
        'friend_change_count',
        'friend_changes',
        'deleted_friend_count',
        'deleted_notices',
        'friend_notice_count',
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

class MentionNotice {
  const MentionNotice({
    required this.id,
    required this.conversation,
    required this.message,
    required this.kind,
    this.title = '',
    this.isRead = false,
  });

  final int id;
  final Conversation conversation;
  final ChatMessage message;
  final String kind;
  final String title;
  final bool isRead;

  bool get isReply =>
      kind.toLowerCase().contains('reply') || message.replyTo > 0;

  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    return isReply ? 'Reply to me' : '@ me';
  }

  MentionNotice copyWith({bool? isRead}) {
    return MentionNotice(
      id: id,
      conversation: conversation,
      message: message,
      kind: kind,
      title: title,
      isRead: isRead ?? this.isRead,
    );
  }

  factory MentionNotice.fromJson(
    Map<String, dynamic> json, {
    String fallbackKind = '',
  }) {
    final messageRaw = firstMap(json, const ['message', 'msg', 'chat']);
    final source = messageRaw == null
        ? json
        : <String, dynamic>{...json, ...messageRaw};
    final message = ChatMessage.fromJson(source);
    final conversationType = _noticeConversationType(json);
    final conversationId = conversationType == ConversationType.group
        ? firstInt(source, const ['room_id', 'rid', 'group_id'])
        : firstInt(source, const ['friend_id', 'to_uid', 'from_uid', 'uid']);
    final conversationName = firstString(source, const [
      'room_name',
      'group_name',
      'conversation_name',
      'friend_name',
      'target_name',
    ]);
    final title = firstString(json, const ['title', 'notice_title']);
    return MentionNotice(
      id: firstInt(json, const ['id', 'notice_id']).ifZero(message.id),
      conversation: Conversation(
        type: conversationType,
        id: conversationId,
        name: conversationName.isEmpty
            ? (conversationType == ConversationType.group
                  ? 'Room $conversationId'
                  : message.sender)
            : conversationName,
        avatar: normalizeApiUrl(
          firstString(source, const ['avatar', 'room_avatar', 'group_avatar']),
        ),
        subtitle: conversationType == ConversationType.group
            ? 'Group chat'
            : 'Private chat',
      ),
      message: message,
      kind: firstString(json, const [
        'type',
        'kind',
        'notice_type',
      ]).ifEmpty(fallbackKind),
      title: title,
      isRead: asBool(json['is_read']) || asBool(json['read']),
    );
  }
}

class MentionNoticeBundle {
  const MentionNoticeBundle({
    required this.items,
    this.mentionCount = 0,
    this.replyCount = 0,
  });

  final List<MentionNotice> items;
  final int mentionCount;
  final int replyCount;

  int get unreadCount {
    final listedUnread = items.where((item) => !item.isRead).length;
    return items.isEmpty ? mentionCount + replyCount : listedUnread;
  }

  bool get hasOnlySummary => items.isEmpty && mentionCount + replyCount > 0;

  MentionNoticeBundle copyWith({
    List<MentionNotice>? items,
    int? mentionCount,
    int? replyCount,
  }) {
    return MentionNoticeBundle(
      items: items ?? this.items,
      mentionCount: mentionCount ?? this.mentionCount,
      replyCount: replyCount ?? this.replyCount,
    );
  }
}

class FriendChangeNotice {
  const FriendChangeNotice({
    required this.id,
    required this.uid,
    required this.nickname,
    this.username = '',
    this.avatar = '',
    this.content = '',
    this.time = '',
    this.kind = '',
    this.isRead = false,
  });

  final int id;
  final int uid;
  final String nickname;
  final String username;
  final String avatar;
  final String content;
  final String time;
  final String kind;
  final bool isRead;

  String get displayName => nickname.trim().isEmpty ? 'UID $uid' : nickname;

  factory FriendChangeNotice.fromJson(Map<String, dynamic> json) {
    final uid = firstInt(json, const [
      'uid',
      'friend_id',
      'from_uid',
      'to_uid',
      'target_uid',
      'user_id',
    ]);
    return FriendChangeNotice(
      id: firstInt(json, const ['id', 'notice_id', 'request_id']),
      uid: uid,
      nickname: firstString(json, const [
        'nickname',
        'friend_name',
        'target_name',
        'name',
      ]).ifEmpty('UID $uid'),
      username: asString(json['username']),
      avatar: normalizeApiUrl(asString(json['avatar'])),
      content: firstString(json, const [
        'content',
        'message',
        'reason',
        'title',
      ]),
      time: firstReadableTime(json, const [
        'create_time',
        'add_time',
        'handle_time',
        'time',
      ]),
      kind: firstString(json, const ['type', 'kind', 'action']),
      isRead: asBool(json['is_read']) || asBool(json['read']),
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
      createTime: firstReadableTime(json, const [
        'create_time',
        'add_time',
        'time',
      ]),
      handleTime: readableTimestamp(json['handle_time']),
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
      createTime: firstReadableTime(json, const [
        'create_time',
        'add_time',
        'time',
      ]),
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

Map<String, dynamic>? firstMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }
  return null;
}

ConversationType _noticeConversationType(Map<String, dynamic> json) {
  final raw = firstString(json, const [
    'conversation_type',
    'chat_type',
    'target_type',
    'type',
  ]).toLowerCase();
  if (raw.contains('private') || raw.contains('friend')) {
    return ConversationType.private;
  }
  if (raw.contains('group') || raw.contains('room')) {
    return ConversationType.group;
  }
  if (firstInt(json, const ['room_id', 'rid', 'group_id']) > 0) {
    return ConversationType.group;
  }
  return ConversationType.private;
}

String firstReadableTime(Map<String, dynamic> json, List<String> keys) {
  return readableTimestamp(firstTimestampValue(json, keys));
}

Object? firstTimestampValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    final normalized = readableTimestamp(value);
    if (normalized.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int timestampForSort(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    if (value == 0) {
      return 0;
    }
    return _dateTimeFromUnix(value.toInt()).millisecondsSinceEpoch;
  }
  final text = asString(value).trim();
  if (text.isEmpty || text == '0') {
    return 0;
  }
  final numeric = int.tryParse(text);
  if (numeric != null) {
    return _dateTimeFromUnix(numeric).millisecondsSinceEpoch;
  }
  var best = 0;
  for (final match in RegExp(
    r'\d{4}-\d{1,2}-\d{1,2}[ T]\d{1,2}:\d{1,2}(?::\d{1,2})?',
  ).allMatches(text)) {
    final raw = text.substring(match.start, match.end);
    final normalized = raw.contains(RegExp(r':\d{1,2}$')) ? raw : '$raw:00';
    final parsed = DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
    if (parsed != null) {
      final candidate = parsed.toLocal().millisecondsSinceEpoch;
      if (candidate > best) {
        best = candidate;
      }
    }
  }
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    final candidate = parsed.toLocal().millisecondsSinceEpoch;
    if (candidate > best) {
      best = candidate;
    }
  }
  return best;
}

String readableTimestamp(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is num) {
    if (value == 0) {
      return '';
    }
    return formatLocalDateTime(_dateTimeFromUnix(value.toInt()));
  }
  final text = asString(value).trim();
  if (text.isEmpty || text == '0') {
    return '';
  }
  final numeric = int.tryParse(text);
  if (numeric != null) {
    return formatLocalDateTime(_dateTimeFromUnix(numeric));
  }
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return formatLocalDateTime(parsed.toLocal());
  }
  return text;
}

DateTime? parseCsacTimestamp(Object? value) {
  final millis = timestampForSort(value);
  if (millis <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
}

String formatCsacTimestamp(
  Object? value, {
  CsacTimestampPattern pattern = CsacTimestampPattern.slash,
}) {
  final parsed = parseCsacTimestamp(value);
  if (parsed == null) {
    return readableTimestamp(value);
  }
  switch (pattern) {
    case CsacTimestampPattern.slash:
      return formatLocalDateTime(parsed, separator: '/');
    case CsacTimestampPattern.dash:
      return formatLocalDateTime(parsed, separator: '-');
    case CsacTimestampPattern.compact:
      return formatCompactLocalDateTime(parsed);
    case CsacTimestampPattern.timeOnly:
      return formatLocalTime(parsed);
  }
}

DateTime _dateTimeFromUnix(int value) {
  final milliseconds = value.abs() >= 1000000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
}

String formatLocalDateTime(DateTime value, {String separator = '-'}) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}$separator${two(value.month)}$separator${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String formatCompactLocalDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String formatLocalTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
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

bool looksLikeVoicePath(String value) {
  final path = _cleanPathForExtension(value);
  return RegExp(r'\.(mp3|m4a|aac|wav|ogg|webm|amr|flac)$').hasMatch(path);
}

bool looksLikeFileLink(String value) {
  final text = value.trim();
  if (text.isEmpty || text.contains('\n')) {
    return false;
  }
  final uri = Uri.tryParse(text);
  if (uri == null || (!uri.hasScheme && !text.startsWith('upload/'))) {
    return false;
  }
  final path = _cleanPathForExtension(text);
  if (path.isEmpty || looksLikeImagePath(text) || looksLikeVoicePath(text)) {
    return false;
  }
  return RegExp(
    r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|md|zip|rar|7z|tar|gz|apk|ipa|exe|dmg|csv|json|xml)$',
  ).hasMatch(path);
}

List<String> extractLinks(String value) {
  final matches = RegExp(r"""https?://[^\s<>"'\]\)]+""").allMatches(value);
  return [
    for (final match in matches)
      value
          .substring(match.start, match.end)
          .replaceAll(RegExp(r'[，。,.]+$'), ''),
  ];
}

String fileNameFromUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  final path = uri?.path.isNotEmpty == true ? uri!.path : url.trim();
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  final name = parts.isEmpty ? '' : parts.last;
  return Uri.decodeComponent(name);
}

String _cleanPathForExtension(String value) {
  final text = value.trim();
  final uri = Uri.tryParse(text);
  final path = uri?.path.isNotEmpty == true ? uri!.path : text;
  return path.toLowerCase().split('?').first.split('#').first;
}

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

extension IntFallback on int {
  int ifZero(int fallback) => this == 0 ? fallback : this;
}
