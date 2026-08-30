import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';

/// Simple typed key/value store for app settings, backed by SQLite so it's
/// included in the same backup/restore flow as everything else (unlike
/// SharedPreferences, which lives outside the database file).
class SettingsRepository {
  Future<Database> get _db async => AppDatabase.instance.database;

  static const keyDefaultPriority = 'default_priority';
  static const keyDefaultStudyMinutes = 'default_study_minutes';
  static const keyDefaultIntervalStages = 'default_interval_stages';
  static const keyAutoGenerateTasks = 'auto_generate_tasks';
  static const keyMaxDailyMinutes = 'max_daily_minutes';
  static const keyMaxDailyTasks = 'max_daily_tasks';
  static const keyIncludeOverdue = 'include_overdue';
  static const keyMorningReminderTime = 'morning_reminder_time';
  static const keyEveningReminderTime = 'evening_reminder_time';
  static const keyRevisionRemindersOn = 'revision_reminders_on';
  static const keyDailyPlanReminderOn = 'daily_plan_reminder_on';
  static const keyThemeMode = 'theme_mode'; // system | light | dark
  static const keyAccentColor = 'accent_color';
  static const keyWeekStartsOn = 'week_starts_on'; // monday | sunday
  static const keyLastProcessedDate = 'last_processed_date';
  static const keyCountdownDefaultSeconds = 'countdown_default_seconds';
  static const keyCountdownAutoStart = 'countdown_auto_start';
  static const keyCountdownKeepScreenOn = 'countdown_keep_screen_on';
  static const keyCountdownWarningSeconds = 'countdown_warning_seconds';

  static final Map<String, String> defaults = {
    keyDefaultPriority: '1',
    keyDefaultStudyMinutes: '30',
    keyDefaultIntervalStages: '[1,3,7,14,30]',
    keyAutoGenerateTasks: 'true',
    keyMaxDailyMinutes: '180',
    keyMaxDailyTasks: '8',
    keyIncludeOverdue: 'true',
    keyMorningReminderTime: '07:00',
    keyEveningReminderTime: '20:00',
    keyRevisionRemindersOn: 'true',
    keyDailyPlanReminderOn: 'true',
    keyThemeMode: 'system',
    keyAccentColor: '4280391411',
    keyWeekStartsOn: 'monday',
    keyCountdownDefaultSeconds: '1500',
    keyCountdownAutoStart: 'false',
    keyCountdownKeepScreenOn: 'true',
    keyCountdownWarningSeconds: '60',
  };

  Future<Map<String, String>> getAll() async {
    final db = await _db;
    final rows = await db.query('settings');
    final map = Map<String, String>.from(defaults);
    for (final row in rows) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  Future<String> get(String key) async {
    final db = await _db;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return defaults[key] ?? '';
    return rows.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setMany(Map<String, String> values) async {
    await AppDatabase.instance.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in values.entries) {
        await txn.insert(
          'settings',
          {'key': entry.key, 'value': entry.value, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> resetAll() async {
    final db = await _db;
    await db.delete('settings');
  }
}
