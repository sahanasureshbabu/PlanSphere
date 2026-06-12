import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/bill_model.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createNotificationChannels();
    await _setupFCM();
  }

  Future<void> _createNotificationChannels() async {
    const warrantyChannel = AndroidNotificationChannel(
      AppConstants.warrantyChannelId,
      AppConstants.warrantyChannelName,
      description: 'Warranty expiry reminders',
      importance: Importance.high,
    );

    const documentChannel = AndroidNotificationChannel(
      AppConstants.documentChannelId,
      AppConstants.documentChannelName,
      description: 'Document expiry reminders',
      importance: Importance.defaultImportance,
    );

    const backupChannel = AndroidNotificationChannel(
      AppConstants.backupChannelId,
      AppConstants.backupChannelName,
      description: 'Cloud backup reminders',
      importance: Importance.low,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(warrantyChannel);
    await androidPlugin?.createNotificationChannel(documentChannel);
    await androidPlugin?.createNotificationChannel(backupChannel);
  }

  Future<void> _setupFCM() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _fcm.getToken();

    if (kDebugMode) {
      print('FCM Token: $token');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showFCMNotification(message);
    });
  }

  Future<void> _showFCMNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.warrantyChannelId,
          AppConstants.warrantyChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  Future<void> scheduleWarrantyReminders(BillModel bill) async {
    if (!bill.hasWarranty || bill.warrantyExpiryDate == null) {
      return;
    }

    for (final days in AppConstants.warrantyReminderDays) {
      final reminderDate = bill.warrantyExpiryDate!
          .subtract(Duration(days: days))
          .copyWith(hour: 9, minute: 0, second: 0);

      if (reminderDate.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: _generateNotificationId(bill.id, days),
          title: 'Warranty Expiring Soon!',
          body:
              '${bill.title} warranty expires in $days days on ${_formatDate(bill.warrantyExpiryDate!)}',
          scheduledDate: reminderDate,
          channelId: AppConstants.warrantyChannelId,
          channelName: AppConstants.warrantyChannelName,
          payload: 'warranty:${bill.id}',
        );
      }
    }
  }

  Future<void> cancelWarrantyReminders(String billId) async {
    for (final days in AppConstants.warrantyReminderDays) {
      await _localNotifications.cancel(
        _generateNotificationId(billId, days),
      );
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String channelId = AppConstants.warrantyChannelId,
    String channelName = AppConstants.warrantyChannelName,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> scheduleBackupReminder() async {
    final scheduledDate =
        DateTime.now().add(const Duration(days: 7));

    await _scheduleNotification(
      id: 99999,
      title: 'Backup Reminder',
      body:
          'Your PlanSphere data hasn\'t been backed up recently. Tap to backup now.',
      scheduledDate: scheduledDate.copyWith(
        hour: 10,
        minute: 0,
      ),
      channelId: AppConstants.backupChannelId,
      channelName: AppConstants.backupChannelName,
      payload: 'backup',
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      ),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  int _generateNotificationId(
    String billId,
    int days,
  ) {
    return '${billId.hashCode}$days'
            .hashCode
            .abs() %
        100000;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}