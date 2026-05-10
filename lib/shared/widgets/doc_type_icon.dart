import 'package:flutter/material.dart';
import '../../core/models/document.dart';

class DocTypeIcon extends StatelessWidget {
  final DocumentType type;
  final double size;

  const DocTypeIcon({super.key, required this.type, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _resolve(type);
    return Icon(icon, color: color, size: size);
  }

  (IconData, Color) _resolve(DocumentType t) {
    switch (t) {
      case DocumentType.pdf:
        return (Icons.picture_as_pdf, Colors.red.shade600);
      case DocumentType.docx:
      case DocumentType.doc:
        return (Icons.description, Colors.blue.shade600);
      case DocumentType.png:
      case DocumentType.jpg:
      case DocumentType.jpeg:
        return (Icons.image, Colors.green.shade600);
      case DocumentType.unknown:
        return (Icons.insert_drive_file, Colors.grey);
    }
  }
}
