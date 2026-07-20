// FILE PATH: lib/services/notification_service.dart

// Handles:
// 1. Requesting notification permission + getting the device's FCM token
// 2. Saving that token to your PHP host (save_admin_token.php) when the
//    signed-in user is an admin
// 3. Showing a local notification WITH SOUND when a push arrives while
//    the app is in the foreground (FCM pushes don't auto-display while
//    foregrounded on Android -- this is why flutter_local_notifications
//    is needed alongside firebase_messaging)
//


import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const String _apiKey = 'f248b9ecd1705a36';
const String _baseUrl = 'https://seghansoccertraining.org/mataheko';

/// Must be a top-level (or static) function -- this is how Firebase
/// requires background message handlers to be registered. Called when a
/// push arrives while the app is fully terminated or backgrounded.
/// Android/iOS show the system notification automatically in this case,
/// so this handler just needs to exist; it doesn't need to do anything
/// unless you want to log/react to background messages specifically.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the OS shows the notification automatically when backgrounded.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'admin_alerts', // must match the channel_id sent from notify_admin.php
    'Admin Alerts',
    description: 'Notifications for actions needing admin approval',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize() async {
    // Register the background handler (safe to call multiple times).
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up local notifications (used only for the foreground case).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    // Ask for permission (Android 13+ requires this explicitly; iOS always does).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages don't auto-display -- show them manually with sound.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    });
  }

  /// Call this right after confirming the signed-in user isAdmin == true
  /// (e.g. in your admin dashboard's initState, alongside the existing
  /// _loadAdminStatus() pattern used across the provider list screens).
  Future<void> registerAdminDeviceToken() async {
    try {
      final isAdmin = await AuthService.instance.isAdmin();
      if (!isAdmin) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('$_baseUrl/save_admin_token.php'),
        body: {'api_key': _apiKey, 'fcm_token': token},
      );

      // Keep it updated if the token ever refreshes while the admin has
      // the app installed (this can happen periodically per FCM's docs).
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await http.post(
          Uri.parse('$_baseUrl/save_admin_token.php'),
          body: {'api_key': _apiKey, 'fcm_token': newToken},
        );
      });
    } catch (e) {
      // Best-effort -- don't let a notification setup failure block admin
      // login or any other flow.
      // ignore: avoid_print
      print('[NotificationService] Could not register admin device token: $e');
    }
  }

  /// Fire-and-forget push to the admin. Called from AuthService after any
  /// self-registration (registerAsMechanic, registerAsWelder, etc.) or new
  /// user signup. Deliberately swallows errors -- a failed notification
  /// should never block the actual registration/signup the user is doing.
  static Future<void> notifyAdmin({
    required String title,
    required String body,
    String? category,
    String? itemId,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/notify_admin.php'),
        body: {
          'api_key': _apiKey,
          'title': title,
          'body': body,
          if (category != null) 'category': category,
          if (itemId != null) 'itemId': itemId,
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('[NotificationService] notifyAdmin failed (non-fatal): $e');
    }
  }
}
