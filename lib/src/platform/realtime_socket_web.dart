// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<RealtimeSocket> connectRealtimeSocket(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
}) async {
  final socket = html.WebSocket(uri.toString());
  final opened = Completer<void>();
  late final StreamSubscription openSub;
  late final StreamSubscription errorSub;
  openSub = socket.onOpen.listen((_) {
    if (!opened.isCompleted) {
      opened.complete();
    }
  });
  errorSub = socket.onError.listen((_) {
    if (!opened.isCompleted) {
      opened.completeError(StateError('WebSocket connection failed.'));
    }
  });
  try {
    await opened.future.timeout(const Duration(seconds: 8));
  } finally {
    await openSub.cancel();
    await errorSub.cancel();
  }
  return _WebRealtimeSocket(socket);
}

abstract class RealtimeSocket {
  Stream<dynamic> get messages;
  void send(String data);
  Future<void> close();
}

class _WebRealtimeSocket implements RealtimeSocket {
  _WebRealtimeSocket(this._socket) {
    _messageSub = _socket.onMessage.listen((event) {
      _controller.add(event.data);
    });
    _errorSub = _socket.onError.listen((event) {
      _controller.addError(StateError('WebSocket error.'));
    });
    _closeSub = _socket.onClose.listen((event) {
      _controller.close();
    });
  }

  final html.WebSocket _socket;
  final _controller = StreamController<dynamic>.broadcast();
  late final StreamSubscription _messageSub;
  late final StreamSubscription _errorSub;
  late final StreamSubscription _closeSub;

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(String data) => _socket.send(data);

  @override
  Future<void> close() async {
    _socket.close();
    await _messageSub.cancel();
    await _errorSub.cancel();
    await _closeSub.cancel();
    await _controller.close();
  }
}
