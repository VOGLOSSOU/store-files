import 'package:flutter/material.dart';
import '../../core/models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onDeleted;

  const TagChip({super.key, required this.tag, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.colorValue);
    return Chip(
      label: Text(
        tag.label,
        style: TextStyle(
          fontSize: 11,
          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.85),
      deleteIcon: onDeleted != null
          ? const Icon(Icons.close, size: 14)
          : null,
      onDeleted: onDeleted,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
