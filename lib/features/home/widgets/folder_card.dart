import 'package:flutter/material.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../shared/widgets/tag_chip.dart';

class FolderCard extends StatelessWidget {
  final Folder folder;
  final List<Tag> tags;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onManageTags;

  const FolderCard({
    super.key,
    required this.folder,
    required this.tags,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.folder, color: colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    if (folder.description != null &&
                        folder.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        folder.description!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                onSelected: (a) {
                  switch (a) {
                    case _Action.edit:
                      onEdit();
                    case _Action.tags:
                      onManageTags();
                    case _Action.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
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

enum _Action { edit, tags, delete }
