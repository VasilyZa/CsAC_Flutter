import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';

class CsacLocalNotificationService {
  CsacLocalNotificationService._();

  static final instance = CsacLocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<Conversation>.broadcast();
  bool _initialized = false;
  bool _permissionRequested = false;
  int _nextNotificationId = 1000;

  Stream<Conversation> get taps => _tapController.stream;

  bool get isSupported {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.windows => true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => false,
    };
  }

  Future<void> initialize() async {
    if (_initialized || !isSupported) {
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const windows = WindowsInitializationSettings(
      appName: 'CsAC',
      appUserModelId: 'ink.jjmm.csacflutter.csac',
      guid: 'a6201f5f-6117-493c-b0a0-1cc73276e2a7',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: ios,
      windows: windows,
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
      _initialized = true;
    } catch (err, stackTrace) {
      if (err.toString().startsWith('LateInitializationError:') &&
          stackTrace.toString().contains('FlutterLocalNotificationsPlatform')) {
        return;
      }
      debugPrint('CsAC local notification init failed: $err');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> ensurePermissions() async {
    if (!isSupported) {
      return false;
    }
    await initialize();
    if (_permissionRequested) {
      return true;
    }
    _permissionRequested = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await plugin?.requestNotificationsPermission() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final plugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await plugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  Future<void> showConversationNotification({
    required Conversation conversation,
    required int newCount,
  }) async {
    if (!isSupported || newCount <= 0) {
      return;
    }
    try {
      final permitted = await ensurePermissions();
      if (!permitted) {
        return;
      }
      final countText = newCount > 99 ? '99+' : '$newCount';
      final title = conversation.name.trim().isEmpty
          ? 'CsAC'
          : conversation.name;
      final body = conversation.subtitle.trim().isEmpty
          ? '$countText new message${newCount == 1 ? '' : 's'}'
          : conversation.subtitle.trim();
      await _plugin.show(
        id: _nextNotificationId++,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(conversation),
        payload: _payloadFor(conversation),
      );
    } catch (err, stackTrace) {
      debugPrint('CsAC local notification show failed: $err');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  NotificationDetails _notificationDetails(Conversation conversation) {
    final android = AndroidNotificationDetails(
      'csac_messages',
      'CsAC messages',
      channelDescription: 'Message notifications from CsAC',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      channelShowBadge: true,
      groupKey: 'csac_messages',
      ticker: conversation.name,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const windows = WindowsNotificationDetails();
    return NotificationDetails(android: android, iOS: ios, windows: windows);
  }

  String _payloadFor(Conversation conversation) {
    return '${conversation.type.name}:${conversation.id}';
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final conversation = _conversationFromPayload(response.payload);
    if (conversation != null) {
      _tapController.add(conversation);
    }
  }

  Conversation? _conversationFromPayload(String? payload) {
    final parts = (payload ?? '').split(':');
    if (parts.length != 2) {
      return null;
    }
    final id = int.tryParse(parts[1]) ?? 0;
    if (id <= 0) {
      return null;
    }
    final type = parts[0] == ConversationType.group.name
        ? ConversationType.group
        : parts[0] == ConversationType.private.name
        ? ConversationType.private
        : null;
    if (type == null) {
      return null;
    }
    return Conversation(type: type, id: id, name: '');
  }

  void dispose() {
    _tapController.close();
  }
}
