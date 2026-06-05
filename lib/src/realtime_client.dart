import 'dart:async';
import 'dart:convert';

import 'models.dart';
import 'platform/realtime_socket.dart';

enum CsacRealtimeStatus { disabled, disconnected, connecting, connected, error }

class CsacRealtimeEvent {
  const CsacRealtimeEvent({required this.conversation, required this.latestId});

  final Conversation conversation;
  final int latestId;
}

class CsacRealtimeClient {
  final _events = StreamController<CsacRealtimeEvent>.broadcast();
  final _statusChanges = StreamController<CsacRealtimeStatus>.broadcast();

  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  bool _closing = false;

  CsacRealtimeStatus status = CsacRealtimeStatus.disconnected;
  String lastError = '';

  Stream<CsacRealtimeEvent> get events => _events.stream;
  Stream<CsacRealtimeStatus> get statusChanges => _statusChanges.stream;

  bool get connected => status == CsacRealtimeStatus.connected;

  Future<void> connect({
    required Uri uri,
    required Map<String, String> headers,
    required List<Conversation> conversations,
  }) async {
    await disconnect();
    _closing = false;
    _setStatus(CsacRealtimeStatus.connecting);
    lastError = '';
    try {
      final socket = await connectRealtimeSocket(uri, headers: headers);
      if (_closing) {
        await socket.close();
        return;
      }
      _socket = socket;
      _setStatus(CsacRealtimeStatus.connected);
      _subscription = socket.messages.listen(
        _handleMessage,
        onError: (Object err) => _handleError(err),
        onDone: _handleDone,
        cancelOnError: false,
      );
      _sendJson(<String, Object?>{
        'type': 'subscribe',
        'conversations': [
          for (final conversation in conversations)
            <String, Object?>{
              'conversation_type': conversation.type.name,
              'conversation_id': conversation.id,
            },
        ],
      });
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _sendJson(<String, Object?>{
          'type': 'ping',
          'time': DateTime.now().millisecondsSinceEpoch,
        });
      });
    } catch (err) {
      _setStatus(CsacRealtimeStatus.error);
      lastError = err.toString();
      await disconnect(keepError: true);
    }
  }

  void resubscribe(List<Conversation> conversations) {
    if (!connected) {
      return;
    }
    _sendJson(<String, Object?>{
      'type': 'subscribe',
      'conversations': [
        for (final conversation in conversations)
          <String, Object?>{
            'conversation_type': conversation.type.name,
            'conversation_id': conversation.id,
          },
      ],
    });
  }

  Future<void> disconnect({bool keepError = false}) async {
    _closing = true;
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
    if (!keepError) {
      _setStatus(CsacRealtimeStatus.disconnected);
      lastError = '';
    }
  }

  Future<void> close() async {
    await disconnect();
    await _events.close();
    await _statusChanges.close();
  }

  void _sendJson(Map<String, Object?> data) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    try {
      socket.send(jsonEncode(data));
    } catch (err) {
      _handleError(err);
    }
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final type = '${decoded['type'] ?? ''}';
    if (type != 'conversation:update') {
      return;
    }
    final conversationType = '${decoded['conversation_type'] ?? ''}';
    final id = _asInt(decoded['conversation_id']);
    if (id <= 0) {
      return;
    }
    final latestId = _asInt(decoded['latest_id']);
    final isGroup = conversationType == 'group' || conversationType == 'room';
    final isPrivate =
        conversationType == 'private' || conversationType == 'friend';
    if (!isGroup && !isPrivate) {
      return;
    }
    _events.add(
      CsacRealtimeEvent(
        conversation: Conversation(
          type: isGroup ? ConversationType.group : ConversationType.private,
          id: id,
          name: '',
        ),
        latestId: latestId,
      ),
    );
  }

  void _handleError(Object err) {
    if (_closing) {
      return;
    }
    _setStatus(CsacRealtimeStatus.error);
    lastError = err.toString();
  }

  void _handleDone() {
    if (_closing) {
      return;
    }
    _setStatus(CsacRealtimeStatus.disconnected);
  }

  void _setStatus(CsacRealtimeStatus value) {
    if (status == value) {
      return;
    }
    status = value;
    _statusChanges.add(value);
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
