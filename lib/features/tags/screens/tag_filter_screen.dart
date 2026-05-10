import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/document.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/folder_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/doc_type_icon.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../document/screens/document_viewer_screen.dart';
import '../../folder/screens/folder_detail_screen.dart';

class TagFilterScreen extends StatefulWidget {
  const TagFilterScreen({super.key});

  @override
  State<TagFilterScreen> createState() => _TagFilterScreenState();
}

class _TagFilterScreenState extends State<TagFilterScreen> {
  final _tagService = TagService();
  final _folderService = FolderService();
  final _docService = DocumentService();

  List<Tag> _allTags = [];
  final Set<int> _selected = {};

  List<Folder> _folders = [];
  List<Document> _docs = [];
  Map<int, List<Tag>> _folderTags = {};
  Map<int, List<Tag>> _docTags = {};

  bool _loadingTags = true;
  bool _loadingResults = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _tagService.getAllTags();
    if (!mounted) return;
    setState(() {
      _allTags = tags;
      _loadingTags = false;
    });
  }

  Future<void> _applyFilter() async {
    if (_selected.isEmpty) {
      setState(() {
        _folders = [];
        _docs = [];
        _folderTags = {};
        _docTags = {};
      });
      return;
    }

    setState(() => _loadingResults = true);

    // Intersection : on cherche les items qui ont TOUS les tags sélectionnés
    List<Folder> folders = await _folderService.getByTag(_selected.first);
    List<Document> docs = await _docService.getByTag(_selected.first);

    for (final tagId in _selected.skip(1)) {
      final fByTag = await _folderService.getByTag(tagId);
      final dByTag = await _docService.getByTag(tagId);
      folders = folders.where((f) => fByTag.any((x) => x.id == f.id)).toList();
      docs = docs.where((d) => dByTag.any((x) => x.id == d.id)).toList();
    }

    final folderTags = <int, List<Tag>>{};
    final docTags = <int, List<Tag>>{};
    for (final f in folders) {
      folderTags[f.id!] = await _tagService.getTagsForFolder(f.id!);
    }
    for (final d in docs) {
      docTags[d.id!] = await _tagService.getTagsForDocument(d.id!);
    }

    if (!mounted) return;
    setState(() {
      _folders = folders;
      _docs = docs;
      _folderTags = folderTags;
      _docTags = docTags;
      _loadingResults = false;
    });
  }

  void _toggleTag(int tagId) {
    setState(() {
      if (_selected.contains(tagId)) {
        _selected.remove(tagId);
      } else {
        _selected.add(tagId);
      }
    });
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtrer par étiquette'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _selected.clear());
                _applyFilter();
              },
              child: const Text('Tout effacer'),
            ),
        ],
      ),
      body: _loadingTags
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTagBar(),
                const Divider(height: 1),
                Expanded(child: _buildResults()),
              ],
            ),
    );
  }

  Widget _buildTagBar() {
    if (_allTags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Aucune étiquette créée.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      width: double.infinity,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _allTags.map((t) {
          final active = _selected.contains(t.id);
          final color = Color(t.colorValue);
          return FilterChip(
            label: Text(t.label),
            selected: active,
            onSelected: (_) => _toggleTag(t.id!),
            selectedColor: color.withValues(alpha: 0.25),
            checkmarkColor: color,
            side: active ? BorderSide(color: color, width: 1.5) : null,
            avatar: active ? null : _dot(color),
          );
        }).toList(),
      ),
    );
  }

  Widget _dot(Color c) => CircleAvatar(radius: 5, backgroundColor: c);

  Widget _buildResults() {
    if (_selected.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Sélectionne une ou plusieurs étiquettes',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_loadingResults) {
      return const Center(child: CircularProgressIndicator());
    }

    final isEmpty = _folders.isEmpty && _docs.isEmpty;
    if (isEmpty) {
      return const Center(
        child: Text('Aucun résultat pour cette combinaison',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_folders.isNotEmpty) ...[
          _sectionLabel('Dossiers (${_folders.length})'),
          const SizedBox(height: 6),
          ..._folders.map((f) => _FolderResultTile(
                folder: f,
                tags: _folderTags[f.id] ?? [],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(folder: f)),
                ).then((_) => _applyFilter()),
              )),
          const SizedBox(height: 12),
        ],
        if (_docs.isNotEmpty) ...[
          _sectionLabel('Fichiers (${_docs.length})'),
          const SizedBox(height: 6),
          ..._docs.map((d) => _DocResultTile(
                doc: d,
                tags: _docTags[d.id] ?? [],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(document: d)),
                ).then((_) => _applyFilter()),
                onShare: () => SharePlus.instance
                    .share(ShareParams(files: [XFile(d.filePath)])),
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _FolderResultTile extends StatelessWidget {
  final Folder folder;
  final List<Tag> tags;
  final VoidCallback onTap;

  const _FolderResultTile(
      {required this.folder, required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.folder, color: cs.primary),
        title: Text(folder.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: tags.isNotEmpty
            ? Wrap(
                spacing: 4,
                runSpacing: 2,
                children: tags.map((t) => TagChip(tag: t)).toList(),
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DocResultTile extends StatelessWidget {
  final Document doc;
  final List<Tag> tags;
  final VoidCallback onTap;
  final VoidCallback onShare;

  const _DocResultTile({
    required this.doc,
    required this.tags,
    required this.onTap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: DocTypeIcon(type: doc.type, size: 28),
        title: Text(doc.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${doc.type.name.toUpperCase()} · ${doc.sizeLabel}',
                style: const TextStyle(fontSize: 12)),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: tags.map((t) => TagChip(tag: t)).toList(),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: onShare,
        ),
        onTap: onTap,
        isThreeLine: tags.isNotEmpty,
      ),
    );
  }
}
