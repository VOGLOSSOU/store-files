import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/models/document.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/folder_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/tag_sheet.dart';
import '../../../shared/widgets/folder_export_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/document_thumbnail.dart';
import '../../../shared/theme/app_theme.dart';
import '../../scanner/screens/folder_picker_screen.dart';
import '../../document/screens/document_viewer_screen.dart';
import '../../folder/screens/folder_detail_screen.dart';
import '../../scanner/screens/scanner_screen.dart';
import '../../tags/screens/tag_filter_screen.dart';
import '../widgets/folder_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _folderService = FolderService();
  final _docService = DocumentService();
  final _tagService = TagService();

  List<Folder> _folders = [];
  Map<int, List<Tag>> _folderTags = {};
  bool _loading = true;
  bool _importing = false;
  String? _error;
  Map<int, int> _counts = {};
  List<Document> _recent = [];

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
      final folders = await _folderService.getRootFolders();
      final counts = await _folderService.getItemCounts();
      final recent = await _docService.getRecent();
      final tagsMap = <int, List<Tag>>{};
      for (final f in folders) {
        tagsMap[f.id!] = await _tagService.getTagsForFolder(f.id!);
      }
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _folderTags = tagsMap;
        _counts = counts;
        _recent = recent;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de charger tes documents.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    await _load();
  }

  Future<void> _search() async {
    final result = await showSearch<Object?>(
      context: context,
      delegate: _GlobalSearchDelegate(_folderService, _docService, _tagService),
    );
    if (!mounted || result == null) return;
    if (result is Folder) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FolderDetailScreen(folder: result)),
      );
    } else if (result is Document) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(document: result),
        ),
      );
    }
    await _load();
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    var imported = 0;
    try {
      final folder = await Navigator.push<Folder>(
        context,
        MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
      );
      if (folder == null || !mounted) return;
      final selection = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'png', 'jpg', 'jpeg'],
      );
      if (selection == null) return;
      for (final file in selection.files) {
        if (file.path != null) {
          await _docService.importFile(file.path!, folder.id!);
          imported++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$imported fichier(s) importé(s) dans « ${folder.name} ».',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import interrompu : $imported fichier(s) enregistré(s). Réessaie pour les autres.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
        await _load();
      }
    }
  }

  Future<void> _showCreateDialog({Folder? toEdit}) async {
    final nameCtrl = TextEditingController(text: toEdit?.name ?? '');
    final descCtrl = TextEditingController(text: toEdit?.description ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(toEdit == null ? 'Nouveau dossier' : 'Renommer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom du dossier *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optionnelle)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (toEdit == null) {
      await _folderService.create(
        nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
    } else {
      await _folderService.update(
        toEdit.copyWith(
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
        ),
      );
    }
    _load();
  }

  Future<void> _confirmDelete(Folder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le dossier ?'),
        content: Text(
          'Le dossier "${folder.name}" et tous ses fichiers seront supprimés définitivement.',
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
      await _folderService.delete(folder.id!);
      _load();
    }
  }

  void _openTagSheet(Folder folder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagSheet.forFolder(
        folderId: folder.id!,
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
        title: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'logo/playstore_icon.png',
            width: 34,
            height: 34,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Filtrer par étiquette',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TagFilterScreen()),
              );
              await _load();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Text(
                    'Tout à sa place.',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tes documents, simplement organisés.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Material(
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: InkWell(
                      onTap: _search,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Retrouver un document…',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _scan,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Scanner un document',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _importing ? null : _import,
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 20,
                          ),
                          label: Text(_importing ? 'Import…' : 'Importer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCreateDialog(),
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 20,
                          ),
                          label: const Text('Créer un dossier'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mes dossiers',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (!_loading)
                        Text(
                          '${_folders.length}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Chargement interrompu',
                      message: _error!,
                      actionLabel: 'Réessayer',
                      onAction: _load,
                    )
                  else if (_folders.isEmpty)
                    EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: 'Ton classeur commence ici',
                      message:
                          'Crée un dossier pour tes factures, tes papiers ou tes projets.',
                      actionLabel: 'Créer mon premier dossier',
                      onAction: () => _showCreateDialog(),
                    )
                  else
                    ..._folders.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FolderCard(
                          folder: f,
                          itemCount: _counts[f.id] ?? 0,
                          tags: _folderTags[f.id] ?? [],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FolderDetailScreen(folder: f),
                              ),
                            );
                            await _load();
                          },
                          onDelete: () => _confirmDelete(f),
                          onExport: () => showFolderExportDialog(context, f),
                          onEdit: () => _showCreateDialog(toEdit: f),
                          onManageTags: () => _openTagSheet(f),
                        ),
                      ),
                    ),
                  if (!_loading && _error == null && _recent.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Ajoutés récemment',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    ..._recent.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: DocumentThumbnail(document: doc, size: 48),
                            title: Text(
                              doc.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${doc.type.name.toUpperCase()} · ${doc.sizeLabel}',
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentViewerScreen(document: doc),
                                ),
                              );
                              await _load();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.offline_pin_outlined,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Sur ton appareil. Sans compte.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Recherche globale ────────────────────────────────────────────────────────

class _GlobalSearchDelegate extends SearchDelegate<Object?> {
  final FolderService _folderService;
  final DocumentService _docService;

  _GlobalSearchDelegate(this._folderService, this._docService, TagService _);

  @override
  String get searchFieldLabel => 'Dossiers, fichiers…';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Tape pour chercher…'));
    }

    return FutureBuilder<_SearchResult>(
      future: _search(query.trim()),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'Recherche indisponible',
            message: 'Réessaie dans un instant.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snap.data!;
        if (result.isEmpty) {
          return const Center(child: Text('Aucun résultat'));
        }
        return ListView(
          children: [
            if (result.folders.isNotEmpty) ...[
              _header(ctx, 'Dossiers'),
              ...result.folders.map(
                (f) => ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  title: Text(f.name),
                  subtitle: f.description != null ? Text(f.description!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => close(ctx, f),
                ),
              ),
            ],
            if (result.docs.isNotEmpty) ...[
              _header(ctx, 'Fichiers'),
              ...result.docs.map(
                (d) => ListTile(
                  leading: _docIcon(d),
                  title: Text(d.name),
                  subtitle: Text(
                    '${d.type.name.toUpperCase()} · ${d.sizeLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => close(ctx, d),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<_SearchResult> _search(String q) async {
    final folders = await _folderService.search(q);
    final docs = await _docService.search(q);
    return _SearchResult(folders, docs);
  }

  Widget _header(BuildContext ctx, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      label,
      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
        color: Theme.of(ctx).colorScheme.primary,
      ),
    ),
  );

  Widget _docIcon(Document d) {
    final (icon, color) = switch (d.type) {
      DocumentType.pdf => (Icons.picture_as_pdf, Colors.red.shade600),
      DocumentType.docx ||
      DocumentType.doc => (Icons.description, Colors.blue.shade600),
      DocumentType.png ||
      DocumentType.jpg ||
      DocumentType.jpeg => (Icons.image, Colors.green.shade600),
      _ => (Icons.insert_drive_file, Colors.grey),
    };
    return Icon(icon, color: color);
  }
}

class _SearchResult {
  final List<Folder> folders;
  final List<Document> docs;

  _SearchResult(this.folders, this.docs);

  bool get isEmpty => folders.isEmpty && docs.isEmpty;
}
