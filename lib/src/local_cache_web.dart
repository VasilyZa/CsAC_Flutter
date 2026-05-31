import 'models.dart';

class CsacLocalCacheStats {
  const CsacLocalCacheStats({
    required this.messageCount,
    required this.conversationCount,
    required this.localDeletedMessageCount,
    required this.databaseBytes,
  });

  final int messageCount;
  final int conversationCount;
  final int localDeletedMessageCount;
  final int databaseBytes;
}

class CsacLocalCache {
  Future<void> open() async {}

  Future<void> close() async {}

  Future<void> clear() async {}

  Future<void> clearCachedData() async {}

  Future<CsacLocalCacheStats> stats() async {
    return const CsacLocalCacheStats(
      messageCount: 0,
      conversationCount: 0,
      localDeletedMessageCount: 0,
      databaseBytes: 0,
    );
  }

  Future<CsacUser?> loadUser() async => null;

  Future<void> saveUser(CsacUser user) async {}

  Future<List<Conversation>> loadConversations() async {
    return const <Conversation>[];
  }

  Future<Conversation?> findConversation(ConversationType type, int id) async {
    return null;
  }

  Future<Map<String, int>> loadConversationActivity() async {
    return const <String, int>{};
  }

  Future<void> saveConversations(List<Conversation> conversations) async {}

  Future<List<ChatMessage>> loadMessages(
    Conversation conversation, {
    int limit = 160,
  }) async {
    return const <ChatMessage>[];
  }

  Future<List<ChatMessage>> loadAllMessages(Conversation conversation) async {
    return const <ChatMessage>[];
  }

  Future<List<ChatMessage>> loadMessagesAround(
    Conversation conversation,
    int messageId, {
    int before = 70,
    int after = 70,
  }) async {
    return const <ChatMessage>[];
  }

  Future<bool> hasMessage(Conversation conversation, int messageId) async {
    return false;
  }

  Future<int> latestMessageId(Conversation conversation) async => 0;

  Future<int> oldestMessageId(Conversation conversation) async => 0;

  Future<List<MessageSearchResult>> searchMessages(
    String query,
    SearchScope scope, {
    int limit = 80,
  }) async {
    return const <MessageSearchResult>[];
  }

  Future<List<ConversationMediaItem>> loadConversationMedia(
    Conversation conversation, {
    ConversationMediaKind kind = ConversationMediaKind.all,
    String query = '',
    int limit = 500,
  }) async {
    return const <ConversationMediaItem>[];
  }

  Future<String> latestImageUrl() async => '';

  Future<void> saveMessages(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {}

  Future<void> replaceMessages(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {}

  Future<List<ChatMessage>> filterLocallyDeletedMessages(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    return messages;
  }

  Future<void> deleteMessages(
    Conversation conversation,
    Iterable<int> messageIds,
  ) async {}
}
