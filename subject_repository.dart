import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../models/subject.dart';

class SubjectRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<Subject>> getAll({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'subjects',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Subject.fromMap).toList();
  }

  Future<Subject?> getById(String id) async {
    final db = await _db;
    final rows = await db.query('subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Subject.fromMap(rows.first);
  }

  /// Creates a subject. Trims and de-duplicates the name (case-insensitive)
  /// against existing non-archived subjects so users don't end up with
  /// "Biology" and "biology " as separate subjects by accident.
  Future<Subject> create({
    required String name,
    String? description,
    int color = 0xFF3B82F6,
    String? icon,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Subject name cannot be empty');
    }
    final db = await _db;
    final existing = await db.query(
      'subjects',
      where: 'LOWER(name) = ? AND archived = 0',
      whereArgs: [trimmed.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw StateError('A subject named "$trimmed" already exists');
    }

    final maxSort = Sqflite.firstIntValue(await db
        .rawQuery('SELECT MAX(sort_order) as m FROM subjects')) ?? -1;

    final subject = Subject(
      id: _uuid.v4(),
      name: trimmed,
      description: description,
      color: color,
      icon: icon,
      createdAt: DateTime.now(),
      sortOrder: maxSort + 1,
    );
    await db.insert('subjects', subject.toMap());
    return subject;
  }

  Future<void> update(Subject subject) async {
    final db = await _db;
    await db.update('subjects', subject.toMap(),
        where: 'id = ?', whereArgs: [subject.id]);
  }

  Future<void> archive(String id, {bool archived = true}) async {
    final db = await _db;
    await db.update('subjects', {'archived': archived ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes a subject and everything that hangs off it (topics, schedules,
  /// history, tasks) inside one transaction — a partial delete would leave
  /// orphan rows pointing at a subject_id that no longer exists.
  Future<void> deleteCascade(String id) async {
    await AppDatabase.instance.transaction((txn) async {
      final topicRows =
          await txn.query('topics', columns: ['id'], where: 'subject_id = ?', whereArgs: [id]);
      final topicIds = topicRows.map((r) => r['id'] as String).toList();
      for (final topicId in topicIds) {
        await txn.delete('daily_tasks', where: 'topic_id = ?', whereArgs: [topicId]);
        await txn.delete('revision_history', where: 'topic_id = ?', whereArgs: [topicId]);
        await txn.delete('revision_schedules', where: 'topic_id = ?', whereArgs: [topicId]);
        await txn.delete('focus_sessions', where: 'topic_id = ?', whereArgs: [topicId]);
      }
      await txn.delete('topics', where: 'subject_id = ?', whereArgs: [id]);
      await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> reorder(List<String> orderedIds) async {
    await AppDatabase.instance.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('subjects', {'sort_order': i},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });
  }
}
