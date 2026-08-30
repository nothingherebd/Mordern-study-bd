import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../models/daily_task.dart';

class TaskRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<DailyTask>> getForDate(String dateKey) async {
    final db = await _db;
    final rows = await db.query('daily_tasks',
        where: 'date = ?', whereArgs: [dateKey], orderBy: 'priority DESC');
    return rows.map(DailyTask.fromMap).toList();
  }

  /// All pending tasks with date < today — the overdue queue.
  Future<List<DailyTask>> getOverdue(String todayKey) async {
    final db = await _db;
    final rows = await db.query(
      'daily_tasks',
      where: 'date < ? AND status = ?',
      whereArgs: [todayKey, 'pending'],
      orderBy: 'date ASC, priority DESC',
    );
    return rows.map(DailyTask.fromMap).toList();
  }

  Future<bool> existsForTopicAndDate({
    required String topicId,
    required String date,
    required String taskType,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'daily_tasks',
      where: 'topic_id = ? AND date = ? AND task_type = ?',
      whereArgs: [topicId, date, taskType],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<DailyTask> create(DailyTask task) async {
    final db = await _db;
    await db.insert('daily_tasks', task.toMap());
    return task;
  }

  Future<void> updateStatus(String id, TaskStatus status) async {
    final db = await _db;
    await db.update(
      'daily_tasks',
      {
        'status': status.value,
        'completed_at': status == TaskStatus.completed
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Moves a pending task to a new date (used for snooze / smart reschedule).
  Future<void> reschedule(String id, String newDateKey) async {
    final db = await _db;
    await db.update('daily_tasks', {'date': newDateKey},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('daily_tasks', where: 'id = ?', whereArgs: [id]);
  }

  String newId() => _uuid.v4();
}
