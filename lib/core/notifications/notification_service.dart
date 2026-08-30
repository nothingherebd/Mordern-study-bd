import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around flutter_local_notifications. Every scheduling call
/// is defensive: if permission was denied or revoked, or the platform
/// throws (some Android OEMs restrict alarms aggressively), we swallow the
/// error rather than crashing the app — a missed notification is much
/// better than a broken app.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool permissionGranted = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      bool granted = true;
      if (androidImpl != null) {
        granted = await androidImpl.requestNotificationsPermission() ?? false;
      }
      if (iosImpl != null) {
        granted = await iosImpl.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      permissionGranted = granted;
      return granted;
    } catch (_) {
      permissionGranted = false;
      return false;
    }
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!permissionGranted) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders',
            'Daily reminders',
            channelDescription: 'Morning and evening plan reminders',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Some OEMs / OS versions restrict exact/inexact alarms; fail silently.
    }
  }

  Future<void> scheduleRevisionReminder({
    required int id,
    required String topicTitle,
    required DateTime when,
  }) async {
    if (!permissionGranted) return;
    if (when.isBefore(DateTime.now())) return; // never schedule in the past
    try {
      final tzTime = tz.TZDateTime.from(when, tz.local);
      await _plugin.zonedSchedule(
        id,
        'Revision due',
        topicTitle,
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'revision_reminders',
            'Revision reminders',
            channelDescription: 'Reminders for scheduled topic revisions',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Ignore — worst case the in-app overdue queue still surfaces it.
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
