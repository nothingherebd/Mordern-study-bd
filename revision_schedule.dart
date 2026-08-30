import 'dart:convert';

/// A configurable spaced-revision plan for a topic.
///
/// [intervalStages] is the sequence of "days until next revision" the user
/// configured, e.g. [1, 3, 7, 14, 30]. [currentStage] is an index into that
/// list. Once the index runs past the end of the list, the last stage
/// repeats indefinitely rather than crashing or looping back to 1 day.
class RevisionSchedule {
  final String id;
  final String topicId;
  final String intervalType; // 'fixed' | 'custom' | 'adaptive'
  final List<int> intervalStages;
  final int currentStage;
  final DateTime? nextRevisionAt;
  final DateTime? lastRevisionAt;
  final int revisionCount;
  final bool enabled;

  RevisionSchedule({
    required this.id,
    required this.topicId,
    this.intervalType = 'custom',
    this.intervalStages = const [1, 3, 7, 14, 30],
    this.currentStage = 0,
    this.nextRevisionAt,
    this.lastRevisionAt,
    this.revisionCount = 0,
    this.enabled = true,
  }) : assert(intervalStages.length > 0,
            'A revision schedule needs at least one stage');

  int get currentIntervalDays {
    if (intervalStages.isEmpty) return 1;
    final idx = currentStage.clamp(0, intervalStages.length - 1);
    return intervalStages[idx];
  }

  RevisionSchedule copyWith({
    String? intervalType,
    List<int>? intervalStages,
    int? currentStage,
    DateTime? nextRevisionAt,
    bool clearNextRevisionAt = false,
    DateTime? lastRevisionAt,
    int? revisionCount,
    bool? enabled,
  }) {
    return RevisionSchedule(
      id: id,
      topicId: topicId,
      intervalType: intervalType ?? this.intervalType,
      intervalStages: intervalStages ?? this.intervalStages,
      currentStage: currentStage ?? this.currentStage,
      nextRevisionAt:
          clearNextRevisionAt ? null : (nextRevisionAt ?? this.nextRevisionAt),
      lastRevisionAt: lastRevisionAt ?? this.lastRevisionAt,
      revisionCount: revisionCount ?? this.revisionCount,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'topic_id': topicId,
        'interval_type': intervalType,
        'interval_stages': jsonEncode(intervalStages),
        'current_stage': currentStage,
        'next_revision_at': nextRevisionAt?.millisecondsSinceEpoch,
        'last_revision_at': lastRevisionAt?.millisecondsSinceEpoch,
        'revision_count': revisionCount,
        'enabled': enabled ? 1 : 0,
      };

  factory RevisionSchedule.fromMap(Map<String, Object?> map) {
    List<int> stages;
    try {
      stages = (jsonDecode(map['interval_stages'] as String) as List)
          .map((e) => e as int)
          .toList();
      if (stages.isEmpty) stages = [1, 3, 7, 14, 30];
    } catch (_) {
      stages = [1, 3, 7, 14, 30];
    }
    return RevisionSchedule(
      id: map['id'] as String,
      topicId: map['topic_id'] as String,
      intervalType: map['interval_type'] as String? ?? 'custom',
      intervalStages: stages,
      currentStage: map['current_stage'] as int? ?? 0,
      nextRevisionAt: map['next_revision_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['next_revision_at'] as int),
      lastRevisionAt: map['last_revision_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['last_revision_at'] as int),
      revisionCount: map['revision_count'] as int? ?? 0,
      enabled: (map['enabled'] as int? ?? 1) == 1,
    );
  }
}
