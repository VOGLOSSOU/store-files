import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/document.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/folder_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/folder_export_dialog.dart';
import '../../home/widgets/folder_card.dart';
import '../../../shared/widgets/tag_sheet.dart';
import '../../document/screens/document_viewer_screen.dart';
import '../../scanner/screens/scanner_screen.dart';
import '../widgets/document_card.dart';

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
  String? _error;
  Map<int, int> _counts = {};
  List<Folder> _path = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await _docService.getByFolder(widget.folder.id!);
      final subs = await _folderService.getSubFolders(widget.folder.id!);
      final counts = await _folderService.getItemCounts();
      final path = await _folderService.getPath(widget.folder.id!);
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
        _counts = counts;
        _path = path;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de charger ce dossier.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
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
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
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
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _folderService.update(
      f.copyWith(
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      ),
    );
    _load();
  }

  Future<void> _confirmDeleteSubfolder(Folder f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le sous-dossier ?'),
        content: Text(
          '« ${f.name} » et tous ses fichiers seront supprimés définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
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
            child: const Text('Annuler'),
          ),
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
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon classeur'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Options du dossier',
            onSelected: (_) => showFolderExportDialog(context, widget.folder),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.folder_zip_outlined),
                  title: Text('Exporter en ZIP'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Créer un sous-dossier',
            onPressed: _createSubfolder,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          child: const Text('Accueil'),
                        ),
                        for (final folder in _path) ...[
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          TextButton(
                            onPressed: folder.id == widget.folder.id
                                ? null
                                : () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FolderDetailScreen(folder: folder),
                                    ),
                                  ),
                            child: Text(folder.name),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.folder.name,
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (widget.folder.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.folder.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (!_loading && _error == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_docs.length} fichier${_docs.length == 1 ? '' : 's'} · ${_subfolders.length} sous-dossier${_subfolders.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    EmptyState(
                      icon: Icons.folder_off_outlined,
                      title: 'Dossier indisponible',
                      message: _error!,
                      actionLabel: 'Réessayer',
                      onAction: _load,
                    )
                  else if (_subfolders.isEmpty && _docs.isEmpty)
                    EmptyState(
                      icon: Icons.note_add_outlined,
                      title: 'Une place pour tes documents',
                      message:
                          'Scanne un document papier ou importe un fichier pour remplir ce dossier.',
                      actionLabel: 'Créer un sous-dossier',
                      onAction: _createSubfolder,
                    )
                  else ...[
                    if (_subfolders.isNotEmpty) ...[
                      Text('Sous-dossiers', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ..._subfolders.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FolderCard(
                            folder: f,
                            tags: _folderTags[f.id] ?? [],
                            itemCount: _counts[f.id] ?? 0,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FolderDetailScreen(folder: f),
                                ),
                              );
                              await _load();
                            },
                            onEdit: () => _renameSubfolder(f),
                            onManageTags: () => _openSubfolderTagSheet(f),
                            onDelete: () => _confirmDeleteSubfolder(f),
                            onExport: () => showFolderExportDialog(context, f),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_docs.isNotEmpty) ...[
                      Text('Documents', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ..._docs.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DocumentCard(
                            doc: d,
                            tags: _docTags[d.id] ?? [],
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentViewerScreen(document: d),
                                ),
                              );
                              await _load();
                            },
                            onDelete: () => _deleteDoc(d),
                            onShare: () => _shareDoc(d),
                            onRename: () => _renameDoc(d),
                            onManageTags: () => _openDocTagSheet(d),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importFile,
                    icon: const Icon(Icons.file_upload_outlined, size: 20),
                    label: const Text('Importer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ScannerScreen(folderId: widget.folder.id!),
                        ),
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.document_scanner_outlined, size: 20),
                    label: const Text('Scanner'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
