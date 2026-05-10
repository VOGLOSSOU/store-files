class Folder {
  final int? id;
  final String name;
  final String? description;
  final int? parentId;
  final DateTime createdAt;

  const Folder({
    this.id,
    required this.name,
    this.description,
    this.parentId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'parent_id': parentId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
        parentId: map['parent_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Folder copyWith({
    int? id,
    String? name,
    String? description,
    int? parentId,
    DateTime? createdAt,
  }) =>
      Folder(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        parentId: parentId ?? this.parentId,
        createdAt: createdAt ?? this.createdAt,
      );
}
