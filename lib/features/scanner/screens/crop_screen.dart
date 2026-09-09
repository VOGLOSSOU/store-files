import 'package:flutter/material.dart';
import '../../../core/services/scanner_service.dart';
import '../widgets/crop_overlay.dart';

class CropScreen extends StatefulWidget {
  final ScannedPage page;
  const CropScreen({super.key, required this.page});
  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late List<Offset> _quad;
  bool _busy = false;
  List<Offset> get _full => [
    Offset.zero,
    Offset(widget.page.imageSize.width - 1, 0),
    Offset(widget.page.imageSize.width - 1, widget.page.imageSize.height - 1),
    Offset(0, widget.page.imageSize.height - 1),
  ];
  @override
  void initState() {
    super.initState();
    _quad = List.from(widget.page.cropQuad ?? _full);
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final page = await ScannerService().cropPage(widget.page, _quad);
      if (mounted) Navigator.pop(context, page);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Impossible de recadrer cette page.',
            ),
          ),
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
      appBar: AppBar(title: const Text('Recadrer la page')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Déplace les quatre coins sur les bords du document.'),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.page.imageSize.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Image.memory(widget.page.originalBytes, fit: BoxFit.fill),
                      IgnorePointer(
                        ignoring: _busy,
                        child: CropOverlay(
                          imageSize: widget.page.imageSize,
                          quad: _quad,
                          onQuadChanged: (quad) => setState(() => _quad = quad),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _quad = _full),
                    child: const Text('Réinitialiser'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _apply,
                    child: Text(_busy ? 'Recadrage…' : 'Valider'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
