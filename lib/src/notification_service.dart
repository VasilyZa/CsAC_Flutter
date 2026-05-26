import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';

class CsacNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  static const _channelId = 'csac_messages';
  static const _channelName = 'CsAC messages';
  static const _channelDescription = 'Chat message notifications';

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) {
      return;
    }
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    _initialized = true;
  }

  Future<void> requestPermissionIfNeeded() async {
    if (_permissionRequested || kIsWeb || !Platform.isAndroid) {
      return;
    }
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    _permissionRequested = true;
  }

  Future<void> showMessageNotification({
    required Conversation conversation,
    required int unreadDelta,
  }) async {
    if (kIsWeb || !Platform.isAndroid || unreadDelta <= 0) {
      return;
    }
    await initialize();
    await requestPermissionIfNeeded();
    final title = conversation.name;
    final body = unreadDelta == 1 ? '收到 1 条新消息' : '收到 $unreadDelta 条新消息';
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
    );
    await _plugin.show(
      id: _notificationId(conversation),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: '${conversation.type.name}:${conversation.id}',
    );
  }

  int _notificationId(Conversation conversation) {
    final typeOffset = conversation.type == ConversationType.group ? 100000 : 0;
    return typeOffset + conversation.id;
  }
}
