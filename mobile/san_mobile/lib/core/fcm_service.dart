import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';


import '../core/dio_client.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'san_channel',
      'SAN Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      details,
    );
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _messaging.requestPermission();

      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        debugPrint('Notification permission: $status');
      }

      // Get token
      final token = await _messaging.getToken();
      debugPrint('FCM TOKEN = $token');
      if (token != null) {
        debugPrint('FCM TOKEN = $token');
      }

      // Token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM token refreshed: $newToken');
      });

      // Foreground messages (app open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final title = message.notification?.title ?? 'SAN';
        final body = message.notification?.body ?? 'You have a new notification';

        debugPrint('FCM Foreground: $title - $body');

        // Show UI notification banner
        await LocalNotifications.show(title: title, body: body);
      });


      // When notification opened (tap)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Opened: ${message.data}');
      });
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
  }

  static Future<void> _registerTokenToServer(String token) async {
    try {
      final dio = DioClient.create();

      await dio.post(
        '/device-tokens/register',
        data: {
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'unknown',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('FCM token registration skipped: $e');
    }
  }
}
