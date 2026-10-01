import 'package:flutter/material.dart';
import '../../core/models/document.dart';

class DocTypeIcon extends StatelessWidget {
  final DocumentType type;
  final double size;

  const DocTypeIcon({super.key, required this.type, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Icon(_resolve(type), color: color, size: size);
  }

  // Une seule couleur (celle du thème) pour tous les types : la différence
  // se lit sur la forme de l'icône, pas sur un code couleur par extension.
  IconData _resolve(DocumentType t) {
    switch (t) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.docx:
      case DocumentType.doc:
        return Icons.description;
      case DocumentType.png:
      case DocumentType.jpg:
      case DocumentType.jpeg:
        return Icons.image;
      case DocumentType.unknown:
        return Icons.insert_drive_file;
    }
  }
}
