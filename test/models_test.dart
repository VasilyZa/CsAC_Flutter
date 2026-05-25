import 'package:flutter_test/flutter_test.dart';

import 'package:csac/src/api_client.dart';
import 'package:csac/src/models.dart';

void main() {
  test('message accepts numeric zero timestamps', () {
    final message = ChatMessage.fromJson({
      'id': 14,
      'uid': 4,
      'nickname': 'Wansheng',
      'content': 'hello',
      'add_time': '2026-04-29 18:48:35',
      'created_at': 0,
    });

    expect(message.id, 14);
    expect(message.senderId, 4);
    expect(message.time, '2026-04-29 18:48:35');
  });

  test('friend display name prefers remark', () {
    final friend = Friend.fromJson({
      'uid': 25,
      'friend_id': 25,
      'nickname': 'Leon',
      'remark': 'Work',
      'unread_count': 3,
    });

    expect(friend.name, 'Work');
    expect(friend.unreadCount, 3);
  });

  test('server URL accepts bare host and host with port', () {
    expect(
      CsacApiClient.normalizeServerUrl('192.168.1.10'),
      'http://192.168.1.10/rpc/UniCsAC.php',
    );
    expect(
      CsacApiClient.normalizeServerUrl('192.168.1.10:8080'),
      'http://192.168.1.10:8080/rpc/UniCsAC.php',
    );
  });

  test('relative media URLs follow configured API origin', () {
    configureApiAssetBaseUrl('http://192.168.1.10:8080/rpc/UniCsAC.php');

    expect(
      normalizeApiUrl('/uploads/avatar.png'),
      'http://192.168.1.10:8080/uploads/avatar.png',
    );

    configureApiAssetBaseUrl(CsacApiClient.defaultBaseUrl);
  });
}
