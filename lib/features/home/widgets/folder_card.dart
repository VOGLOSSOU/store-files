import 'package:flutter/material.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../shared/widgets/tag_chip.dart';

class FolderCard extends StatelessWidget {
  final Folder folder;
  final int? itemCount;
  final List<Tag> tags;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onManageTags;
  final VoidCallback onExport;

  const FolderCard({
    super.key,
    required this.folder,
    this.itemCount,
    required this.tags,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onManageTags,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF403724)
                      : const Color(0xFFFFF2D8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE9B96E)
                      : const Color(0xFFA16C1A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (folder.description != null &&
                        folder.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        folder.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (itemCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$itemCount élément${itemCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                tooltip: 'Options du dossier',
                onSelected: (a) {
                  switch (a) {
                    case _Action.edit:
                      onEdit();
                    case _Action.tags:
                      onManageTags();
                    case _Action.delete:
                      onDelete();
                    case _Action.export:
                      onExport();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _Action.export,
                    child: ListTile(
                      leading: Icon(Icons.folder_zip_outlined),
                      title: Text('Exporter en ZIP'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _Action.edit,
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
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
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

enum _Action { edit, tags, delete, export }
