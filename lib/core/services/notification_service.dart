// lib/core/services/notification_service.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false);

    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        // Handle notification tapped logic here
        debugPrint('Notification clicked: ${notificationResponse.payload}');
      },
    );

    await requestPermission();
  }

  Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> showLowStockNotification(String menuName, int remainingStock) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'stock_alert_channel',
      'Peringatan Stok',
      channelDescription: 'Notifikasi saat stok barang hampir habis',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFFFF9800), // Orange
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails();
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iosPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond, // Unique ID
      title: '⚠️ Peringatan Stok Menipis',
      body: 'Stok untuk menu "$menuName" tersisa $remainingStock porsi!',
      notificationDetails: platformChannelSpecifics,
      payload: 'low_stock',
    );
  }

  Future<void> showShiftNotification(String kasirName, String action) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'shift_alert_channel',
      'Peringatan Shift',
      channelDescription: 'Notifikasi saat kasir membuka atau menutup shift',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFF2196F3), // Blue
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails();
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iosPlatformChannelSpecifics);

    final title = action == 'open' ? '🟢 Shift Dibuka' : '🔴 Shift Ditutup';
    final body = action == 'open' 
        ? 'Kasir $kasirName telah memulai shift.' 
        : 'Kasir $kasirName telah mengakhiri shift.';

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond + 1, // Unique ID
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'shift_status',
    );
  }
  Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'general_alert_channel',
      'Pemberitahuan Umum',
      channelDescription: 'Notifikasi umum sistem kasir',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFF2196F3),
      icon: '@mipmap/ic_launcher',
    );
    const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails();
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iosPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond + 2,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'general_notification',
    );
  }
}
