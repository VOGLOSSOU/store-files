class Tag {
  final int? id;
  final String label;
  final int colorValue;

  const Tag({
    this.id,
    required this.label,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'color_value': colorValue,
      };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
        id: map['id'] as int?,
        label: map['label'] as String,
        colorValue: map['color_value'] as int,
      );
}
