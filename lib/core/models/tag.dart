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

// Table de jointure (tag <-> dossier ou document)
class TagBinding {
  final int tagId;
  final int? folderId;
  final int? documentId;

  const TagBinding({required this.tagId, this.folderId, this.documentId})
      : assert(folderId != null || documentId != null);

  Map<String, dynamic> toMap() => {
        'tag_id': tagId,
        'folder_id': folderId,
        'document_id': documentId,
      };
}
