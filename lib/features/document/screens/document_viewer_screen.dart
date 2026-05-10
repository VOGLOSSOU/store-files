import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/document.dart';
import '../../../core/models/tag.dart';
import '../../../core/services/tag_service.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/tag_sheet.dart';

class DocumentViewerScreen extends StatefulWidget {
  final Document document;
  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final _tagService = TagService();
  List<Tag> _tags = [];
  int _pdfPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await _tagService.getTagsForDocument(widget.document.id!);
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  void _share() {
    SharePlus.instance.share(
      ShareParams(files: [XFile(widget.document.filePath)]),
    );
  }

  void _showTagSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagSheet.forDocument(
        documentId: widget.document.id!,
        tagService: _tagService,
        onChanged: _loadTags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Étiquettes',
            onPressed: _showTagSheet,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
            onPressed: _share,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tags.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _tags.map((t) => TagChip(tag: t)).toList(),
              ),
            ),
          Expanded(child: _buildViewer()),
          if (widget.document.type.isPdf && _pdfPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Page ${_currentPage + 1} / $_pdfPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    final doc = widget.document;

    if (doc.type.isPdf) {
      return PDFView(
        filePath: doc.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) => setState(() => _pdfPages = pages ?? 0),
        onPageChanged: (page, _) =>
            setState(() => _currentPage = page ?? 0),
        onError: (e) => _errorWidget(e.toString()),
      );
    }

    if (doc.type.isImage) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(
            File(doc.filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, e, stack) =>
                _errorWidget(e.toString()),
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Aperçu non disponible pour .${doc.type.name}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share),
            label: const Text('Ouvrir avec une autre app'),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(msg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
}
