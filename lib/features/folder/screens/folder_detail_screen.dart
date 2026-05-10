import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/document.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/folder_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/tag_sheet.dart';
import '../../document/screens/document_viewer_screen.dart';
import '../widgets/document_card.dart';
import 'subfolder_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final Folder folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final _docService = DocumentService();
  final _folderService = FolderService();
  final _tagService = TagService();

  List<Document> _docs = [];
  List<Folder> _subfolders = [];
  Map<int, List<Tag>> _docTags = {};
  Map<int, List<Tag>> _folderTags = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await _docService.getByFolder(widget.folder.id!);
    final subs = await _folderService.getSubFolders(widget.folder.id!);
    final docTags = <int, List<Tag>>{};
    final folderTags = <int, List<Tag>>{};
    for (final d in docs) {
      docTags[d.id!] = await _tagService.getTagsForDocument(d.id!);
    }
    for (final f in subs) {
      folderTags[f.id!] = await _tagService.getTagsForFolder(f.id!);
    }
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _subfolders = subs;
      _docTags = docTags;
      _folderTags = folderTags;
      _loading = false;
    });
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'png', 'jpg', 'jpeg'],
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.path != null) {
        await _docService.importFile(file.path!, widget.folder.id!);
      }
    }
    _load();
  }

  Future<void> _createSubfolder() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau sous-dossier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Nom *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _folderService.create(
      nameCtrl.text.trim(),
      description:
          descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      parentId: widget.folder.id,
    );
    _load();
  }

  Future<void> _renameSubfolder(Folder f) async {
    final nameCtrl = TextEditingController(text: f.name);
    final descCtrl = TextEditingController(text: f.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Nom *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;
    await _folderService.update(f.copyWith(
      name: nameCtrl.text.trim(),
      description:
          descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    ));
    _load();
  }

  Future<void> _confirmDeleteSubfolder(Folder f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le sous-dossier ?'),
        content: Text(
            '« ${f.name} » et tous ses fichiers seront supprimés définitivement.'),
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
    if (ok == true) {
      await _folderService.delete(f.id!);
      _load();
    }
  }

  void _openSubfolderTagSheet(Folder f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagSheet.forFolder(
        folderId: f.id!,
        tagService: _tagService,
        onChanged: _load,
      ),
    );
  }

  Future<void> _deleteDoc(Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fichier ?'),
        content: Text('« ${doc.name} » sera supprimé définitivement.'),
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
    if (ok == true) {
      await _docService.delete(doc);
      _load();
    }
  }

  Future<void> _renameDoc(Document doc) async {
    final ctrl = TextEditingController(text: doc.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _docService.rename(doc, ctrl.text.trim());
      _load();
    }
  }

  void _shareDoc(Document doc) =>
      SharePlus.instance.share(ShareParams(files: [XFile(doc.filePath)]));

  void _openDocTagSheet(Document doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagSheet.forDocument(
        documentId: doc.id!,
        tagService: _tagService,
        onChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Sous-dossier',
            onPressed: _createSubfolder,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildContent(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importFile,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importer'),
      ),
    );
  }

  Widget _buildContent() {
    if (_subfolders.isEmpty && _docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Dossier vide', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            const Text(
              'Importe des fichiers ou crée un sous-dossier',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_subfolders.isNotEmpty) ...[
          _sectionLabel('Sous-dossiers'),
          const SizedBox(height: 8),
          ..._subfolders.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SubfolderTile(
                  folder: f,
                  tags: _folderTags[f.id] ?? [],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SubfolderScreen(folder: f)),
                  ).then((_) => _load()),
                  onRename: () => _renameSubfolder(f),
                  onManageTags: () => _openSubfolderTagSheet(f),
                  onDelete: () => _confirmDeleteSubfolder(f),
                ),
              )),
          const SizedBox(height: 16),
        ],
        if (_docs.isNotEmpty) ...[
          _sectionLabel('Fichiers'),
          const SizedBox(height: 8),
          ..._docs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DocumentCard(
                  doc: d,
                  tags: _docTags[d.id] ?? [],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DocumentViewerScreen(document: d)),
                  ).then((_) => _load()),
                  onDelete: () => _deleteDoc(d),
                  onShare: () => _shareDoc(d),
                  onRename: () => _renameDoc(d),
                  onManageTags: () => _openDocTagSheet(d),
                ),
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
      );
}

// ── Sous-dossier tile ─────────────────────────────────────────────────────────

class _SubfolderTile extends StatelessWidget {
  final Folder folder;
  final List<Tag> tags;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onManageTags;
  final VoidCallback onDelete;

  const _SubfolderTile({
    required this.folder,
    required this.tags,
    required this.onTap,
    required this.onRename,
    required this.onManageTags,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.folder, color: cs.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (folder.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        folder.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
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
              PopupMenuButton<_SubAction>(
                onSelected: (a) {
                  switch (a) {
                    case _SubAction.rename:
                      onRename();
                    case _SubAction.tags:
                      onManageTags();
                    case _SubAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _SubAction.rename,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Renommer'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _SubAction.tags,
                    child: ListTile(
                      leading: Icon(Icons.label_outline),
                      title: Text('Étiquettes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _SubAction.delete,
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

enum _SubAction { rename, tags, delete }
