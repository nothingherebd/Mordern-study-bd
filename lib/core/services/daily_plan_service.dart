import '../../data/models/daily_task.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/topic_repository.dart';

/// Generates and maintains the daily task list.
///
/// The guiding rule from the spec: never blindly wipe yesterday's list at
/// midnight. Instead, every time the app starts or resumes, compare
/// "last processed date" to "today". If the app was closed across one or
/// more midnights, catch up exactly once — generate today's tasks, and
/// reclassify anything still pending from earlier days as overdue (they
/// stay as their own rows, not duplicated).
class DailyPlanService {
  final TaskRepository taskRepo;
  final TopicRepository topicRepo;
  final RevisionRepository revisionRepo;
  final SettingsRepository settingsRepo;

  DailyPlanService({
    required this.taskRepo,
    required this.topicRepo,
    required this.revisionRepo,
    required this.settingsRepo,
  });

  /// Call this on app start and app resume. Idempotent — safe to call many
  /// times in the same day; it only does work the first time each day.
  Future<void> processDailyRollover() async {
    final now = DateTime.now();
    final todayKey = dayKeyFormat.format(now);
    final lastProcessed = await settingsRepo.get(SettingsRepository.keyLastProcessedDate);

    if (lastProcessed == todayKey) return; // already processed today

    await generateTasksForDate(now);
    await settingsRepo.set(SettingsRepository.keyLastProcessedDate, todayKey);
  }

  /// Generates today's tasks from due revision schedules and topics with no
  /// schedule yet that are due for first study. Skips anything that already
  /// has a task for that topic+date+type, so re-running never duplicates.
  Future<void> generateTasksForDate(DateTime date) async {
    final autoGenerate =
        (await settingsRepo.get(SettingsRepository.keyAutoGenerateTasks)) != 'false';
    if (!autoGenerate) return;

    final dateKey = dayKeyFormat.format(date);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final dueSchedules = await revisionRepo.getDueBefore(endOfDay);
    for (final schedule in dueSchedules) {
      final topic = await topicRepo.getById(schedule.topicId);
      if (topic == null || topic.archived) continue; // topic was deleted/archived

      final alreadyExists = await taskRepo.existsForTopicAndDate(
        topicId: topic.id,
        date: dateKey,
        taskType: 'revision',
      );
      if (alreadyExists) continue;

      await taskRepo.create(DailyTask(
        id: taskRepo.newId(),
        topicId: topic.id,
        date: dateKey,
        taskType: TaskType.revision,
        priority: topic.priority.value,
        estimatedMinutes: (topic.estimatedMinutes * 0.6).round().clamp(10, 999),
        createdAt: DateTime.now(),
        sourceScheduleId: schedule.id,
      ));
    }

    // Topics with no revision schedule at all and status not-started get a
    // "study" task on their target date, or today if no target date is set
    // and they were created today.
    final topics = await topicRepo.getAll();
    for (final topic in topics) {
      if (topic.status != TopicStatus.notStarted) continue;
      final schedules = await revisionRepo.getByTopic(topic.id);
      if (schedules.isNotEmpty) continue;
      final targetKey =
          topic.targetDate != null ? dayKeyFormat.format(topic.targetDate!) : null;
      if (targetKey != dateKey) continue;

      final exists = await taskRepo.existsForTopicAndDate(
        topicId: topic.id,
        date: dateKey,
        taskType: 'study',
      );
      if (exists) continue;

      await taskRepo.create(DailyTask(
        id: taskRepo.newId(),
        topicId: topic.id,
        date: dateKey,
        taskType: TaskType.study,
        priority: topic.priority.value,
        estimatedMinutes: topic.estimatedMinutes,
        createdAt: DateTime.now(),
      ));
    }

    await _applySmartLimit(dateKey);
  }

  /// If today's total planned minutes exceed the configured daily maximum,
  /// push the lowest-priority tasks to tomorrow rather than overwhelming
  /// the user with an unrealistic list.
  Future<void> _applySmartLimit(String dateKey) async {
    final maxMinutesStr = await settingsRepo.get(SettingsRepository.keyMaxDailyMinutes);
    final maxTasksStr = await settingsRepo.get(SettingsRepository.keyMaxDailyTasks);
    final maxMinutes = int.tryParse(maxMinutesStr) ?? 180;
    final maxTasks = int.tryParse(maxTasksStr) ?? 8;

    final tasks = await taskRepo.getForDate(dateKey);
    final pending = tasks.where((t) => t.status == TaskStatus.pending).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority)); // highest priority first

    int minutes = 0;
    int count = 0;
    final tomorrow = dayKeyFormat.format(
        DateTime.parse('$dateKey 00:00:00').add(const Duration(days: 1)));

    for (final task in pending) {
      minutes += task.estimatedMinutes;
      count += 1;
      final overBudget = minutes > maxMinutes || count > maxTasks;
      if (overBudget) {
        await taskRepo.reschedule(task.id, tomorrow);
      }
    }
  }

  Future<List<DailyTask>> getToday() async {
    return taskRepo.getForDate(dayKeyFormat.format(DateTime.now()));
  }

  Future<List<DailyTask>> getOverdue() async {
    return taskRepo.getOverdue(dayKeyFormat.format(DateTime.now()));
  }

  Future<void> snooze(String taskId, Duration by) async {
    final newDate = dayKeyFormat.format(DateTime.now().add(by));
    await taskRepo.reschedule(taskId, newDate);
  }
}
