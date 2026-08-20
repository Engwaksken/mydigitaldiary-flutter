import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import 'api_client.dart';

/// Handles both push notifications and on-device reminder alarms.
///
/// Local reminder alarms are deliberately independent from Firebase and from
/// the signed-in UI. Once a reminder has been synced to the device, Android/iOS
/// owns the schedule, so it can alert while the app is backgrounded,
/// terminated, or sitting on the login screen.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _deviceIdKey = 'device_id';
  static const _reminderChannelId = 'reminders_v2';
  static const _maxScheduledSlotsPerReminder = 48;

  bool _localInitialized = false;
  bool _pushInitialized = false;

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _reminderChannelId,
      'Reminders',
      channelDescription: 'My Digital Diary reminder alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Must be called even when Firebase is not configured. This is what makes
  /// scheduled reminders work without requiring the user to open/log in at
  /// reminder time.
  Future<void> initializeLocalNotifications() async {
    if (_localInitialized) return;

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) async {
        await _handleNotificationPayload(response.payload);
      },
    );

    // Android 13+ requires runtime notification permission. Older Android
    // versions simply return null/no-op here.
    try {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          'Reminders',
          description: 'My Digital Diary reminder alerts',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (_) {
      // Exact-alarm permission can be denied. Scheduling falls back safely.
    }

    _localInitialized = true;
  }

  /// Call only after Firebase.initializeApp() succeeds.
  Future<void> initializePushNotifications() async {
    if (_pushInitialized) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((message) async {
      // FCM may deliver either a notification payload or a data-only payload.
      // Previously data-only messages were silently ignored while the app was
      // open, which made reminders look unreliable. Always turn either form
      // into a visible local heads-up notification.
      final notification = message.notification;
      final title = notification?.title ??
          message.data['title']?.toString() ??
          (message.data['type'] == 'daily_planner'
              ? 'Daily Planner reminder'
              : 'My Digital Diary reminder');
      final body = notification?.body ??
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          'You have an upcoming item in My Digital Diary.';

      await initializeLocalNotifications();
      await _localNotifications.show(
        message.hashCode & 0x7fffffff,
        title,
        body,
        _reminderDetails,
        payload: _payloadFromPushData(message.data),
      );
    });

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _markPushAsRead(message.data);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _markPushAsRead(initialMessage.data);
    }

    messaging.onTokenRefresh.listen((_) => registerDeviceToken());
    _pushInitialized = true;

    // Fix the login/Firebase race: if login completed before Firebase was ready,
    // register the token now instead of waiting for a future token rotation.
    await registerDeviceToken();
  }

  Future<void> showReminderAlarm(int id, String title, String? body) async {
    await initializeLocalNotifications();
    await _localNotifications.show(id, title, body, _reminderDetails, payload: 'reminder:$id');
  }

  /// Rebuilds the local schedules from reminders returned by the API.
  Future<void> syncReminderSchedules(List<Reminder> reminders) async {
    await initializeLocalNotifications();
    for (final reminder in reminders) {
      await scheduleReminder(reminder);
    }
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    await initializeLocalNotifications();
    await cancelReminder(reminder.id);

    if (!reminder.isActive || !reminder.alarmEnabled) return;

    // `nextRunAt` is the actual due time. User-facing alarms start only
    // in the 30-minute window before that due time. We calculate the next
    // future DUE occurrence first, then schedule its alert 30 minutes early.
    final due = _moveToFuture(reminder.nextRunAt, reminder);
    if (due == null) return;
    var next = due.subtract(const Duration(minutes: 30));
    final now = DateTime.now();
    // If a reminder is created/synced after the 30-minute window has begun,
    // alert promptly rather than skipping it. Never resurrect overdue dues.
    if (!next.isAfter(now) && due.isAfter(now)) {
      next = now.add(const Duration(seconds: 2));
    }

    switch (reminder.frequency) {
      case 'daily':
        await _schedule(
          reminder,
          next,
          0,
          match: DateTimeComponents.time,
        );
        return;
      case 'weekly':
        await _schedule(
          reminder,
          next,
          0,
          match: DateTimeComponents.dayOfWeekAndTime,
        );
        return;
      case 'monthly':
        await _schedule(
          reminder,
          next,
          0,
          match: DateTimeComponents.dayOfMonthAndTime,
        );
        return;
      case 'annually':
        await _schedule(
          reminder,
          next,
          0,
          match: DateTimeComponents.dateAndTime,
        );
        return;
      case 'once':
        await _schedule(reminder, next, 0);
        return;
      case 'hourly':
      case 'every_n_minutes':
        // Native match-components don't express arbitrary minute/hour
        // intervals. Pre-schedule a rolling window so alarms keep working even
        // if the app stays closed for a long time. Every app open/sync refreshes
        // this window.
        var occurrence = next;
        for (var i = 0; i < _maxScheduledSlotsPerReminder; i++) {
          await _schedule(reminder, occurrence, i);
          occurrence = _advance(occurrence, reminder);
        }
        return;
      default:
        await _schedule(reminder, next, 0);
    }
  }

  Future<void> cancelReminder(int reminderId) async {
    await initializeLocalNotifications();
    for (var i = 0; i < _maxScheduledSlotsPerReminder; i++) {
      await _localNotifications.cancel(_notificationId(reminderId, i));
    }
  }

  Future<void> _schedule(
    Reminder reminder,
    DateTime when,
    int slot, {
    DateTimeComponents? match,
  }) async {
    final scheduled = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.UTC))) return;

    final id = _notificationId(reminder.id, slot);
    final body = reminder.message?.trim().isNotEmpty == true
        ? reminder.message
        : 'You have a reminder in My Digital Diary.';

    try {
      await _localNotifications.zonedSchedule(
        id,
        reminder.title,
        body,
        scheduled,
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
        payload: 'reminder:${reminder.id}',
      );
    } catch (_) {
      await _localNotifications.zonedSchedule(
        id,
        reminder.title,
        body,
        scheduled,
        _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
        payload: 'reminder:${reminder.id}',
      );
    }
  }

  int _notificationId(int reminderId, int slot) {
    // Keep IDs positive and safely inside Android's signed 32-bit int range.
    final safeReminderId = reminderId.abs() % 20000000;
    return 100000000 + (safeReminderId * 50) + slot;
  }

  DateTime? _moveToFuture(DateTime candidate, Reminder reminder) {
    final now = DateTime.now();
    var next = candidate;
    if (next.isAfter(now)) return next;
    if (reminder.frequency == 'once') return null;

    var guard = 0;
    while (!next.isAfter(now) && guard < 100000) {
      next = _advance(next, reminder);
      guard++;
    }
    return next.isAfter(now) ? next : null;
  }

  DateTime _advance(DateTime value, Reminder reminder) {
    switch (reminder.frequency) {
      case 'every_n_minutes':
        final minutes = reminder.intervalMinutes != null && reminder.intervalMinutes! > 0
            ? reminder.intervalMinutes!
            : 1;
        return value.add(Duration(minutes: minutes));
      case 'hourly':
        return value.add(const Duration(hours: 1));
      case 'daily':
        return value.add(const Duration(days: 1));
      case 'weekly':
        return value.add(const Duration(days: 7));
      case 'monthly':
        return _addMonths(value, 1);
      case 'annually':
        return _addMonths(value, 12);
      default:
        return value.add(const Duration(days: 1));
    }
  }

  DateTime _addMonths(DateTime value, int months) {
    final zeroBased = value.month - 1 + months;
    final year = value.year + zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = value.day > lastDay ? lastDay : value.day;
    return DateTime(
      year,
      month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  String? _payloadFromPushData(Map<String, dynamic> data) {
    final notificationId = data['notification_id']?.toString();
    if (notificationId != null && notificationId.isNotEmpty) {
      return 'notification:$notificationId';
    }

    final reminderId = int.tryParse(data['reminder_id']?.toString() ?? '');
    if (reminderId != null) {
      return 'reminder:$reminderId';
    }

    final type = data['type']?.toString();
    return type == null || type.isEmpty ? null : 'type:$type';
  }

  Future<void> _markPushAsRead(Map<String, dynamic> data) async {
    final notificationId = data['notification_id']?.toString();
    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        await ApiClient.instance.post('notifications/$notificationId/read', {});
      } catch (_) {}
      return;
    }

    final reminderId = int.tryParse(data['reminder_id']?.toString() ?? '');
    if (reminderId != null) {
      try {
        await ApiClient.instance.post('notifications/reminder/$reminderId/read', {});
      } catch (_) {}
    }
  }

  Future<void> _handleNotificationPayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    if (payload.startsWith('notification:')) {
      final id = payload.substring('notification:'.length).trim();
      if (id.isEmpty) return;
      try {
        await ApiClient.instance.post('notifications/$id/read', {});
      } catch (_) {}
      return;
    }

    if (payload.startsWith('reminder:')) {
      final id = int.tryParse(payload.substring('reminder:'.length).trim());
      if (id == null) return;
      try {
        await ApiClient.instance.post('notifications/reminder/$id/read', {});
      } catch (_) {}
    }
  }

  Future<void> registerDeviceToken() async {
    if (!_pushInitialized) return;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;

    final deviceId = await _getOrCreateDeviceId();
    final platform = Platform.isIOS ? 'ios' : 'android';

    try {
      await ApiClient.instance.post('device-tokens', {
        'device_id': deviceId,
        'fcm_token': fcmToken,
        'platform': platform,
      });
    } catch (_) {
      // Registration will be retried on another successful app/session open.
    }
  }

  Future<void> unregisterDeviceToken() async {
    final deviceId = await _getOrCreateDeviceId();
    try {
      await ApiClient.instance.delete('device-tokens?device_id=$deviceId');
    } catch (_) {
      // Best-effort. Local reminder schedules intentionally remain in place so
      // reminders can still fire after logout, as requested.
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }
}
