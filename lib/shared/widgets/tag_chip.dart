import 'package:flutter/material.dart';
import '../../core/models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final original = Color(tag.colorValue);
    final color = Color.lerp(
      original,
      dark ? Colors.white : Colors.black,
      dark ? 0.4 : 0.25,
    )!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: original.withValues(alpha: dark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        tag.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
