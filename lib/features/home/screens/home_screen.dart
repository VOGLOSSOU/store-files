import 'package:flutter/material.dart';
import '../../../core/models/document.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/folder_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/tag_sheet.dart';
import '../../document/screens/document_viewer_screen.dart';
import '../../folder/screens/folder_detail_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final folders = await _folderService.getRootFolders();
    final tagsMap = <int, List<Tag>>{};
    for (final f in folders) {
      tagsMap[f.id!] = await _tagService.getTagsForFolder(f.id!);
    }
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _folderTags = tagsMap;
      _loading = false;
    });
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
              child: const Text('Annuler')),
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
        description:
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
    } else {
      await _folderService.update(toEdit.copyWith(
        name: nameCtrl.text.trim(),
        description:
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      ));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Classeur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Filtrer par étiquette',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagFilterScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Recherche globale',
            onPressed: () => showSearch(
              context: context,
              delegate: _GlobalSearchDelegate(
                  _folderService, _docService, _tagService),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _folders.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final f = _folders[i];
                      return FolderCard(
                        folder: f,
                        tags: _folderTags[f.id] ?? [],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderDetailScreen(folder: f),
                          ),
                        ).then((_) => _load()),
                        onDelete: () => _confirmDelete(f),
                        onEdit: () => _showCreateDialog(toEdit: f),
                        onManageTags: () => _openTagSheet(f),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        tooltip: 'Nouveau dossier',
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucun dossier',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Appuie sur + pour créer ton premier dossier',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
}

// ── Recherche globale ────────────────────────────────────────────────────────

class _GlobalSearchDelegate extends SearchDelegate {
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
              ...result.folders.map((f) => ListTile(
                    leading: Icon(Icons.folder,
                        color: Theme.of(ctx).colorScheme.primary),
                    title: Text(f.name),
                    subtitle: f.description != null ? Text(f.description!) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      close(ctx, null);
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => FolderDetailScreen(folder: f)),
                      );
                    },
                  )),
            ],
            if (result.docs.isNotEmpty) ...[
              _header(ctx, 'Fichiers'),
              ...result.docs.map((d) => ListTile(
                    leading: _docIcon(d),
                    title: Text(d.name),
                    subtitle: Text(
                        '${d.type.name.toUpperCase()} · ${d.sizeLabel}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      close(ctx, null);
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => DocumentViewerScreen(document: d)),
                      );
                    },
                  )),
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
      DocumentType.docx || DocumentType.doc =>
        (Icons.description, Colors.blue.shade600),
      DocumentType.png ||
      DocumentType.jpg ||
      DocumentType.jpeg =>
        (Icons.image, Colors.green.shade600),
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
