import 'package:http/http.dart' as http;

import '../api_protocol.dart';

ProtocolAwareHttpClient createApiHttpClient() {
  return _ProtocolAwareWebClient(http.Client());
}

class _ProtocolAwareWebClient extends http.BaseClient
    implements ProtocolAwareHttpClient {
  _ProtocolAwareWebClient(this._inner);

  final http.Client _inner;
  ApiProtocolChanged? _onProtocolChanged;
  ApiHttpProtocol _lastProtocol = ApiHttpProtocol.browser;

  @override
  ApiHttpProtocol get lastProtocol => _lastProtocol;

  @override
  set onProtocolChanged(ApiProtocolChanged? callback) {
    _onProtocolChanged = callback;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_lastProtocol != ApiHttpProtocol.browser) {
      _lastProtocol = ApiHttpProtocol.browser;
      _onProtocolChanged?.call(_lastProtocol);
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
