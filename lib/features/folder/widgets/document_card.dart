import 'package:flutter/material.dart';
import '../../../core/models/document.dart';
import '../../../core/models/tag.dart';
import '../../../shared/widgets/doc_type_icon.dart';
import '../../../shared/widgets/tag_chip.dart';

class DocumentCard extends StatelessWidget {
  final Document doc;
  final List<Tag> tags;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onManageTags;

  const DocumentCard({
    super.key,
    required this.doc,
    required this.tags,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
    required this.onRename,
    required this.onManageTags,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: DocTypeIcon(type: doc.type, size: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.type.name.toUpperCase()} · ${doc.sizeLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: tags.map((t) => TagChip(tag: t)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_Action>(
                onSelected: (a) {
                  switch (a) {
                    case _Action.share:
                      onShare();
                    case _Action.rename:
                      onRename();
                    case _Action.tags:
                      onManageTags();
                    case _Action.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _Action.share,
                    child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Partager'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _Action.rename,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Renommer'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _Action.tags,
                    child: ListTile(
                      leading: Icon(Icons.label_outline),
                      title: Text('Étiquettes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _Action.delete,
                    child: ListTile(
                      leading:
                          Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Supprimer',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { share, rename, tags, delete }
