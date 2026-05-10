import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/document.dart';
import '../../../core/models/folder.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/document_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/tag_sheet.dart';
import '../../document/screens/document_viewer_screen.dart';
import '../widgets/document_card.dart';

// Écran générique pour naviguer dans un sous-dossier (profondeur n)
class SubfolderScreen extends StatefulWidget {
  final Folder folder;
  const SubfolderScreen({super.key, required this.folder});

  @override
  State<SubfolderScreen> createState() => _SubfolderScreenState();
}

class _SubfolderScreenState extends State<SubfolderScreen> {
  final _docService = DocumentService();
  final _tagService = TagService();

  List<Document> _docs = [];
  Map<int, List<Tag>> _docTags = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final docs = await _docService.getByFolder(widget.folder.id!);
    final tags = <int, List<Tag>>{};
    for (final d in docs) {
      tags[d.id!] = await _tagService.getTagsForDocument(d.id!);
    }
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _docTags = tags;
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

  Future<void> _deleteDoc(Document doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('« ${doc.name} » sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _docService.rename(doc, ctrl.text.trim());
      _load();
    }
  }

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
      appBar: AppBar(title: Text(widget.folder.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? const Center(child: Text('Dossier vide', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _docs.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = _docs[i];
                    return DocumentCard(
                      doc: d,
                      tags: _docTags[d.id] ?? [],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(document: d),
                        ),
                      ),
                      onDelete: () => _deleteDoc(d),
                      onShare: () => SharePlus.instance.share(
                        ShareParams(files: [XFile(d.filePath)]),
                      ),
                      onRename: () => _renameDoc(d),
                      onManageTags: () => _openDocTagSheet(d),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importFile,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importer'),
      ),
    );
  }
}
