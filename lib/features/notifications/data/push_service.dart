import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../domain/push_payload.dart';
import '../domain/push_session_coordinator.dart';

const pushNotificationChannelId = 'fcourt_notifications';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushService {
  PushService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  static const _platform = MethodChannel('com.bro73.fcourt/push');
  final StreamController<PushPayload> _payloads =
      StreamController<PushPayload>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Stream<PushPayload> get payloads => _payloads.stream;

  // The replacement API (register()/onRegistered) yields a Firebase
  // Installation ID for direct send, not the FCM registration token our
  // backend (SNS) endpoints are created from, so getToken/onTokenRefresh stay.
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  Future<void> initialize(PushSessionCoordinator coordinator) async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _createChannel();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // ignore: deprecated_member_use
    _tokenSubscription = _messaging.onTokenRefresh.listen((_) {
      coordinator.onTokenRefresh();
    });
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _payloads.add(
        PushPayload.fromMap(
          message.data,
          title: message.notification?.title,
          body: message.notification?.body,
          foreground: true,
        ),
      ),
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _emit(message.data),
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _emit(initial.data);
  }

  Future<void> _createChannel() async {
    await _platform.invokeMethod<void>('createNotificationChannel');
  }

  void _emit(Map<String, dynamic> data) {
    _payloads.add(PushPayload.fromMap(data));
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _payloads.close();
  }
}
