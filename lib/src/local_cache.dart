import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

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
  Database? _db;

  Future<void> open() async {
    if (_db != null) {
      return;
    }
    final directory = await getApplicationSupportDirectory();
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = await _databaseFile();
    final db = sqlite3.open(file.path);
    _db = db;
    _migrate(db);
  }

  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  Future<void> clear() async {
    final db = await _database();
    db.execute('DELETE FROM session_user');
    db.execute('DELETE FROM messages');
    db.execute('DELETE FROM local_deleted_messages');
    db.execute('DELETE FROM conversations');
  }

  Future<void> clearCachedData() async {
    final db = await _database();
    db.execute('DELETE FROM messages');
    db.execute('DELETE FROM local_deleted_messages');
    db.execute('DELETE FROM conversations');
  }

  Future<CsacLocalCacheStats> stats() async {
    final db = await _database();
    return CsacLocalCacheStats(
      messageCount: _countRows(db, 'messages'),
      conversationCount: _countRows(db, 'conversations'),
      localDeletedMessageCount: _countRows(db, 'local_deleted_messages'),
      databaseBytes: await _databaseStorageBytes(),
    );
  }

  Future<CsacUser?> loadUser() async {
    final db = await _database();
    final rows = db.select('''
      SELECT uid, nickname, username, avatar, online_status, pat_action
      FROM session_user
      ORDER BY saved_at DESC
      LIMIT 1
      ''');
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return CsacUser(
      uid: row['uid'] as int,
      nickname: row['nickname'] as String,
      username: row['username'] as String,
      avatar: row['avatar'] as String,
      onlineStatus: row['online_status'] as String,
      patAction: row['pat_action'] as String,
    );
  }

  Future<void> saveUser(CsacUser user) async {
    final db = await _database();
    db.execute('DELETE FROM session_user');
    db.execute(
      '''
      INSERT INTO session_user (
        uid, nickname, username, avatar, online_status, pat_action, saved_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        user.uid,
        user.nickname,
        user.username,
        user.avatar,
        user.onlineStatus,
        user.patAction,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<Conversation>> loadConversations() async {
    final db = await _database();
    final rows = db.select('''
      SELECT type, remote_id, name, avatar, subtitle, unread_count, search_text,
        last_message_at, display_order
      FROM conversations
      ORDER BY display_order ASC, updated_at DESC, name COLLATE NOCASE ASC
      ''');
    return <Conversation>[
      for (final row in rows)
        Conversation(
          type: _conversationType(row['type'] as String),
          id: row['remote_id'] as int,
          name: row['name'] as String,
          avatar: row['avatar'] as String,
          subtitle: row['subtitle'] as String,
          unreadCount: row['unread_count'] as int,
          searchText: row['search_text'] as String,
          lastMessageAt: row['last_message_at'] as int,
          displayOrder: row['display_order'] as int,
        ),
    ];
  }

  Future<Conversation?> findConversation(ConversationType type, int id) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT type, remote_id, name, avatar, subtitle, unread_count, search_text,
        last_message_at, display_order
      FROM conversations
      WHERE type = ? AND remote_id = ?
      LIMIT 1
      ''',
      [_conversationTypeName(type), id],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return _conversationFromRow(row);
  }

  Future<Map<String, int>> loadConversationActivity() async {
    final db = await _database();
    final rows = db.select('''
      SELECT conversation_type, conversation_id, time
      FROM messages
      ORDER BY conversation_type ASC, conversation_id ASC, id ASC
      ''');
    final activity = <String, int>{};
    for (final row in rows) {
      final type = row['conversation_type'] as String;
      final id = row['conversation_id'] as int;
      final key = '$type:$id';
      final timestamp = timestampForSort(row['time']);
      if (timestamp > (activity[key] ?? 0)) {
        activity[key] = timestamp;
      }
    }
    return activity;
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final db = await _database();
    final deleteStatement = db.prepare('''
      DELETE FROM conversations
      WHERE type = ? AND remote_id = ?
      ''');
    final insertStatement = db.prepare('''
      INSERT INTO conversations (
        type, remote_id, name, avatar, subtitle, unread_count, search_text,
        last_message_at, updated_at, display_order
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(type, remote_id) DO UPDATE SET
        name = excluded.name,
        avatar = excluded.avatar,
        subtitle = excluded.subtitle,
        unread_count = excluded.unread_count,
        search_text = excluded.search_text,
        last_message_at = excluded.last_message_at,
        updated_at = excluded.updated_at,
        display_order = excluded.display_order
      ''');
    try {
      db.execute('BEGIN IMMEDIATE');
      db.execute('UPDATE conversations SET display_order = -1');
      final now = DateTime.now().millisecondsSinceEpoch;
      var index = 0;
      for (final conversation in conversations) {
        insertStatement.execute([
          _conversationTypeName(conversation.type),
          conversation.id,
          conversation.name,
          conversation.avatar,
          conversation.subtitle,
          conversation.unreadCount,
          conversation.searchText,
          conversation.lastMessageAt,
          now,
          index,
        ]);
        index++;
      }
      final staleRows = db.select('''
        SELECT type, remote_id
        FROM conversations
        WHERE display_order < 0
        ''');
      for (final row in staleRows) {
        deleteStatement.execute([row['type'], row['remote_id']]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      deleteStatement.dispose();
      insertStatement.dispose();
    }
  }

  Future<List<ChatMessage>> loadMessages(
    Conversation conversation, {
    int limit = 160,
  }) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT id, sender_id, sender, body, sender_avatar, message_type,
        is_read, member_level, member_title, time, image_url, voice_url,
        voice_duration, file_url, file_name, can_recall, is_recalled,
        is_essence, is_mentioned, reply_to
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ?
      ORDER BY id DESC
      LIMIT ?
      ''',
      [_conversationTypeName(conversation.type), conversation.id, limit],
    );
    final messages = <ChatMessage>[
      for (final row in rows) _messageFromRow(row),
    ];
    messages.sort((a, b) => a.id.compareTo(b.id));
    return messages;
  }

  Future<List<ChatMessage>> loadAllMessages(Conversation conversation) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT id, sender_id, sender, body, sender_avatar, message_type,
        is_read, member_level, member_title, time, image_url, voice_url,
        voice_duration, file_url, file_name, can_recall, is_recalled,
        is_essence, is_mentioned, reply_to
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ?
      ORDER BY id ASC
      ''',
      [_conversationTypeName(conversation.type), conversation.id],
    );
    return <ChatMessage>[for (final row in rows) _messageFromRow(row)];
  }

  Future<List<ChatMessage>> loadMessagesAround(
    Conversation conversation,
    int messageId, {
    int before = 70,
    int after = 70,
  }) async {
    final db = await _database();
    final type = _conversationTypeName(conversation.type);
    final beforeRows = db.select(
      '''
      SELECT id, sender_id, sender, body, sender_avatar, message_type,
        is_read, member_level, member_title, time, image_url, voice_url,
        voice_duration, file_url, file_name, can_recall, is_recalled,
        is_essence, is_mentioned, reply_to
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ? AND id <= ?
      ORDER BY id DESC
      LIMIT ?
      ''',
      [type, conversation.id, messageId, before],
    );
    final afterRows = db.select(
      '''
      SELECT id, sender_id, sender, body, sender_avatar, message_type,
        is_read, member_level, member_title, time, image_url, voice_url,
        voice_duration, file_url, file_name, can_recall, is_recalled,
        is_essence, is_mentioned, reply_to
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ? AND id > ?
      ORDER BY id ASC
      LIMIT ?
      ''',
      [type, conversation.id, messageId, after],
    );
    final messages = <ChatMessage>[
      for (final row in beforeRows) _messageFromRow(row),
      for (final row in afterRows) _messageFromRow(row),
    ];
    messages.sort((a, b) => a.id.compareTo(b.id));
    return mergeChatMessages(const <ChatMessage>[], messages);
  }

  Future<bool> hasMessage(Conversation conversation, int messageId) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT 1
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ? AND id = ?
      LIMIT 1
      ''',
      [_conversationTypeName(conversation.type), conversation.id, messageId],
    );
    return rows.isNotEmpty;
  }

  Future<int> latestMessageId(Conversation conversation) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT COALESCE(MAX(id), 0) AS last_id
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ?
      ''',
      [_conversationTypeName(conversation.type), conversation.id],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first['last_id'] as int;
  }

  Future<int> oldestMessageId(Conversation conversation) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT COALESCE(MIN(id), 0) AS first_id
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ?
      ''',
      [_conversationTypeName(conversation.type), conversation.id],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first['first_id'] as int;
  }

  Future<List<MessageSearchResult>> searchMessages(
    String query,
    SearchScope scope, {
    int limit = 80,
  }) async {
    final text = query.trim();
    if (text.isEmpty &&
        scope != SearchScope.image &&
        scope != SearchScope.essence) {
      return const <MessageSearchResult>[];
    }
    final where = <String>[];
    final params = <Object?>[];
    if (text.isNotEmpty) {
      where.add(r"(m.body LIKE ? ESCAPE '\' OR m.sender LIKE ? ESCAPE '\')");
      final like = '%${_escapeLike(text)}%';
      params
        ..add(like)
        ..add(like);
    }
    switch (scope) {
      case SearchScope.private:
        where.add("m.conversation_type = 'private'");
        break;
      case SearchScope.group:
        where.add("m.conversation_type = 'group'");
        break;
      case SearchScope.image:
        where.add("m.image_url <> ''");
        break;
      case SearchScope.essence:
        where.add('m.is_essence <> 0');
        break;
      case SearchScope.all:
        break;
    }
    final db = await _database();
    final rows = db.select(
      '''
      SELECT
        c.type,
        c.remote_id,
        c.name,
        c.avatar,
        c.subtitle,
        c.unread_count,
        c.search_text,
        c.last_message_at,
        c.display_order,
        m.id,
        m.sender_id,
        m.sender,
        m.body,
        m.sender_avatar,
        m.message_type,
        m.is_read,
        m.member_level,
        m.member_title,
        m.time,
        m.image_url,
        m.voice_url,
        m.voice_duration,
        m.file_url,
        m.file_name,
        m.can_recall,
        m.is_recalled,
        m.is_essence,
        m.is_mentioned,
        m.reply_to
      FROM messages m
      JOIN conversations c
        ON c.type = m.conversation_type AND c.remote_id = m.conversation_id
      WHERE ${where.isEmpty ? '1 = 1' : where.join(' AND ')}
      ORDER BY m.time DESC, m.id DESC
      LIMIT ?
      ''',
      [...params, limit],
    );
    return <MessageSearchResult>[
      for (final row in rows)
        MessageSearchResult(
          conversation: _conversationFromRow(row),
          message: _messageFromRow(row),
          snippet: _snippet(_messageFromRow(row).body, text),
        ),
    ];
  }

  Future<List<ConversationMediaItem>> loadConversationMedia(
    Conversation conversation, {
    ConversationMediaKind kind = ConversationMediaKind.all,
    String query = '',
    int limit = 500,
  }) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT
        c.type,
        c.remote_id,
        c.name,
        c.avatar,
        c.subtitle,
        c.unread_count,
        c.search_text,
        c.last_message_at,
        c.display_order,
        m.id,
        m.sender_id,
        m.sender,
        m.body,
        m.time,
        m.image_url,
        m.voice_url,
        m.voice_duration,
        m.file_url,
        m.file_name,
        m.can_recall,
        m.is_recalled,
        m.is_essence,
        m.is_mentioned,
        m.reply_to
      FROM messages m
      JOIN conversations c
        ON c.type = m.conversation_type AND c.remote_id = m.conversation_id
      WHERE m.conversation_type = ? AND m.conversation_id = ?
        AND (
          m.image_url <> '' OR m.voice_url <> '' OR m.file_url <> ''
          OR m.body LIKE '%http://%' OR m.body LIKE '%https://%'
        )
      ORDER BY m.id DESC
      LIMIT ?
      ''',
      [_conversationTypeName(conversation.type), conversation.id, limit],
    );
    final text = query.trim().toLowerCase();
    final items = <ConversationMediaItem>[];
    final seen = <String>{};
    for (final row in rows) {
      final resolvedConversation = _conversationFromRow(row);
      final message = _messageFromRow(row);
      void add(
        ConversationMediaKind itemKind,
        String rawUrl, {
        String title = '',
      }) {
        final url = normalizeApiUrl(rawUrl);
        if (url.isEmpty ||
            (kind != ConversationMediaKind.all && kind != itemKind)) {
          return;
        }
        final key = '${itemKind.name}:$url:${message.id}';
        if (!seen.add(key)) {
          return;
        }
        final item = ConversationMediaItem(
          conversation: resolvedConversation,
          message: message,
          kind: itemKind,
          url: url,
          title: title,
        );
        if (text.isNotEmpty && !item.searchableText.contains(text)) {
          return;
        }
        items.add(item);
      }

      add(ConversationMediaKind.image, message.imageUrl);
      add(
        ConversationMediaKind.voice,
        message.voiceUrl,
        title: message.voiceDuration > 0 ? '${message.voiceDuration}s' : '',
      );
      add(ConversationMediaKind.file, message.fileUrl, title: message.fileName);
      for (final link in extractLinks(message.body)) {
        if (looksLikeImagePath(link)) {
          add(ConversationMediaKind.image, link);
        } else if (looksLikeVoicePath(link)) {
          add(ConversationMediaKind.voice, link);
        } else if (looksLikeFileLink(link)) {
          add(ConversationMediaKind.file, link);
        }
      }
    }
    return items;
  }

  Future<String> latestImageUrl() async {
    final db = await _database();
    final rows = db.select('''
      SELECT image_url
      FROM messages
      WHERE image_url <> ''
      ORDER BY id DESC
      LIMIT 1
      ''');
    if (rows.isEmpty) {
      return '';
    }
    return normalizeApiUrl(asString(rows.first['image_url']));
  }

  Future<void> saveMessages(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) {
      return;
    }
    final db = await _database();
    final statement = db.prepare('''
      INSERT INTO messages (
        conversation_type, conversation_id, id, sender_id, sender, body, time,
        sender_avatar, message_type, is_read, member_level, member_title,
        image_url, voice_url, voice_duration, file_url, file_name, can_recall,
        is_recalled, is_essence, is_mentioned, reply_to
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(conversation_type, conversation_id, id) DO UPDATE SET
        sender_id = excluded.sender_id,
        sender = excluded.sender,
        body = excluded.body,
        time = excluded.time,
        sender_avatar = excluded.sender_avatar,
        message_type = excluded.message_type,
        is_read = excluded.is_read,
        member_level = excluded.member_level,
        member_title = excluded.member_title,
        image_url = excluded.image_url,
        voice_url = excluded.voice_url,
        voice_duration = excluded.voice_duration,
        file_url = excluded.file_url,
        file_name = excluded.file_name,
        can_recall = excluded.can_recall,
        is_recalled = excluded.is_recalled,
        is_essence = excluded.is_essence,
        is_mentioned = excluded.is_mentioned,
        reply_to = excluded.reply_to
      ''');
    try {
      db.execute('BEGIN IMMEDIATE');
      final type = _conversationTypeName(conversation.type);
      final deletedIds = _deletedMessageIds(db, conversation);
      for (final message in messages) {
        if (deletedIds.contains(message.id)) {
          continue;
        }
        statement.execute([
          type,
          conversation.id,
          message.id,
          message.senderId,
          message.sender,
          message.body,
          message.time,
          message.senderAvatar,
          message.messageType,
          message.isRead ? 1 : 0,
          message.memberLevel,
          message.memberTitle,
          message.imageUrl,
          message.voiceUrl,
          message.voiceDuration,
          message.fileUrl,
          message.fileName,
          message.canRecall ? 1 : 0,
          message.isRecalled ? 1 : 0,
          message.isEssence ? 1 : 0,
          message.isMentioned ? 1 : 0,
          message.replyTo,
        ]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      statement.dispose();
    }
  }

  Future<void> replaceMessages(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    final db = await _database();
    try {
      db.execute('BEGIN IMMEDIATE');
      db.execute(
        '''
        DELETE FROM messages
        WHERE conversation_type = ? AND conversation_id = ?
        ''',
        [_conversationTypeName(conversation.type), conversation.id],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    await saveMessages(conversation, messages);
  }

  Future<List<ChatMessage>> filterLocallyDeletedMessages(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) {
      return messages;
    }
    final db = await _database();
    final deletedIds = _deletedMessageIds(db, conversation);
    if (deletedIds.isEmpty) {
      return messages;
    }
    return messages
        .where((message) => !deletedIds.contains(message.id))
        .toList();
  }

  Future<void> deleteMessages(
    Conversation conversation,
    Iterable<int> messageIds,
  ) async {
    final ids = messageIds.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) {
      return;
    }
    final db = await _database();
    final statement = db.prepare('''
      DELETE FROM messages
      WHERE conversation_type = ? AND conversation_id = ? AND id = ?
      ''');
    final tombstoneStatement = db.prepare('''
      INSERT OR IGNORE INTO local_deleted_messages (
        conversation_type, conversation_id, id, deleted_at
      )
      VALUES (?, ?, ?, ?)
      ''');
    try {
      db.execute('BEGIN IMMEDIATE');
      final type = _conversationTypeName(conversation.type);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in ids) {
        statement.execute([type, conversation.id, id]);
        tombstoneStatement.execute([type, conversation.id, id, now]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      statement.dispose();
      tombstoneStatement.dispose();
    }
  }

  Future<Database> _database() async {
    await open();
    return _db!;
  }

  Future<File> _databaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'csac_cache.sqlite3'));
  }

  Future<int> _databaseStorageBytes() async {
    final file = await _databaseFile();
    var total = 0;
    for (final path in <String>[
      file.path,
      '${file.path}-wal',
      '${file.path}-shm',
    ]) {
      final part = File(path);
      if (part.existsSync()) {
        total += await part.length();
      }
    }
    return total;
  }

  int _countRows(Database db, String table) {
    final rows = db.select('SELECT COUNT(*) AS count FROM $table');
    return rows.first['count'] as int;
  }

  void _migrate(Database db) {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
      CREATE TABLE IF NOT EXISTS session_user (
        uid INTEGER NOT NULL PRIMARY KEY,
        nickname TEXT NOT NULL DEFAULT '',
        username TEXT NOT NULL DEFAULT '',
        avatar TEXT NOT NULL DEFAULT '',
        online_status TEXT NOT NULL DEFAULT '',
        pat_action TEXT NOT NULL DEFAULT '$defaultPatAction',
        saved_at INTEGER NOT NULL DEFAULT 0
      )
      ''');
    _addColumnIfMissing(
      db,
      'session_user',
      'pat_action',
      "TEXT NOT NULL DEFAULT '$defaultPatAction'",
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS conversations (
        type TEXT NOT NULL,
        remote_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        avatar TEXT NOT NULL DEFAULT '',
        subtitle TEXT NOT NULL DEFAULT '',
        unread_count INTEGER NOT NULL DEFAULT 0,
        search_text TEXT NOT NULL DEFAULT '',
        last_message_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        display_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (type, remote_id)
      )
      ''');
    _addColumnIfMissing(
      db,
      'conversations',
      'display_order',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _addColumnIfMissing(
      db,
      'conversations',
      'avatar',
      "TEXT NOT NULL DEFAULT ''",
    );
    _addColumnIfMissing(
      db,
      'conversations',
      'search_text',
      "TEXT NOT NULL DEFAULT ''",
    );
    _addColumnIfMissing(
      db,
      'conversations',
      'last_message_at',
      'INTEGER NOT NULL DEFAULT 0',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        conversation_type TEXT NOT NULL,
        conversation_id INTEGER NOT NULL,
        id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL DEFAULT 0,
        sender TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        sender_avatar TEXT NOT NULL DEFAULT '',
        message_type INTEGER NOT NULL DEFAULT 1,
        is_read INTEGER NOT NULL DEFAULT 0,
        member_level INTEGER NOT NULL DEFAULT 0,
        member_title TEXT NOT NULL DEFAULT '',
        time TEXT NOT NULL DEFAULT '',
        image_url TEXT NOT NULL DEFAULT '',
        voice_url TEXT NOT NULL DEFAULT '',
        voice_duration INTEGER NOT NULL DEFAULT 0,
        file_url TEXT NOT NULL DEFAULT '',
        file_name TEXT NOT NULL DEFAULT '',
        can_recall INTEGER NOT NULL DEFAULT 0,
        is_recalled INTEGER NOT NULL DEFAULT 0,
        is_essence INTEGER NOT NULL DEFAULT 0,
        is_mentioned INTEGER NOT NULL DEFAULT 0,
        reply_to INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (conversation_type, conversation_id, id)
      )
      ''');
    _addColumnIfMissing(
      db,
      'messages',
      'sender_avatar',
      "TEXT NOT NULL DEFAULT ''",
    );
    _addColumnIfMissing(
      db,
      'messages',
      'message_type',
      'INTEGER NOT NULL DEFAULT 1',
    );
    _addColumnIfMissing(
      db,
      'messages',
      'is_read',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _addColumnIfMissing(
      db,
      'messages',
      'member_level',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _addColumnIfMissing(
      db,
      'messages',
      'member_title',
      "TEXT NOT NULL DEFAULT ''",
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS local_deleted_messages (
        conversation_type TEXT NOT NULL,
        conversation_id INTEGER NOT NULL,
        id INTEGER NOT NULL,
        deleted_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (conversation_type, conversation_id, id)
      )
      ''');
    _addColumnIfMissing(
      db,
      'messages',
      'voice_url',
      "TEXT NOT NULL DEFAULT ''",
    );
    _addColumnIfMissing(
      db,
      'messages',
      'voice_duration',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _addColumnIfMissing(db, 'messages', 'file_url', "TEXT NOT NULL DEFAULT ''");
    _addColumnIfMissing(
      db,
      'messages',
      'file_name',
      "TEXT NOT NULL DEFAULT ''",
    );
    _addColumnIfMissing(
      db,
      'messages',
      'can_recall',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _addColumnIfMissing(
      db,
      'messages',
      'is_recalled',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _addColumnIfMissing(
      db,
      'messages',
      'reply_to',
      'INTEGER NOT NULL DEFAULT 0',
    );
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_messages_conversation_id
      ON messages(conversation_type, conversation_id, id)
      ''');
  }

  ConversationType _conversationType(String raw) {
    return raw == 'group' ? ConversationType.group : ConversationType.private;
  }

  String _conversationTypeName(ConversationType type) {
    return type == ConversationType.group ? 'group' : 'private';
  }

  Conversation _conversationFromRow(Row row) {
    return Conversation(
      type: _conversationType(row['type'] as String),
      id: row['remote_id'] as int,
      name: row['name'] as String,
      avatar: row['avatar'] as String,
      subtitle: row['subtitle'] as String,
      unreadCount: row['unread_count'] as int,
      searchText: row['search_text'] as String,
      lastMessageAt: row['last_message_at'] as int,
      displayOrder: row['display_order'] as int,
    );
  }

  ChatMessage _messageFromRow(Row row) {
    final imageUrl = asString(row['image_url']);
    final voiceUrl = asString(row['voice_url']);
    final fileUrl = asString(row['file_url']);
    var body = asString(row['body']);
    if (imageUrl.isNotEmpty &&
        (body.startsWith('[image]') || looksLikeImagePath(body))) {
      body = '[image]';
    }
    if (voiceUrl.isNotEmpty && body.trim().isEmpty) {
      body = '[voice]';
    }
    if (fileUrl.isNotEmpty && body.trim().isEmpty) {
      body = '[file]';
    }
    final time = readableTimestamp(row['time']);
    return ChatMessage(
      id: asInt(row['id']),
      senderId: asInt(row['sender_id']),
      sender: asString(row['sender']),
      body: body,
      senderAvatar: asString(row['sender_avatar']),
      messageType: asInt(row['message_type']).ifZero(1),
      isRead: asBool(row['is_read']),
      memberLevel: asInt(row['member_level']),
      memberTitle: asString(row['member_title']),
      time: time,
      timeSortValue: timestampForSort(row['time']),
      imageUrl: imageUrl,
      voiceUrl: voiceUrl,
      voiceDuration: asInt(row['voice_duration']),
      fileUrl: fileUrl,
      fileName: asString(row['file_name']),
      canRecall: asBool(row['can_recall']),
      isRecalled: asBool(row['is_recalled']),
      isEssence: asBool(row['is_essence']),
      isMentioned: asBool(row['is_mentioned']),
      replyTo: asInt(row['reply_to']),
    );
  }

  Set<int> _deletedMessageIds(Database db, Conversation conversation) {
    final rows = db.select(
      '''
      SELECT id
      FROM local_deleted_messages
      WHERE conversation_type = ? AND conversation_id = ?
      ''',
      [_conversationTypeName(conversation.type), conversation.id],
    );
    return rows.map((row) => row['id'] as int).toSet();
  }

  String _snippet(String body, String query) {
    final text = body.trim();
    if (text.isEmpty) {
      return '[image]';
    }
    if (query.isEmpty) {
      return text.length <= 96 ? text : '${text.substring(0, 96)}...';
    }
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return text.length <= 96 ? text : '${text.substring(0, 96)}...';
    }
    final start = (index - 36).clamp(0, text.length);
    final end = (index + query.length + 60).clamp(0, text.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }

  String _escapeLike(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  void _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) {
    final rows = db.select('PRAGMA table_info($table)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}
