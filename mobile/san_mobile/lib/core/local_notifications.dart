import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'san_high',
    'SAN Notifications',
    description: 'Smart Aid Navigator notifications',
    importance: Importance.high,
  );

  static Future<void> init() async {
    // Android init
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notification');

    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Create channel on Android 8+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'san_high',
      'SAN Notifications',
      channelDescription: 'Smart Aid Navigator notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notification',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
