import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

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
    final file = File(p.join(directory.path, 'csac_cache.sqlite3'));
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

  Future<void> clearConversationMessages(Conversation conversation) async {
    final db = await _database();
    final type = _conversationTypeName(conversation.type);
    db.execute(
      'DELETE FROM messages WHERE conversation_type = ? AND conversation_id = ?',
      [type, conversation.id],
    );
    db.execute(
      '''
      DELETE FROM local_deleted_messages
      WHERE conversation_type = ? AND conversation_id = ?
      ''',
      [type, conversation.id],
    );
  }

  Future<CsacUser?> loadUser() async {
    final db = await _database();
    final rows = db.select('''
      SELECT uid, nickname, username, avatar, online_status
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
    );
  }

  Future<void> saveUser(CsacUser user) async {
    final db = await _database();
    db.execute('DELETE FROM session_user');
    db.execute(
      '''
      INSERT INTO session_user (
        uid, nickname, username, avatar, online_status, saved_at
      )
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        user.uid,
        user.nickname,
        user.username,
        user.avatar,
        user.onlineStatus,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<Conversation>> loadConversations() async {
    final db = await _database();
    final rows = db.select('''
      SELECT type, remote_id, name, subtitle, unread_count, search_text, avatar
      FROM conversations
      ORDER BY display_order ASC, updated_at DESC, name COLLATE NOCASE ASC
      ''');
    return <Conversation>[
      for (final row in rows)
        Conversation(
          type: _conversationType(row['type'] as String),
          id: row['remote_id'] as int,
          name: row['name'] as String,
          avatar: row['avatar'] as String? ?? '',
          subtitle: row['subtitle'] as String,
          unreadCount: row['unread_count'] as int,
          searchText: row['search_text'] as String,
        ),
    ];
  }

  Future<Conversation?> findConversation(ConversationType type, int id) async {
    final db = await _database();
    final rows = db.select(
      '''
      SELECT type, remote_id, name, subtitle, unread_count, search_text, avatar
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

  Future<void> saveConversations(List<Conversation> conversations) async {
    final db = await _database();
    final deleteStatement = db.prepare('''
      DELETE FROM conversations
      WHERE type = ? AND remote_id = ?
      ''');
    final insertStatement = db.prepare('''
      INSERT INTO conversations (
        type, remote_id, name, subtitle, unread_count, search_text, avatar,
        updated_at, display_order
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(type, remote_id) DO UPDATE SET
        name = excluded.name,
        subtitle = excluded.subtitle,
        unread_count = excluded.unread_count,
        search_text = excluded.search_text,
        avatar = excluded.avatar,
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
          conversation.subtitle,
          conversation.unreadCount,
          conversation.searchText,
          conversation.avatar,
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
      SELECT id, sender_id, sender, body, time, image_url, voice_url,
        voice_duration, can_recall, is_recalled, is_essence, is_mentioned,
        is_read, reply_to
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
      SELECT id, sender_id, sender, body, time, image_url, voice_url,
        voice_duration, can_recall, is_recalled, is_essence, is_mentioned,
        is_read, reply_to
      FROM messages
      WHERE conversation_type = ? AND conversation_id = ? AND id <= ?
      ORDER BY id DESC
      LIMIT ?
      ''',
      [type, conversation.id, messageId, before],
    );
    final afterRows = db.select(
      '''
      SELECT id, sender_id, sender, body, time, image_url, voice_url,
        voice_duration, can_recall, is_recalled, is_essence, is_mentioned,
        is_read, reply_to
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
        m.id,
        m.sender_id,
        m.sender,
        m.body,
        m.time,
        m.image_url,
        m.voice_url,
        m.voice_duration,
        m.can_recall,
        m.is_recalled,
        m.is_essence,
        m.is_mentioned,
        m.is_read,
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
        image_url, voice_url, voice_duration, can_recall, is_recalled,
        is_essence, is_mentioned, is_read, reply_to
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(conversation_type, conversation_id, id) DO UPDATE SET
        sender_id = excluded.sender_id,
        sender = excluded.sender,
        body = excluded.body,
        time = excluded.time,
        image_url = excluded.image_url,
        voice_url = excluded.voice_url,
        voice_duration = excluded.voice_duration,
        can_recall = excluded.can_recall,
        is_recalled = excluded.is_recalled,
        is_essence = excluded.is_essence,
        is_mentioned = excluded.is_mentioned,
        is_read = excluded.is_read,
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
          message.imageUrl,
          message.voiceUrl,
          message.voiceDuration,
          message.canRecall ? 1 : 0,
          message.isRecalled ? 1 : 0,
          message.isEssence ? 1 : 0,
          message.isMentioned ? 1 : 0,
          message.isRead ? 1 : 0,
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
        saved_at INTEGER NOT NULL DEFAULT 0
      )
      ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS conversations (
        type TEXT NOT NULL,
        remote_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        subtitle TEXT NOT NULL DEFAULT '',
        unread_count INTEGER NOT NULL DEFAULT 0,
        search_text TEXT NOT NULL DEFAULT '',
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
      'search_text',
      "TEXT NOT NULL DEFAULT ''",
    );
    _addColumnIfMissing(
      db,
      'conversations',
      'avatar',
      "TEXT NOT NULL DEFAULT ''",
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        conversation_type TEXT NOT NULL,
        conversation_id INTEGER NOT NULL,
        id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL DEFAULT 0,
        sender TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        time TEXT NOT NULL DEFAULT '',
        image_url TEXT NOT NULL DEFAULT '',
        voice_url TEXT NOT NULL DEFAULT '',
        voice_duration INTEGER NOT NULL DEFAULT 0,
        can_recall INTEGER NOT NULL DEFAULT 0,
        is_recalled INTEGER NOT NULL DEFAULT 0,
        is_essence INTEGER NOT NULL DEFAULT 0,
        is_mentioned INTEGER NOT NULL DEFAULT 0,
        is_read INTEGER NOT NULL DEFAULT 0,
        reply_to INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (conversation_type, conversation_id, id)
      )
      ''');
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
      'is_read',
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
      avatar: row['avatar'] as String? ?? '',
      subtitle: row['subtitle'] as String,
      unreadCount: row['unread_count'] as int,
      searchText: row['search_text'] as String,
    );
  }

  ChatMessage _messageFromRow(Row row) {
    final imageUrl = row['image_url'] as String;
    var body = row['body'] as String;
    if (imageUrl.isNotEmpty &&
        (body.startsWith('[image]') || looksLikeImagePath(body))) {
      body = '[image]';
    }
    return ChatMessage(
      id: row['id'] as int,
      senderId: row['sender_id'] as int,
      sender: row['sender'] as String,
      body: body,
      time: row['time'] as String,
      imageUrl: imageUrl,
      voiceUrl: row['voice_url'] as String,
      voiceDuration: row['voice_duration'] as int,
      canRecall: (row['can_recall'] as int) != 0,
      isRecalled: (row['is_recalled'] as int) != 0,
      isEssence: (row['is_essence'] as int) != 0,
      isMentioned: (row['is_mentioned'] as int) != 0,
      isRead: (row['is_read'] as int? ?? 0) != 0,
      replyTo: row['reply_to'] as int,
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
