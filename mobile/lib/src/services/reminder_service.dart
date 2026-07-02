import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.message,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final String message;
}

class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  static const _notificationId = 4107;
  static const _enabledKey = 'safar_reminder_enabled';
  static const _hourKey = 'safar_reminder_hour';
  static const _minuteKey = 'safar_reminder_minute';
  static const _messageKey = 'safar_reminder_message';
  static const defaultMessage = "Don't forget to capture today's journey.";

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final zoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
    final settings = await loadSettings();
    if (settings.enabled) await schedule(settings);
  }

  Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 20,
      minute: prefs.getInt(_minuteKey) ?? 0,
      message: prefs.getString(_messageKey) ?? defaultMessage,
    );
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_hourKey, settings.hour);
    await prefs.setInt(_minuteKey, settings.minute);
    await prefs.setString(
        _messageKey,
        settings.message.trim().isEmpty
            ? defaultMessage
            : settings.message.trim());
    if (settings.enabled) {
      await schedule(settings);
    } else {
      await cancel();
    }
  }

  Future<void> schedule(ReminderSettings settings) async {
    await cancel();
    await _plugin.zonedSchedule(
      _notificationId,
      'Safar',
      settings.message.trim().isEmpty ? defaultMessage : settings.message,
      _nextInstance(settings.hour, settings.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminders',
          channelDescription: 'Daily Safar diary reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel() => _plugin.cancel(_notificationId);

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
