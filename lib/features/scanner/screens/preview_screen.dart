import 'package:flutter/material.dart';
import '../../../core/services/scanner_service.dart';
import 'crop_screen.dart';

enum PreviewAction { save, retake }

class PreviewResult {
  final PreviewAction action;
  final int? index;
  const PreviewResult(this.action, [this.index]);
}

class PreviewScreen extends StatefulWidget {
  final List<ScannedPage> pages;
  final ValueChanged<List<ScannedPage>> onPagesUpdated;
  final int initialIndex;
  const PreviewScreen({
    super.key,
    required this.pages,
    required this.onPagesUpdated,
    this.initialIndex = 0,
  });
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late List<ScannedPage> _pages;
  late int _index;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.pages);
    _index = widget.initialIndex;
  }

  void _notify() => widget.onPagesUpdated(List<ScannedPage>.from(_pages));

  Future<void> _crop() async {
    setState(() => _busy = true);
    final page = await Navigator.push<ScannedPage>(
      context,
      MaterialPageRoute(builder: (_) => CropScreen(page: _pages[_index])),
    );
    if (!mounted) return;
    setState(() {
      if (page != null) _pages[_index] = page;
      _busy = false;
    });
    _notify();
  }

  Future<void> _rotate() async {
    setState(() => _busy = true);
    try {
      final page = await ScannerService().rotatePage(_pages[_index]);
      if (!mounted) return;
      setState(() => _pages[_index] = page);
      _notify();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de tourner cette page.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _move(int delta) {
    setState(() {
      final page = _pages.removeAt(_index);
      _index += delta;
      _pages.insert(_index, page);
    });
    _notify();
  }

  void _delete() {
    setState(() {
      _pages.removeAt(_index);
      if (_index >= _pages.length) {
        _index = _pages.isEmpty ? 0 : _pages.length - 1;
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu du scan'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            tooltip: 'Ajouter une page',
            icon: const Icon(Icons.add_a_photo),
          ),
        ],
      ),
      body: _pages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aucune page'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Ajouter une page'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Page ${_index + 1} / ${_pages.length}'),
                ),
                Expanded(
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : InteractiveViewer(
                          key: ObjectKey(_pages[_index]),
                          minScale: 0.5,
                          maxScale: 4,
                          child: Center(
                            child: Image.memory(
                              _pages[_index].effectiveBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                ),
                SizedBox(
                  height: 88,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => Semantics(
                      label: 'Afficher la page ${i + 1}',
                      selected: i == _index,
                      child: InkWell(
                        onTap: _busy ? null : () => setState(() => _index = i),
                        child: Container(
                          width: 68,
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 3,
                              color: i == _index
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Image.memory(
                            _pages[i].effectiveBytes,
                            cacheWidth: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _busy || _index == 0
                            ? null
                            : () => _move(-1),
                        tooltip: 'Déplacer avant',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        onPressed: _busy || _index == _pages.length - 1
                            ? null
                            : () => _move(1),
                        tooltip: 'Déplacer après',
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _crop,
                        tooltip: 'Recadrer',
                        icon: const Icon(Icons.crop),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _rotate,
                        tooltip: 'Tourner',
                        icon: const Icon(Icons.rotate_right),
                      ),
                      IconButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.pop(
                                context,
                                PreviewResult(PreviewAction.retake, _index),
                              ),
                        tooltip: 'Reprendre la photo',
                        icon: const Icon(Icons.camera_alt),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _delete,
                        tooltip: 'Supprimer la page',
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.pop(
                                context,
                                const PreviewResult(PreviewAction.save),
                              ),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Créer le PDF'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}
