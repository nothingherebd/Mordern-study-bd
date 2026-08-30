class Subject {
  final String id;
  final String name;
  final String? description;
  final int color;
  final String? icon;
  final DateTime createdAt;
  final bool archived;
  final int sortOrder;

  Subject({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.icon,
    required this.createdAt,
    this.archived = false,
    this.sortOrder = 0,
  });

  Subject copyWith({
    String? name,
    String? description,
    int? color,
    String? icon,
    bool? archived,
    int? sortOrder,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'created_at': createdAt.millisecondsSinceEpoch,
        'archived': archived ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory Subject.fromMap(Map<String, Object?> map) => Subject(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        color: map['color'] as int,
        icon: map['icon'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        archived: (map['archived'] as int) == 1,
        sortOrder: map['sort_order'] as int,
      );
}
