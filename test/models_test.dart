import 'package:flutter_test/flutter_test.dart';

import 'package:csac/src/api_client.dart';
import 'package:csac/src/models.dart';
import 'package:csac/src/update_checker.dart';

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

  test('message accepts read status aliases', () {
    final readByStatus = ChatMessage.fromJson({
      'id': 15,
      'from_uid': 4,
      'nickname': 'Leon',
      'content': 'hello',
      'read_status': 1,
    });
    final readByTime = ChatMessage.fromJson({
      'id': 16,
      'from_uid': 4,
      'nickname': 'Leon',
      'content': 'hello',
      'read_at': '2026-05-30 12:00:00',
    });

    expect(readByStatus.isRead, isTrue);
    expect(readByTime.isRead, isTrue);
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

  test('release version tags match app versions', () {
    expect(
      VersionUpdateChecker.versionMatches('1.2.5+46', 'v1.2.5-46'),
      isTrue,
    );
    expect(
      VersionUpdateChecker.versionMatches('1.2.5+46', 'refs/tags/v1.2.5-46'),
      isTrue,
    );
    expect(VersionUpdateChecker.versionMatches('1.2.5', 'v1.2.5'), isTrue);
    expect(
      VersionUpdateChecker.versionMatches('1.2.5+46', 'v1.2.6-1'),
      isFalse,
    );
  });

  test('release version display normalizes action tags', () {
    expect(VersionUpdateChecker.displayVersion('v1.2.5-46'), '1.2.5-46');
    expect(
      VersionUpdateChecker.displayVersion('refs/tags/v1.2.5-46'),
      '1.2.5-46',
    );
    expect(VersionUpdateChecker.displayVersion('1.2.5+46'), '1.2.5-46');
    expect(VersionUpdateChecker.displayVersion('1.3.0+50'), '1.3.0-50');
  });
}
