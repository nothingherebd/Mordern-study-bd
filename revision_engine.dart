import 'package:uuid/uuid.dart';
import '../../data/models/revision_history.dart';
import '../../data/models/revision_schedule.dart';
import '../../data/repositories/revision_repository.dart';

/// Turns "study this topic, then revise it on this cadence" into concrete
/// scheduled dates. Kept separate from the repository so the scheduling
/// math (which is the part likely to grow adaptive/SRS logic later) isn't
/// tangled up with SQL.
class RevisionEngine {
  final RevisionRepository repository;
  final _uuid = const Uuid();

  RevisionEngine(this.repository);

  /// Creates a new schedule for a topic starting from [firstRevisionDate].
  /// Rejects a first-revision date that's absurdly far in the past (data
  /// entry mistake) but allows "today" or a couple of days ago, since a
  /// user might be logging a study session after the fact.
  Future<RevisionSchedule> createSchedule({
    required String topicId,
    required DateTime firstRevisionDate,
    List<int> intervalStages = const [1, 3, 7, 14, 30],
    String intervalType = 'custom',
  }) async {
    final stages = intervalStages.where((d) => d > 0).toList();
    final safeStages = stages.isEmpty ? [1, 3, 7, 14, 30] : stages;

    final schedule = RevisionSchedule(
      id: _uuid.v4(),
      topicId: topicId,
      intervalType: intervalType,
      intervalStages: safeStages,
      currentStage: 0,
      nextRevisionAt: firstRevisionDate,
      enabled: true,
    );
    return repository.create(schedule);
  }

  /// Preview of upcoming revision dates for display in the Study editor
  /// (e.g. "30 Aug → 2 Sep → 5 Sep → 8 Sep"), without touching the database.
  List<DateTime> previewDates(DateTime start, List<int> stages, {int count = 4}) {
    final dates = <DateTime>[];
    var cursor = DateTime(start.year, start.month, start.day);
    dates.add(cursor);
    for (var i = 0; i < count - 1 && i < stages.length; i++) {
      cursor = cursor.add(Duration(days: stages[i]));
      dates.add(cursor);
    }
    return dates;
  }

  Future<void> completeRevision({
    required RevisionSchedule schedule,
    required String topicId,
    String? taskId,
    RevisionResult? result,
    int durationSeconds = 0,
    String? notes,
  }) {
    return repository.completeRevision(
      schedule: schedule,
      topicId: topicId,
      taskId: taskId,
      result: result,
      durationSeconds: durationSeconds,
      notes: notes,
    );
  }

  Future<void> pause(RevisionSchedule schedule) =>
      repository.update(schedule.copyWith(enabled: false));

  Future<void> resume(RevisionSchedule schedule) =>
      repository.update(schedule.copyWith(enabled: true));
}
