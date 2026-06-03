import 'package:http/http.dart' as http;

enum ApiHttpProtocol { unknown, http1, http2, browser }

typedef ApiProtocolChanged = void Function(ApiHttpProtocol protocol);

String apiHttpProtocolLabel(ApiHttpProtocol protocol) {
  return switch (protocol) {
    ApiHttpProtocol.http2 => 'HTTP/2',
    ApiHttpProtocol.http1 => 'HTTP/1.1',
    ApiHttpProtocol.browser => 'Browser managed',
    ApiHttpProtocol.unknown => 'Unknown',
  };
}

abstract class ProtocolAwareHttpClient extends http.BaseClient {
  ApiHttpProtocol get lastProtocol;
  set onProtocolChanged(ApiProtocolChanged? callback);
}
