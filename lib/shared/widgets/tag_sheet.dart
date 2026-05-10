import 'package:flutter/material.dart';
import '../../core/models/tag.dart';
import '../../core/services/tag_service.dart';

/// Bottom sheet pour gérer les étiquettes d'un dossier ou d'un document.
/// Passe soit [folderId] soit [documentId] (pas les deux).
class TagSheet extends StatefulWidget {
  final int? folderId;
  final int? documentId;
  final TagService tagService;
  final VoidCallback onChanged;

  const TagSheet.forFolder({
    super.key,
    required this.folderId,
    required this.tagService,
    required this.onChanged,
  }) : documentId = null;

  const TagSheet.forDocument({
    super.key,
    required this.documentId,
    required this.tagService,
    required this.onChanged,
  }) : folderId = null;

  @override
  State<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<TagSheet> {
  List<Tag> _current = [];
  List<Tag> _all = [];
  final _ctrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.tagService.getAllTags();
    final current = widget.folderId != null
        ? await widget.tagService.getTagsForFolder(widget.folderId!)
        : await widget.tagService.getTagsForDocument(widget.documentId!);
    if (!mounted) return;
    setState(() {
      _all = all;
      _current = current;
      _loading = false;
    });
  }

  bool _isAttached(Tag t) => _current.any((c) => c.id == t.id);

  Future<void> _toggle(Tag t) async {
    if (_isAttached(t)) {
      if (widget.folderId != null) {
        await widget.tagService.unbindFromFolder(t.id!, widget.folderId!);
      } else {
        await widget.tagService.unbindFromDocument(t.id!, widget.documentId!);
      }
      setState(() => _current.removeWhere((c) => c.id == t.id));
    } else {
      if (widget.folderId != null) {
        await widget.tagService.bindToFolder(t.id!, widget.folderId!);
      } else {
        await widget.tagService.bindToDocument(t.id!, widget.documentId!);
      }
      setState(() => _current.add(t));
    }
    widget.onChanged();
  }

  Future<void> _createAndAttach() async {
    final label = _ctrl.text.trim();
    if (label.isEmpty) return;
    final tag = await widget.tagService.createTag(label);
    if (widget.folderId != null) {
      await widget.tagService.bindToFolder(tag.id!, widget.folderId!);
    } else {
      await widget.tagService.bindToDocument(tag.id!, widget.documentId!);
    }
    setState(() {
      _all.add(tag);
      _current.add(tag);
      _ctrl.clear();
    });
    widget.onChanged();
  }

  Future<void> _deleteTag(Tag t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'étiquette ?'),
        content: Text(
          '« ${t.label} » sera supprimée de tous les dossiers et fichiers.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.tagService.deleteTag(t.id!);
    setState(() {
      _all.removeWhere((e) => e.id == t.id);
      _current.removeWhere((e) => e.id == t.id);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Étiquettes',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          hintText: 'Nouvelle étiquette…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _createAndAttach(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: _createAndAttach,
                        child: const Text('Créer')),
                  ],
                ),
                const SizedBox(height: 12),
                if (_all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Aucune étiquette',
                        style: TextStyle(color: Colors.grey)),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _all.map((t) {
                      final attached = _isAttached(t);
                      return _TagFilterChip(
                        tag: t,
                        selected: attached,
                        onSelected: (_) => _toggle(t),
                        onLongPress: () => _deleteTag(t),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Appui long sur une étiquette pour la supprimer',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  final Tag tag;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onLongPress;

  const _TagFilterChip({
    required this.tag,
    required this.selected,
    required this.onSelected,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.colorValue);
    return GestureDetector(
      onLongPress: onLongPress,
      child: FilterChip(
        label: Text(tag.label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: color.withValues(alpha: 0.25),
        checkmarkColor: color,
        side: selected ? BorderSide(color: color, width: 1.5) : null,
      ),
    );
  }
}
