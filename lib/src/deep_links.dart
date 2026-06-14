const csacDeepLinkScheme = 'csacflutterleon';

enum CsacDeepLinkAction {
  chats,
  search,
  searchResult,
  space,
  spacePost,
  notices,
  profile,
  userProfile,
  groupChat,
  privateChat,
  groupMessage,
  privateMessage,
  unsupported,
}

class CsacDeepLinkTarget {
  const CsacDeepLinkTarget(this.action, {this.id, this.messageId, this.query});

  final CsacDeepLinkAction action;
  final int? id;
  final int? messageId;
  final String? query;

  bool get isSupported => action != CsacDeepLinkAction.unsupported;
}

bool isCsacDeepLink(Uri uri) {
  return uri.scheme.toLowerCase() == csacDeepLinkScheme;
}

CsacDeepLinkTarget parseCsacDeepLink(Uri uri) {
  if (!isCsacDeepLink(uri)) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
  }
  final segments = csacDeepLinkSegments(uri);
  if (segments.isEmpty) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.chats);
  }
  switch (segments.first) {
    case 'home':
    case 'chatlist':
    case 'chats':
    case 'conversations':
    case 'messages':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.chats);
    case 'search':
    case 'find':
      final query = (uri.queryParameters['q'] ?? uri.queryParameters['query'])
          ?.trim();
      if (query != null && query.isNotEmpty) {
        return CsacDeepLinkTarget(
          CsacDeepLinkAction.searchResult,
          query: query,
        );
      }
      return const CsacDeepLinkTarget(CsacDeepLinkAction.search);
    case 'space':
    case 'discover':
    case 'discovery':
    case 'dynamic':
    case 'feed':
      if (segments.length > 2 &&
          (segments[1] == 'post' ||
              segments[1] == 'status' ||
              segments[1] == 'dynamic')) {
        return _typedChatLinkTarget(CsacDeepLinkAction.spacePost, segments[2]);
      }
      if (segments.length > 1 &&
          (segments[1] == 'post' ||
              segments[1] == 'status' ||
              segments[1] == 'dynamic')) {
        return _typedChatLinkTarget(
          CsacDeepLinkAction.spacePost,
          uri.queryParameters['id'],
        );
      }
      return const CsacDeepLinkTarget(CsacDeepLinkAction.space);
    case 'post':
    case 'status':
      return _typedChatLinkTarget(
        CsacDeepLinkAction.spacePost,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
      );
    case 'notice':
    case 'notices':
    case 'notification':
    case 'notifications':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.notices);
    case 'me':
    case 'mine':
    case 'settings':
      return const CsacDeepLinkTarget(CsacDeepLinkAction.profile);
    case 'profile':
      return _profileLinkTarget(uri, segments);
    case 'u':
    case 'uid':
    case 'user-profile':
    case 'profile-user':
      return _typedChatLinkTarget(
        CsacDeepLinkAction.userProfile,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
      );
    case 'chat':
    case 'conversation':
      return _chatLinkTarget(uri, segments);
    case 'message':
    case 'msg':
      return _messageLinkTarget(uri, segments);
    case 'group':
    case 'room':
      return _chatOrMessageLinkTarget(
        CsacDeepLinkAction.groupChat,
        CsacDeepLinkAction.groupMessage,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
        segments.length > 3 && segments[2] == 'message'
            ? segments[3]
            : uri.queryParameters['message_id'],
      );
    case 'private':
    case 'friend':
    case 'user':
      return _chatOrMessageLinkTarget(
        CsacDeepLinkAction.privateChat,
        CsacDeepLinkAction.privateMessage,
        segments.length > 1 ? segments[1] : uri.queryParameters['id'],
        segments.length > 3 && segments[2] == 'message'
            ? segments[3]
            : uri.queryParameters['message_id'],
      );
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
}

String csacUserProfileDeepLink(int uid) {
  return '$csacDeepLinkScheme://profile/user/$uid';
}

String csacGroupChatDeepLink(int roomId) {
  return '$csacDeepLinkScheme://chat/group/$roomId';
}

String csacSpacePostDeepLink(int postId) {
  return '$csacDeepLinkScheme://space/post/$postId';
}

String csacSearchDeepLink(String query) {
  final encoded = Uri.encodeQueryComponent(query.trim());
  return encoded.isEmpty
      ? '$csacDeepLinkScheme://search'
      : '$csacDeepLinkScheme://search?q=$encoded';
}

String csacGroupMessageDeepLink(int roomId, int messageId) {
  return '$csacDeepLinkScheme://chat/group/$roomId/message/$messageId';
}

String csacPrivateMessageDeepLink(int uid, int messageId) {
  return '$csacDeepLinkScheme://chat/private/$uid/message/$messageId';
}

List<String> csacDeepLinkSegments(Uri uri) {
  final segments = <String>[];
  if (uri.host.trim().isNotEmpty) {
    segments.add(uri.host.trim());
  }
  for (final segment in uri.pathSegments) {
    final trimmed = segment.trim();
    if (trimmed.isNotEmpty) {
      segments.add(trimmed);
    }
  }
  if (segments.isEmpty && uri.fragment.trim().isNotEmpty) {
    final fragment = uri.fragment.trim().replaceFirst(RegExp(r'^/+'), '');
    segments.addAll(
      fragment
          .split('/')
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty),
    );
  }
  return [
    for (final segment in segments) Uri.decodeComponent(segment).toLowerCase(),
  ];
}

CsacDeepLinkTarget _chatLinkTarget(Uri uri, List<String> segments) {
  final type = segments.length > 1
      ? segments[1]
      : (uri.queryParameters['type'] ?? uri.queryParameters['kind'] ?? '');
  final id = segments.length > 2 ? segments[2] : uri.queryParameters['id'];
  final messageId = segments.length > 4 && segments[3] == 'message'
      ? segments[4]
      : (uri.queryParameters['message_id'] ??
            uri.queryParameters['msg_id'] ??
            uri.queryParameters['mid']);
  switch (type.toLowerCase()) {
    case 'group':
    case 'room':
      return _chatOrMessageLinkTarget(
        CsacDeepLinkAction.groupChat,
        CsacDeepLinkAction.groupMessage,
        id,
        messageId,
      );
    case 'private':
    case 'friend':
    case 'user':
      return _chatOrMessageLinkTarget(
        CsacDeepLinkAction.privateChat,
        CsacDeepLinkAction.privateMessage,
        id,
        messageId,
      );
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
}

CsacDeepLinkTarget _messageLinkTarget(Uri uri, List<String> segments) {
  final type = segments.length > 1
      ? segments[1]
      : (uri.queryParameters['type'] ?? uri.queryParameters['kind'] ?? '');
  final id = segments.length > 2
      ? segments[2]
      : (uri.queryParameters['room_id'] ??
            uri.queryParameters['uid'] ??
            uri.queryParameters['id']);
  final messageId = segments.length > 3
      ? segments[3]
      : (uri.queryParameters['message_id'] ??
            uri.queryParameters['msg_id'] ??
            uri.queryParameters['mid']);
  switch (type.toLowerCase()) {
    case 'group':
    case 'room':
      return _chatOrMessageLinkTarget(
        CsacDeepLinkAction.groupChat,
        CsacDeepLinkAction.groupMessage,
        id,
        messageId,
      );
    case 'private':
    case 'friend':
    case 'user':
      return _chatOrMessageLinkTarget(
        CsacDeepLinkAction.privateChat,
        CsacDeepLinkAction.privateMessage,
        id,
        messageId,
      );
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
}

CsacDeepLinkTarget _chatOrMessageLinkTarget(
  CsacDeepLinkAction chatAction,
  CsacDeepLinkAction messageAction,
  String? rawId,
  String? rawMessageId,
) {
  final id = int.tryParse((rawId ?? '').trim()) ?? 0;
  if (id <= 0) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
  }
  final messageId = int.tryParse((rawMessageId ?? '').trim()) ?? 0;
  if (messageId > 0) {
    return CsacDeepLinkTarget(messageAction, id: id, messageId: messageId);
  }
  return CsacDeepLinkTarget(chatAction, id: id);
}

CsacDeepLinkTarget _profileLinkTarget(Uri uri, List<String> segments) {
  if (segments.length > 1) {
    final kind = segments[1];
    if (kind == 'user' || kind == 'uid') {
      return _typedChatLinkTarget(
        CsacDeepLinkAction.userProfile,
        segments.length > 2 ? segments[2] : uri.queryParameters['id'],
      );
    }
    final id = int.tryParse(kind) ?? 0;
    if (id > 0) {
      return CsacDeepLinkTarget(CsacDeepLinkAction.userProfile, id: id);
    }
  }
  final id = int.tryParse(uri.queryParameters['uid'] ?? '') ?? 0;
  if (id > 0) {
    return CsacDeepLinkTarget(CsacDeepLinkAction.userProfile, id: id);
  }
  return const CsacDeepLinkTarget(CsacDeepLinkAction.profile);
}

CsacDeepLinkTarget _typedChatLinkTarget(
  CsacDeepLinkAction action,
  String? rawId,
) {
  final id = int.tryParse((rawId ?? '').trim()) ?? 0;
  if (id <= 0) {
    return const CsacDeepLinkTarget(CsacDeepLinkAction.unsupported);
  }
  return CsacDeepLinkTarget(action, id: id);
}
