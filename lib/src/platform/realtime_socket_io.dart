import 'dart:async';
import 'dart:io';

Future<RealtimeSocket> connectRealtimeSocket(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
}) async {
  final socket = await WebSocket.connect(
    uri.toString(),
    headers: headers.isEmpty ? null : headers,
  ).timeout(const Duration(seconds: 8));
  return _IoRealtimeSocket(socket);
}

abstract class RealtimeSocket {
  Stream<dynamic> get messages;
  void send(String data);
  Future<void> close();
}

class _IoRealtimeSocket implements RealtimeSocket {
  const _IoRealtimeSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<dynamic> get messages => _socket;

  @override
  void send(String data) => _socket.add(data);

  @override
  Future<void> close() => _socket.close();
}
