import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../models/topic.dart';

class TopicRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Topic>> getBySubject(String subjectId,
      {bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'topics',
      where: includeArchived
          ? 'subject_id = ?'
          : 'subject_id = ? AND archived = 0',
      whereArgs: [subjectId],
      orderBy: 'priority DESC, created_at ASC',
    );
    return rows.map(Topic.fromMap).toList();
  }

  Future<List<Topic>> getAll({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'topics',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'priority DESC, created_at ASC',
    );
    return rows.map(Topic.fromMap).toList();
  }

  Future<Topic?> getById(String id) async {
    final db = await _db;
    final rows = await db.query('topics', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Topic.fromMap(rows.first);
  }

  Future<Topic> create(Topic topic) async {
    if (topic.title.trim().isEmpty) {
      throw ArgumentError('Topic title cannot be empty');
    }
    final db = await _db;
    await db.insert('topics', topic.toMap());
    return topic;
  }

  Future<void> update(Topic topic) async {
    if (topic.title.trim().isEmpty) {
      throw ArgumentError('Topic title cannot be empty');
    }
    final db = await _db;
    await db.update('topics', topic.toMap(),
        where: 'id = ?', whereArgs: [topic.id]);
  }

  Future<void> archive(String id, {bool archived = true}) async {
    final db = await _db;
    await db.update('topics', {'archived': archived ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes a topic and its schedules/history/tasks in one transaction.
  Future<void> deleteCascade(String id) async {
    await AppDatabase.instance.transaction((txn) async {
      await txn.delete('daily_tasks', where: 'topic_id = ?', whereArgs: [id]);
      await txn.delete('revision_history', where: 'topic_id = ?', whereArgs: [id]);
      await txn.delete('revision_schedules', where: 'topic_id = ?', whereArgs: [id]);
      await txn.delete('focus_sessions', where: 'topic_id = ?', whereArgs: [id]);
      await txn.delete('topics', where: 'id = ?', whereArgs: [id]);
    });
  }

  String newId() => _uuid.v4();
}
