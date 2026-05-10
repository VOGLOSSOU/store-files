import 'package:flutter/material.dart';
import '../../core/models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;

  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Text(
      '#${tag.label}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(tag.colorValue),
        letterSpacing: 0.2,
      ),
    );
  }
}
