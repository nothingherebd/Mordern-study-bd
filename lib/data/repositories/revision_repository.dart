import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../models/revision_history.dart';
import '../models/revision_schedule.dart';

class RevisionRepository {
  final _uuid = const Uuid();
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<RevisionSchedule>> getByTopic(String topicId) async {
    final db = await _db;
    final rows = await db.query('revision_schedules',
        where: 'topic_id = ?', whereArgs: [topicId]);
    return rows.map(RevisionSchedule.fromMap).toList();
  }

  Future<List<RevisionSchedule>> getDueBefore(DateTime cutoff) async {
    final db = await _db;
    final rows = await db.query(
      'revision_schedules',
      where: 'enabled = 1 AND next_revision_at IS NOT NULL AND next_revision_at <= ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    return rows.map(RevisionSchedule.fromMap).toList();
  }

  Future<List<RevisionSchedule>> getAllEnabled() async {
    final db = await _db;
    final rows = await db.query('revision_schedules', where: 'enabled = 1');
    return rows.map(RevisionSchedule.fromMap).toList();
  }

  Future<RevisionSchedule> create(RevisionSchedule schedule) async {
    // Guard against invalid/empty stage lists reaching storage — an empty
    // list would make "next interval" undefined.
    final stages = schedule.intervalStages.where((d) => d > 0).toList();
    final safe = schedule.copyWith(
      intervalStages: stages.isEmpty ? [1, 3, 7, 14, 30] : stages,
    );
    final db = await _db;
    await db.insert('revision_schedules', safe.toMap());
    return safe;
  }

  Future<void> update(RevisionSchedule schedule) async {
    final db = await _db;
    await db.update('revision_schedules', schedule.toMap(),
        where: 'id = ?', whereArgs: [schedule.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('revision_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RevisionHistoryEntry>> getHistoryForTopic(String topicId) async {
    final db = await _db;
    final rows = await db.query('revision_history',
        where: 'topic_id = ?',
        whereArgs: [topicId],
        orderBy: 'completed_at DESC');
    return rows.map(RevisionHistoryEntry.fromMap).toList();
  }

  Future<int> countHistory() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM revision_history');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Marks a revision complete and advances the schedule to its next stage,
  /// all inside one transaction (schedule + history + originating task all
  /// move together or not at all).
  ///
  /// [result] drives adaptive behaviour when intervalType == 'adaptive':
  /// easy -> skip ahead a stage, good -> normal next stage, difficult ->
  /// repeat current stage, forgotten -> reset to stage 0.
  Future<void> completeRevision({
    required RevisionSchedule schedule,
    required String topicId,
    String? taskId,
    RevisionResult? result,
    int durationSeconds = 0,
    String? notes,
  }) async {
    await AppDatabase.instance.transaction((txn) async {
      final now = DateTime.now();

      int nextStage = schedule.currentStage + 1;
      if (schedule.intervalType == 'adaptive' && result != null) {
        switch (result) {
          case RevisionResult.easy:
            nextStage = schedule.currentStage + 2;
            break;
          case RevisionResult.good:
            nextStage = schedule.currentStage + 1;
            break;
          case RevisionResult.difficult:
            nextStage = schedule.currentStage; // repeat
            break;
          case RevisionResult.forgotten:
            nextStage = 0; // restart
            break;
        }
      }
      nextStage = nextStage.clamp(0, schedule.intervalStages.length - 1);

      final intervalDays = schedule.intervalStages[nextStage];
      final next = DateTime(now.year, now.month, now.day)
          .add(Duration(days: intervalDays));

      final updatedSchedule = schedule.copyWith(
        currentStage: nextStage,
        nextRevisionAt: next,
        lastRevisionAt: now,
        revisionCount: schedule.revisionCount + 1,
      );
      await txn.update('revision_schedules', updatedSchedule.toMap(),
          where: 'id = ?', whereArgs: [schedule.id]);

      final entry = RevisionHistoryEntry(
        id: _uuid.v4(),
        topicId: topicId,
        scheduleId: schedule.id,
        scheduledAt: schedule.nextRevisionAt,
        completedAt: now,
        result: result,
        durationSeconds: durationSeconds,
        notes: notes,
      );
      await txn.insert('revision_history', entry.toMap());

      if (taskId != null) {
        await txn.update(
          'daily_tasks',
          {'status': 'completed', 'completed_at': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [taskId],
        );
      }
    });
  }
}
