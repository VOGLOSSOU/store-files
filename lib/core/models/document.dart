enum DocumentType { pdf, docx, doc, png, jpg, jpeg, unknown }

extension DocumentTypeExt on DocumentType {
  static DocumentType fromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return DocumentType.pdf;
      case 'docx':
        return DocumentType.docx;
      case 'doc':
        return DocumentType.doc;
      case 'png':
        return DocumentType.png;
      case 'jpg':
        return DocumentType.jpg;
      case 'jpeg':
        return DocumentType.jpeg;
      default:
        return DocumentType.unknown;
    }
  }

  bool get isImage =>
      this == DocumentType.png ||
      this == DocumentType.jpg ||
      this == DocumentType.jpeg;

  bool get isPdf => this == DocumentType.pdf;
}

class Document {
  final int? id;
  final String name;
  final String filePath;
  final DocumentType type;
  final int folderId;
  final int fileSizeBytes;
  final DateTime importedAt;

  const Document({
    this.id,
    required this.name,
    required this.filePath,
    required this.type,
    required this.folderId,
    required this.fileSizeBytes,
    required this.importedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'file_path': filePath,
        'type': type.name,
        'folder_id': folderId,
        'file_size_bytes': fileSizeBytes,
        'imported_at': importedAt.toIso8601String(),
      };

  factory Document.fromMap(Map<String, dynamic> map) => Document(
        id: map['id'] as int?,
        name: map['name'] as String,
        filePath: map['file_path'] as String,
        type: DocumentType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => DocumentType.unknown,
        ),
        folderId: map['folder_id'] as int,
        fileSizeBytes: map['file_size_bytes'] as int,
        importedAt: DateTime.parse(map['imported_at'] as String),
      );

  String get sizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes o';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}
