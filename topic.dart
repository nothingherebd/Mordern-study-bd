enum TopicPriority { low, medium, high, critical }

enum TopicStatus { notStarted, inProgress, learned, mastered }

extension TopicPriorityX on TopicPriority {
  int get value => index;
  String get label => switch (this) {
        TopicPriority.low => 'Low',
        TopicPriority.medium => 'Medium',
        TopicPriority.high => 'High',
        TopicPriority.critical => 'Critical',
      };
  static TopicPriority fromValue(int v) =>
      TopicPriority.values[v.clamp(0, TopicPriority.values.length - 1)];
}

extension TopicStatusX on TopicStatus {
  String get value => switch (this) {
        TopicStatus.notStarted => 'not_started',
        TopicStatus.inProgress => 'in_progress',
        TopicStatus.learned => 'learned',
        TopicStatus.mastered => 'mastered',
      };
  static TopicStatus fromValue(String v) => TopicStatus.values.firstWhere(
        (e) => e.value == v,
        orElse: () => TopicStatus.notStarted,
      );
}

class Topic {
  final String id;
  final String subjectId;
  final String title;
  final String? description;
  final String? notes;
  final TopicPriority priority;
  final TopicStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int estimatedMinutes;
  final DateTime? targetDate;
  final bool archived;

  Topic({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    this.notes,
    this.priority = TopicPriority.medium,
    this.status = TopicStatus.notStarted,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedMinutes = 30,
    this.targetDate,
    this.archived = false,
  });

  Topic copyWith({
    String? title,
    String? description,
    String? notes,
    TopicPriority? priority,
    TopicStatus? status,
    DateTime? updatedAt,
    int? estimatedMinutes,
    DateTime? targetDate,
    bool? archived,
  }) {
    return Topic(
      id: id,
      subjectId: subjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      targetDate: targetDate ?? this.targetDate,
      archived: archived ?? this.archived,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'notes': notes,
        'priority': priority.value,
        'status': status.value,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'estimated_minutes': estimatedMinutes,
        'target_date': targetDate?.millisecondsSinceEpoch,
        'archived': archived ? 1 : 0,
      };

  factory Topic.fromMap(Map<String, Object?> map) => Topic(
        id: map['id'] as String,
        subjectId: map['subject_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        notes: map['notes'] as String?,
        priority: TopicPriorityX.fromValue(map['priority'] as int),
        status: TopicStatusX.fromValue(map['status'] as String),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        estimatedMinutes: map['estimated_minutes'] as int,
        targetDate: map['target_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['target_date'] as int),
        archived: (map['archived'] as int) == 1,
      );
}
