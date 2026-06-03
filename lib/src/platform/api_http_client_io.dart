import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http2/transport.dart' as h2;

import '../api_protocol.dart';

ProtocolAwareHttpClient createApiHttpClient() {
  final fallback = HttpClient()..badCertificateCallback = (_, _, _) => true;
  return _ProtocolAwareIoClient(IOClient(fallback));
}

class _ProtocolAwareIoClient extends http.BaseClient
    implements ProtocolAwareHttpClient {
  _ProtocolAwareIoClient(this._fallback);

  final IOClient _fallback;
  final Map<String, _Http2Connection> _http2Connections =
      <String, _Http2Connection>{};

  ApiProtocolChanged? _onProtocolChanged;
  ApiHttpProtocol _lastProtocol = ApiHttpProtocol.unknown;
  bool _closed = false;

  @override
  ApiHttpProtocol get lastProtocol => _lastProtocol;

  @override
  set onProtocolChanged(ApiProtocolChanged? callback) {
    _onProtocolChanged = callback;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) {
      throw http.ClientException(
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }
    if (request.url.scheme == 'https') {
      final prepared = await _PreparedRequest.from(request);
      late final _Http2Connection connection;
      try {
        connection = await _connectionFor(prepared.url);
      } catch (_) {
        _setProtocol(ApiHttpProtocol.http1);
        return _fallback.send(prepared.toStreamedRequest());
      }
      try {
        return await _sendHttp2(prepared, connection);
      } catch (_) {
        _closeHttp2Connection(_connectionKey(prepared.url));
        rethrow;
      }
    }
    _setProtocol(ApiHttpProtocol.http1);
    return _fallback.send(request);
  }

  Future<http.StreamedResponse> _sendHttp2(
    _PreparedRequest request,
    _Http2Connection connection,
  ) async {
    final stream = connection.transport.makeRequest(
      _http2Headers(request, request.bodyBytes.length),
      endStream: request.bodyBytes.isEmpty,
    );
    if (request.bodyBytes.isNotEmpty) {
      stream.sendData(request.bodyBytes, endStream: true);
    }
    final response = await _readHttp2Response(stream, request);
    _setProtocol(ApiHttpProtocol.http2);
    return response;
  }

  Future<_Http2Connection> _connectionFor(Uri uri) async {
    final key = _connectionKey(uri);
    final existing = _http2Connections[key];
    if (existing != null && existing.transport.isOpen) {
      return existing;
    }
    _closeHttp2Connection(key);
    final socket = await SecureSocket.connect(
      uri.host,
      uri.port,
      onBadCertificate: (_) => true,
      supportedProtocols: const <String>['h2', 'http/1.1'],
      timeout: const Duration(seconds: 8),
    );
    if (socket.selectedProtocol != 'h2') {
      await socket.close();
      throw const _Http2UnavailableException();
    }
    final transport = h2.ClientTransportConnection.viaSocket(socket);
    final connection = _Http2Connection(transport);
    _http2Connections[key] = connection;
    return connection;
  }

  Future<http.StreamedResponse> _readHttp2Response(
    h2.ClientTransportStream stream,
    _PreparedRequest request,
  ) async {
    final headers = <String, String>{};
    final data = <List<int>>[];
    var statusCode = 200;
    await for (final message in stream.incomingMessages) {
      if (message is h2.HeadersStreamMessage) {
        for (final header in message.headers) {
          final name = utf8.decode(header.name).toLowerCase();
          final value = utf8.decode(header.value);
          if (name == ':status') {
            statusCode = int.tryParse(value) ?? statusCode;
          } else if (!name.startsWith(':')) {
            headers.update(
              name,
              (current) => '$current,$value',
              ifAbsent: () => value,
            );
          }
        }
      } else if (message is h2.DataStreamMessage) {
        data.add(message.bytes);
      }
    }
    final body = data.expand((chunk) => chunk).toList(growable: false);
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      statusCode,
      contentLength: body.length,
      request: request.toResponseRequest(),
      headers: headers,
      reasonPhrase: '',
      persistentConnection: true,
    );
  }

  List<h2.Header> _http2Headers(_PreparedRequest request, int bodyLength) {
    final uri = request.url;
    final path = uri.path.isEmpty ? '/' : uri.path;
    final queryPath = uri.query.isEmpty ? path : '$path?${uri.query}';
    final headers = <h2.Header>[
      _header(':method', request.method),
      _header(':path', queryPath),
      _header(':scheme', uri.scheme),
      _header(':authority', _authority(uri)),
    ];
    request.headers.forEach((name, value) {
      final lower = name.toLowerCase();
      if (lower == 'connection' ||
          lower == 'upgrade' ||
          lower == 'keep-alive' ||
          lower == 'proxy-connection' ||
          lower == 'transfer-encoding' ||
          lower == 'te' ||
          lower == 'host') {
        return;
      }
      headers.add(_header(lower, value));
    });
    if (bodyLength > 0 &&
        !request.headers.keys.any(
          (name) => name.toLowerCase() == 'content-length',
        )) {
      headers.add(_header('content-length', '$bodyLength'));
    }
    return headers;
  }

  h2.Header _header(String name, String value) {
    return h2.Header(utf8.encode(name.toLowerCase()), utf8.encode(value));
  }

  String _authority(Uri uri) {
    if (!uri.hasPort ||
        uri.port == HttpClient.defaultHttpsPort ||
        uri.port == HttpClient.defaultHttpPort) {
      return uri.host;
    }
    return '${uri.host}:${uri.port}';
  }

  String _connectionKey(Uri uri) => '${uri.scheme}://${_authority(uri)}';

  void _closeHttp2Connection(String key) {
    final connection = _http2Connections.remove(key);
    if (connection != null) {
      unawaited(connection.transport.terminate());
    }
  }

  void _setProtocol(ApiHttpProtocol protocol) {
    if (_lastProtocol == protocol) {
      return;
    }
    _lastProtocol = protocol;
    _onProtocolChanged?.call(protocol);
  }

  @override
  void close() {
    _closed = true;
    for (final connection in _http2Connections.values) {
      unawaited(connection.transport.terminate());
    }
    _http2Connections.clear();
    _fallback.close();
  }
}

class _PreparedRequest {
  const _PreparedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
    required this.followRedirects,
    required this.maxRedirects,
    required this.persistentConnection,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final bool followRedirects;
  final int maxRedirects;
  final bool persistentConnection;

  static Future<_PreparedRequest> from(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    return _PreparedRequest(
      method: request.method,
      url: request.url,
      headers: Map<String, String>.from(request.headers),
      bodyBytes: body,
      followRedirects: request.followRedirects,
      maxRedirects: request.maxRedirects,
      persistentConnection: request.persistentConnection,
    );
  }

  http.StreamedRequest toStreamedRequest() {
    final request = http.StreamedRequest(method, url)
      ..headers.addAll(headers)
      ..contentLength = bodyBytes.length
      ..followRedirects = followRedirects
      ..maxRedirects = maxRedirects
      ..persistentConnection = persistentConnection;
    request.sink.add(bodyBytes);
    unawaited(request.sink.close());
    return request;
  }

  http.BaseRequest toResponseRequest() {
    return http.Request(method, url)
      ..headers.addAll(headers)
      ..followRedirects = followRedirects
      ..maxRedirects = maxRedirects
      ..persistentConnection = persistentConnection;
  }
}

class _Http2Connection {
  const _Http2Connection(this.transport);

  final h2.ClientTransportConnection transport;
}

class _Http2UnavailableException implements Exception {
  const _Http2UnavailableException();
}
