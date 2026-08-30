import 'package:intl/intl.dart';

enum TaskType { study, revision }

enum TaskStatus { pending, completed, skipped }

extension TaskTypeX on TaskType {
  String get value => name;
  static TaskType fromValue(String v) =>
      TaskType.values.firstWhere((e) => e.value == v, orElse: () => TaskType.revision);
}

extension TaskStatusX on TaskStatus {
  String get value => name;
  static TaskStatus fromValue(String v) => TaskStatus.values
      .firstWhere((e) => e.value == v, orElse: () => TaskStatus.pending);
}

final DateFormat dayKeyFormat = DateFormat('yyyy-MM-dd');

class DailyTask {
  final String id;
  final String topicId;
  final String date; // yyyy-MM-dd, the local calendar day this belongs to
  final TaskType taskType;
  final int priority;
  final TaskStatus status;
  final int estimatedMinutes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? sourceScheduleId;

  DailyTask({
    required this.id,
    required this.topicId,
    required this.date,
    this.taskType = TaskType.revision,
    this.priority = 1,
    this.status = TaskStatus.pending,
    this.estimatedMinutes = 30,
    required this.createdAt,
    this.completedAt,
    this.sourceScheduleId,
  });

  bool get isOverdue {
    final today = dayKeyFormat.format(DateTime.now());
    return status == TaskStatus.pending && date.compareTo(today) < 0;
  }

  DailyTask copyWith({
    TaskStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return DailyTask(
      id: id,
      topicId: topicId,
      date: date,
      taskType: taskType,
      priority: priority,
      status: status ?? this.status,
      estimatedMinutes: estimatedMinutes,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sourceScheduleId: sourceScheduleId,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'topic_id': topicId,
        'date': date,
        'task_type': taskType.value,
        'priority': priority,
        'status': status.value,
        'estimated_minutes': estimatedMinutes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'source_schedule_id': sourceScheduleId,
      };

  factory DailyTask.fromMap(Map<String, Object?> map) => DailyTask(
        id: map['id'] as String,
        topicId: map['topic_id'] as String,
        date: map['date'] as String,
        taskType: TaskTypeX.fromValue(map['task_type'] as String),
        priority: map['priority'] as int,
        status: TaskStatusX.fromValue(map['status'] as String),
        estimatedMinutes: map['estimated_minutes'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int),
        sourceScheduleId: map['source_schedule_id'] as String?,
      );
}
