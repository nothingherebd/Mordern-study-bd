enum RevisionResult { easy, good, difficult, forgotten }

extension RevisionResultX on RevisionResult {
  String get value => name;
  static RevisionResult? fromValue(String? v) {
    if (v == null) return null;
    return RevisionResult.values.where((e) => e.value == v).firstOrNull;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class RevisionHistoryEntry {
  final String id;
  final String topicId;
  final String? scheduleId;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final RevisionResult? result;
  final int durationSeconds;
  final String? notes;

  RevisionHistoryEntry({
    required this.id,
    required this.topicId,
    this.scheduleId,
    this.scheduledAt,
    this.completedAt,
    this.result,
    this.durationSeconds = 0,
    this.notes,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'topic_id': topicId,
        'schedule_id': scheduleId,
        'scheduled_at': scheduledAt?.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'result': result?.value,
        'duration_seconds': durationSeconds,
        'notes': notes,
      };

  factory RevisionHistoryEntry.fromMap(Map<String, Object?> map) =>
      RevisionHistoryEntry(
        id: map['id'] as String,
        topicId: map['topic_id'] as String,
        scheduleId: map['schedule_id'] as String?,
        scheduledAt: map['scheduled_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['scheduled_at'] as int),
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int),
        result: RevisionResultX.fromValue(map['result'] as String?),
        durationSeconds: map['duration_seconds'] as int? ?? 0,
        notes: map['notes'] as String?,
      );
}
