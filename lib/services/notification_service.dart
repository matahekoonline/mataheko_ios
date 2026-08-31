// lib/services/notification_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
  NotificationService._();

  // ===========================================================================
  // FIREBASE
  // ===========================================================================

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Map<String, bool> _notificationSettings = {
    'enabled': true,
    'communityAlerts': true,
    'marketplace': true,
    'providerUpdates': true,
    'messages': true,
  };

  bool _settingsLoaded = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _adminActionSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deleteActionSub;
  bool _adminMonitorReady = false;

  // ===========================================================================
  // LOCAL NOTIFICATIONS
  // ===========================================================================

  final FlutterLocalNotificationsPlugin
  _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ===========================================================================
  // CHANNEL IDS
  // ===========================================================================

  static const String normalChannelId =
      'mataheko_normal_channel_v3';

  static const String adminChannelId =
      'mataheko_admin_channel_v3';

  // ===========================================================================
  // SOUND NAMES
  //
  // IMPORTANT:
  //
  // Android files:
  //
  // android/app/src/main/res/raw/notification.wav
  // android/app/src/main/res/raw/notify_admin.wav
  //
  // Flutter assets:
  //
  // assets/sounds/notification.wav
  // assets/sounds/notify_admin.wav
  //
  // Android references the files WITHOUT ".wav".
  // ===========================================================================

  static const String normalSound =
      'notification';

  static const String adminSound =
      'notify_admin';


  // ===========================================================================
  // ADMIN ACTION NOTIFICATIONS
  // ===========================================================================

  /// Sends an admin notification for an action that requires attention.
  ///
  /// This is a compatibility wrapper around the existing notifyAdmin()
  /// method so AccountScreen and other screens can use the same admin
  /// notification system.
  Future<void> notifyAdminAction({
    required String title,
    required String body,
    String category = 'admin_action',
    String? itemId,
  }) async {
    await notifyAdmin(
      title: title,
      body: body,
      category: category,
      itemId: itemId,
    );
  }

  // ===========================================================================
  // ANDROID CHANNELS
  // ===========================================================================

  static const AndroidNotificationChannel
  normalChannel =
  AndroidNotificationChannel(
    normalChannelId,
    'Mataheko Notifications',
    description:
    'General Mataheko marketplace notifications.',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(normalSound),
    audioAttributesUsage: AudioAttributesUsage.notification,
  );

  static const AndroidNotificationChannel
  adminChannel =
  AndroidNotificationChannel(
    adminChannelId,
    'Mataheko Admin Notifications',
    description:
    'Important administrator notifications.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(adminSound),
    audioAttributesUsage: AudioAttributesUsage.notification,
  );

  /// Re-opens the OS notification permission request from the Settings page.
  Future<void> requestNotificationPermissions() async {
    await _requestPermissions();
  }

  /// Returns the OS-level notification permission state where supported.
  /// Android 13+ can explicitly report whether this app may post notifications.
  Future<bool> areDeviceNotificationsEnabled() async {
    try {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }

      final ios = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final permissions = await ios.checkPermissions();
        return permissions?.isEnabled ?? true;
      }
    } catch (e) {
      debugPrint('[NotificationService] Permission status error: $e');
    }
    return true;
  }

  /// Requests notification permission and returns the resulting state.
  Future<bool> enableDeviceNotifications() async {
    await _requestPermissions();
    return areDeviceNotificationsEnabled();
  }

  /// Starts a client-side admin action monitor. This gives an admin an
  /// immediate local alert while the app is open, even when the action was
  /// created by another user. Real background/terminated-app push still
  /// requires the trusted server sender to consume `admin_notifications`.
  Future<void> startAdminActionMonitor() async {
    final user = _auth.currentUser;
    if (user == null || !await _checkIfAdmin(user.uid)) return;

    await stopAdminActionMonitor();
    _adminMonitorReady = false;

    _adminActionSub = _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!_adminMonitorReady || snap.docs.isEmpty) return;
      final d = snap.docs.first.data();
      if (d['read'] == true) return;
      showLocalNotification(
        title: d['title']?.toString() ?? 'Admin action required',
        body: d['body']?.toString() ?? 'A new action requires your attention.',
        type: 'admin',
      );
    });

    _deleteActionSub = _db
        .collection('account_deletion_requests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!_adminMonitorReady || snap.docs.isEmpty) return;
      final d = snap.docs.first.data();
      showLocalNotification(
        title: 'Account deletion request',
        body: '${d['displayName'] ?? 'A user'} requested account deletion.',
        type: 'admin',
      );
    });

    Future<void>.delayed(const Duration(seconds: 2), () {
      _adminMonitorReady = true;
    });
  }

  Future<void> stopAdminActionMonitor() async {
    await _adminActionSub?.cancel();
    await _deleteActionSub?.cancel();
    _adminActionSub = null;
    _deleteActionSub = null;
    _adminMonitorReady = false;
  }

  // ===========================================================================
  // USER NOTIFICATION SETTINGS
  // ===========================================================================

  Future<Map<String, bool>> loadNotificationSettings() async {
    final user = _auth.currentUser;
    if (user == null) return Map<String, bool>.from(_notificationSettings);

    try {
      final snap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();
      final data = snap.data() ?? {};
      for (final key in _notificationSettings.keys) {
        if (data[key] is bool) {
          _notificationSettings[key] = data[key] as bool;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Settings load error: $e');
    }

    _settingsLoaded = true;
    return Map<String, bool>.from(_notificationSettings);
  }

  Future<void> saveNotificationSettings(Map<String, bool> settings) async {
    final user = _auth.currentUser;
    _notificationSettings = {
      ..._notificationSettings,
      ...settings,
    };

    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('notifications')
        .set({
      ..._notificationSettings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _settingsLoaded = true;
  }

  Future<bool> notificationsEnabledForType(String type) async {
    if (!_settingsLoaded) await loadNotificationSettings();
    if (_notificationSettings['enabled'] != true) return false;

    final normalized = type.toLowerCase().trim();
    if (normalized.contains('alert') || normalized.contains('community')) {
      return _notificationSettings['communityAlerts'] != false;
    }
    if (normalized.contains('market')) {
      return _notificationSettings['marketplace'] != false;
    }
    if (normalized.contains('provider') || normalized.contains('verification')) {
      return _notificationSettings['providerUpdates'] != false;
    }
    if (normalized.contains('message') || normalized.contains('chat')) {
      return _notificationSettings['messages'] != false;
    }
    return true;
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> initialize() async {
    try {
      await _requestPermissions();

      await _initializeLocalNotifications();

      await _createNotificationChannels();

      await _configureFirebaseListeners();

      await _handleInitialMessage();

      if (_auth.currentUser != null) {
        await loadNotificationSettings();
      }

      await _printFCMToken();

      debugPrint(
        '[NotificationService] Initialized successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[NotificationService] Initialization error: $e',
      );
      debugPrint('$stackTrace');
    }
  }

  // ===========================================================================
  // PERMISSIONS
  // ===========================================================================

  Future<void> _requestPermissions() async {
    try {
      final settings =
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        '[NotificationService] Permission: '
            '${settings.authorizationStatus}',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Permission error: $e',
      );
    }

    // Android 13+
    try {
      final androidPlugin =
      _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] Android permission error: $e',
      );
    }
  }

  // ===========================================================================
  // LOCAL NOTIFICATION INITIALIZATION
  // ===========================================================================

  Future<void>
  _initializeLocalNotifications() async {
    const android =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const ios =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings =
    InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse:
      _onNotificationTapped,
    );
  }

  // ===========================================================================
  // CHANNEL CREATION
  // ===========================================================================

  Future<void>
  _createNotificationChannels() async {
    final androidPlugin =
    _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      return;
    }

    await androidPlugin
        .createNotificationChannel(
      normalChannel,
    );

    await androidPlugin
        .createNotificationChannel(
      adminChannel,
    );

    debugPrint(
      '[NotificationService] Notification channels created.',
    );
  }

  // ===========================================================================
  // FIREBASE MESSAGE LISTENERS
  // ===========================================================================

  Future<void>
  _configureFirebaseListeners() async {
    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );

    debugPrint(
      '[NotificationService] FCM listeners configured.',
    );
  }

  // ===========================================================================
  // TERMINATED APP MESSAGE
  // ===========================================================================

  Future<void>
  _handleInitialMessage() async {
    try {
      final message =
      await _messaging.getInitialMessage();

      if (message != null) {
        debugPrint(
          '[NotificationService] '
              'App opened from notification.',
        );

        _handleOpenedMessage(message);
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] Initial message error: $e',
      );
    }
  }

  // ===========================================================================
  // FOREGROUND MESSAGE
  // ===========================================================================

  Future<void>
  _handleForegroundMessage(
      RemoteMessage message,
      ) async {
    debugPrint(
      '[NotificationService] Foreground message: '
          '${message.messageId}',
    );

    await showNotification(message);
  }

  // ===========================================================================
  // NOTIFICATION OPENED
  // ===========================================================================

  void _handleOpenedMessage(
      RemoteMessage message,
      ) {
    debugPrint(
      '[NotificationService] Notification opened.',
    );

    debugPrint(
      '[NotificationService] Data: ${message.data}',
    );

    final type =
        message.data['type']?.toString() ??
            'normal';

    final itemId =
    message.data['itemId']?.toString();

    debugPrint(
      '[NotificationService] Type: $type',
    );

    debugPrint(
      '[NotificationService] Item ID: $itemId',
    );

    // -------------------------------------------------------------------------
    // NAVIGATION
    // -------------------------------------------------------------------------
    //
    // We deliberately don't navigate from this service because your current
    // app does not expose a global NavigatorKey.
    //
    // When you are ready, we can add:
    //
    // normal -> notification list
    // admin -> admin dashboard
    // provider -> provider application
    // enquiry -> enquiry/chat
    // message -> chat
    //
    // without breaking the notification system.
    // -------------------------------------------------------------------------
  }

  // ===========================================================================
  // SHOW FIREBASE NOTIFICATION
  // ===========================================================================

  Future<void> showNotification(
      RemoteMessage message,
      ) async {
    final title =
        message.notification?.title ??
            message.data['title']?.toString() ??
            'Mataheko';

    final body =
        message.notification?.body ??
            message.data['body']?.toString() ??
            '';

    final type =
        message.data['type']
            ?.toString()
            .toLowerCase() ??
            'normal';

    final isAdmin =
    _isAdminNotification(type);

    if (!isAdmin && !await notificationsEnabledForType(type)) {
      debugPrint('[NotificationService] Notification suppressed by user settings: $type');
      return;
    }

    await _showNotification(
      title: title,
      body: body,
      type: type,
      payload: message.data,
      isAdmin: isAdmin,
    );
  }

  // ===========================================================================
  // MANUAL LOCAL NOTIFICATION
  // ===========================================================================

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String type = 'normal',
    Map<String, dynamic>? data,
  }) async {
    final isAdmin =
    _isAdminNotification(type);

    if (!isAdmin && !await notificationsEnabledForType(type)) {
      return;
    }

    await _showNotification(
      title: title,
      body: body,
      type: type,
      payload: data,
      isAdmin: isAdmin,
    );
  }

  // ===========================================================================
  // ACTUAL LOCAL NOTIFICATION
  // ===========================================================================

  Future<void> _showNotification({
    required String title,
    required String body,
    required String type,
    required bool isAdmin,
    Map<String, dynamic>? payload,
  }) async {
    final notificationId =
    DateTime.now()
        .millisecondsSinceEpoch
        .remainder(2147483647);

    final androidDetails =
    AndroidNotificationDetails(
      isAdmin
          ? adminChannelId
          : normalChannelId,

      isAdmin
          ? 'Mataheko Admin Notifications'
          : 'Mataheko Notifications',

      channelDescription: isAdmin
          ? 'Important administrator notifications.'
          : 'General Mataheko marketplace notifications.',

      importance: isAdmin
          ? Importance.max
          : Importance.high,

      priority: isAdmin
          ? Priority.max
          : Priority.high,

      playSound: true,

      sound: RawResourceAndroidNotificationSound(
        isAdmin ? adminSound : normalSound,
      ),

      audioAttributesUsage: AudioAttributesUsage.notification,

      icon: '@mipmap/ic_launcher',

      autoCancel: true,

      enableVibration: true,

      category: isAdmin
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.message,

      visibility:
      NotificationVisibility.public,
    );

    final iosDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,

      // -----------------------------------------------------------------------
      // IMPORTANT:
      //
      // For iOS, the WAV files must also be copied into the iOS Runner bundle
      // and the actual filename including extension is required here.
      //
      // We use the normal sound by default.
      // Admin sound is selected below.
      // -----------------------------------------------------------------------
      sound: isAdmin
          ? 'notify_admin.wav'
          : 'notification.wav',
    );

    final details =
    NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String? encodedPayload;

    if (payload != null) {
      try {
        encodedPayload =
            jsonEncode(payload);
      } catch (e) {
        debugPrint(
          '[NotificationService] '
              'Payload encode error: $e',
        );
      }
    }

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: encodedPayload,
    );

    debugPrint(
      '[NotificationService] Notification shown: '
          '$title',
    );

    debugPrint(
      '[NotificationService] Sound: '
          '${isAdmin ? adminSound : normalSound}',
    );
  }

  // ===========================================================================
  // NOTIFICATION TAP
  // ===========================================================================

  void _onNotificationTapped(
      NotificationResponse response,
      ) {
    final payload =
        response.payload;

    if (payload == null ||
        payload.trim().isEmpty) {
      return;
    }

    try {
      final data =
      jsonDecode(payload);

      debugPrint(
        '[NotificationService] '
            'Local notification tapped: $data',
      );

      if (data is Map) {
        final type =
        data['type']?.toString();

        final itemId =
        data['itemId']?.toString();

        debugPrint(
          '[NotificationService] '
              'Tapped type: $type',
        );

        debugPrint(
          '[NotificationService] '
              'Tapped item: $itemId',
        );
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Notification payload error: $e',
      );
    }
  }

  // ===========================================================================
  // ADMIN DEVICE TOKEN
  //
  // main.dart already calls:
  //
  // NotificationService.instance.registerAdminDeviceToken();
  //
  // This method therefore MUST exist.
  // ===========================================================================

  Future<void>
  registerAdminDeviceToken() async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        debugPrint(
          '[NotificationService] '
              'No signed-in user. Admin token not registered.',
        );
        return;
      }

      final isAdmin =
      await _checkIfAdmin(user.uid);

      if (!isAdmin) {
        debugPrint(
          '[NotificationService] '
              'Current user is not an admin.',
        );
        return;
      }

      // On iOS, FCM's token depends on APNs registration. Waiting briefly
      // for the APNs token avoids a race during cold start while still
      // guaranteeing that notification setup cannot hang forever.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _messaging
              .getAPNSToken()
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint(
            '[NotificationService] APNs token not ready yet: $e',
          );
        }
      }

      final token =
      await _messaging
          .getToken()
          .timeout(const Duration(seconds: 8));

      if (token == null ||
          token.trim().isEmpty) {
        debugPrint(
          '[NotificationService] '
              'FCM token unavailable.',
        );
        return;
      }

      // -----------------------------------------------------------------------
      // Store the current admin device token.
      // -----------------------------------------------------------------------

      await _db
          .collection('admin_devices')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'fcmToken': token,
          'platform': defaultTargetPlatform.name,
          'active': true,
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint(
        '[NotificationService] '
            'Admin device token registered.',
      );

      // -----------------------------------------------------------------------
      // Token refresh
      // -----------------------------------------------------------------------

      FirebaseMessaging.instance
          .onTokenRefresh
          .listen(
            (newToken) async {
          try {
            await _db
                .collection('admin_devices')
                .doc(user.uid)
                .set(
              {
                'uid': user.uid,
                'fcmToken': newToken,
                'platform':
                defaultTargetPlatform.name,
                'active': true,
                'updatedAt':
                FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );

            debugPrint(
              '[NotificationService] '
                  'Admin FCM token refreshed.',
            );
          } catch (e) {
            debugPrint(
              '[NotificationService] '
                  'Admin token refresh error: $e',
            );
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[NotificationService] '
            'Register admin token error: $e',
      );
      debugPrint('$stackTrace');
    }
  }

  // ===========================================================================
  // CHECK ADMIN
  // ===========================================================================

  Future<bool> _checkIfAdmin(
      String uid,
      ) async {
    try {
      final userDoc =
      await _db
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        return false;
      }

      final data =
      userDoc.data();

      if (data == null) {
        return false;
      }

      // Support the different admin flags that may already exist in the app.
      if (data['isAdmin'] == true) {
        return true;
      }

      if (data['admin'] == true) {
        return true;
      }

      if (data['role']
          ?.toString()
          .toLowerCase() ==
          'admin') {
        return true;
      }

      if (data['userRole']
          ?.toString()
          .toLowerCase() ==
          'admin') {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Admin check error: $e',
      );

      return false;
    }
  }

  // ===========================================================================
  // NOTIFY ADMIN
  //
  // Your existing AuthService already calls:
  //
  // NotificationService.notifyAdmin(...)
  //
  // This method records the notification request in Firestore.
  //
  // Your server/PHP notification sender can use this record to send the
  // actual FCM push to the registered admin device token.
  //
  // ===========================================================================

  static Future<void> notifyAdmin({
    required String title,
    required String body,
    required String category,
    String? itemId,
  }) async {
    try {
      final db =
          FirebaseFirestore.instance;

      await db
          .collection('admin_notifications')
          .add(
        {
          'title': title,
          'body': body,
          'category': category,
          'itemId': itemId,
          'type': 'admin',

          'read': false,

          'createdAt':
          FieldValue.serverTimestamp(),
        },
      );

      debugPrint(
        '[NotificationService] '
            'Admin notification created: $title',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'notifyAdmin error: $e',
      );
    }
  }

  // ===========================================================================
  // FCM TOKEN
  // ===========================================================================

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Get FCM token error: $e',
      );

      return null;
    }
  }

  Future<void> _printFCMToken() async {
    final token =
    await getToken().timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );

    if (token == null) {
      return;
    }

    debugPrint(
      '================================================',
    );

    debugPrint(
      'MATAHEKO FCM TOKEN',
    );

    debugPrint(token);

    debugPrint(
      '================================================',
    );
  }

  // ===========================================================================
  // TOPICS
  // ===========================================================================

  Future<void> subscribeToAdmin() async {
    try {
      await _messaging
          .subscribeToTopic('admin');

      debugPrint(
        '[NotificationService] '
            'Subscribed to admin topic.',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Admin topic error: $e',
      );
    }
  }

  Future<void> unsubscribeFromAdmin()
  async {
    try {
      await _messaging
          .unsubscribeFromTopic('admin');
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Unsubscribe admin error: $e',
      );
    }
  }

  Future<void> subscribeToProviders()
  async {
    try {
      await _messaging
          .subscribeToTopic('providers');

      debugPrint(
        '[NotificationService] '
            'Subscribed to providers topic.',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Provider topic error: $e',
      );
    }
  }

  Future<void> unsubscribeFromProviders()
  async {
    try {
      await _messaging
          .unsubscribeFromTopic('providers');
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Unsubscribe providers error: $e',
      );
    }
  }

  // ===========================================================================
  // REMOVE ADMIN DEVICE
  // ===========================================================================

  Future<void>
  unregisterAdminDeviceToken() async {
    try {
      final user =
          _auth.currentUser;

      if (user == null) {
        return;
      }

      await _db
          .collection('admin_devices')
          .doc(user.uid)
          .set(
        {
          'active': false,
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] '
            'Unregister admin token error: $e',
      );
    }
  }

  // ===========================================================================
  // ADMIN / NORMAL TYPE DETECTION
  // ===========================================================================

  bool _isAdminNotification(
      String type,
      ) {
    final normalized =
    type.toLowerCase().trim();

    return normalized == 'admin' ||
        normalized == 'admin_notification' ||
        normalized == 'new_user' ||
        normalized == 'provider_registration' ||
        normalized == 'provider_application' ||
        normalized == 'verification';
  }

  // ===========================================================================
  // CLEAR ALL LOCAL NOTIFICATIONS
  // ===========================================================================

  Future<void>
  cancelAllNotifications() async {
    await _localNotifications
        .cancelAll();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  Future<void> dispose() async {
    await cancelAllNotifications();
  }
}

// =============================================================================
// FIREBASE BACKGROUND MESSAGE HANDLER
//
// IMPORTANT:
//
// Do NOT manually call showNotification() here for a normal FCM message that
// already contains a "notification" payload.
//
// Android/iOS will display notification-payload messages themselves when the
// app is backgrounded/closed.
//
// If you use DATA-ONLY FCM messages, the server must supply the notification
// configuration appropriately, or we can add a dedicated background-local
// notification implementation.
// =============================================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Notification-payload messages are normally displayed by Android/iOS
    // while the app is backgrounded. Data-only messages need a local
    // notification here so they also produce a sound.
    if (message.notification == null && message.data.isNotEmpty) {
      final plugin = FlutterLocalNotificationsPlugin();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await plugin.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      const channel = AndroidNotificationChannel(
        NotificationService.normalChannelId,
        'Mataheko Notifications',
        description: 'General Mataheko marketplace notifications.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(
          NotificationService.normalSound,
        ),
        audioAttributesUsage: AudioAttributesUsage.notification,
      );

      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(channel);
      }

      final title =
          message.data['title']?.toString() ?? 'Mataheko notification';
      final body = message.data['body']?.toString() ?? 'You have a new update.';

      await plugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationService.normalChannelId,
            'Mataheko Notifications',
            channelDescription:
                'General Mataheko marketplace notifications.',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
              NotificationService.normalSound,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  } catch (e, stack) {
    debugPrint('[NotificationService] Background handler error: $e');
    debugPrint('$stack');
  }
}
