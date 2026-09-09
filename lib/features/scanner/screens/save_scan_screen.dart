import 'package:flutter/material.dart';
import '../../../core/models/folder.dart';
import '../../../core/services/folder_service.dart';
import '../../../core/services/scanner_service.dart';
import 'folder_picker_screen.dart';

class SaveScanScreen extends StatefulWidget {
  final List<ScannedPage> pages;
  final int? initialFolderId;
  const SaveScanScreen({super.key, required this.pages, this.initialFolderId});
  @override
  State<SaveScanScreen> createState() => _SaveScanScreenState();
}

class _SaveScanScreenState extends State<SaveScanScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  Folder? _folder;
  bool _busy = false;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    final date = DateTime.now();
    _name = TextEditingController(
      text:
          'Scan ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
    _loadFolder();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadFolder() async {
    try {
      final folder = widget.initialFolderId == null
          ? null
          : await FolderService().getById(widget.initialFolderId!);
      if (mounted) setState(() => _folder = folder);
    } catch (_) {
      if (mounted) {
        _error('Sélectionne un dossier pour enregistrer le document.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pick() async {
    final folder = await Navigator.push<Folder>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(initialFolderId: _folder?.id),
      ),
    );
    if (folder != null && mounted) setState(() => _folder = folder);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_folder == null) {
      await _pick();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final document = await ScannerService().saveDocument(
        pages: widget.pages,
        name: _name.text,
        folderId: _folder!.id!,
      );
      if (!mounted) return;
      // Re-enable the route before popping a completed save.
      setState(() => _busy = false);
      Navigator.pop(context, document);
    } catch (_) {
      if (mounted) {
        _error(
          'Enregistrement impossible. Vérifie l’espace disponible et le dossier, puis réessaie. Tes pages sont conservées.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Enregistrer le PDF')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${widget.pages.length} page(s)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Nom du document',
                suffixText: '.pdf',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  ScannerService.normalizeName(value ?? '').isEmpty
                  ? 'Donne un nom au document.'
                  : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder),
              title: Text(
                _loading
                    ? 'Chargement…'
                    : _folder?.name ?? 'Choisir un dossier',
              ),
              subtitle: const Text('Dossier ou sous-dossier de destination'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy || _loading ? null : _pick,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || _loading ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_busy ? 'Création du PDF…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    ),
  );
}
