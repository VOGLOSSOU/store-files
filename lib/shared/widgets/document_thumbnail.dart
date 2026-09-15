import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/document.dart';
import '../../core/services/thumbnail_service.dart';
import 'doc_type_icon.dart';

class DocumentThumbnail extends StatefulWidget {
  final Document document;
  final double size;
  const DocumentThumbnail({super.key, required this.document, this.size = 56});

  @override
  State<DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends State<DocumentThumbnail> {
  String? _thumbPath;
  bool _tried = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.document.type.isPdf) {
      _initThumb();
    }
  }

  @override
  void didUpdateWidget(covariant DocumentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.filePath != widget.document.filePath ||
        oldWidget.document.type != widget.document.type) {
      _request++;
      _thumbPath = null;
      _tried = false;
      if (widget.document.type.isPdf) _initThumb();
    }
  }

  Future<void> _initThumb() async {
    final request = ++_request;
    final generated = await ThumbnailService.ensureThumbnail(widget.document);
    if (!mounted || request != _request) return;
    setState(() {
      _thumbPath = generated;
      _tried = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerLow,
      alignment: Alignment.center,
      child: DocTypeIcon(type: widget.document.type, size: widget.size * 0.48),
    );

    Widget child;

    if (widget.document.type.isImage) {
      child = Image.file(
        File(widget.document.filePath),
        fit: BoxFit.cover,
        cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, e, s) => fallback,
      );
    } else if (widget.document.type.isPdf && _thumbPath != null) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_thumbPath!),
            fit: BoxFit.cover,
            cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, e, s) => fallback,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (widget.document.type.isPdf && !_tried) {
      // Encore en cours de génération : indicateur subtil
      child = Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          const Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          ),
        ],
      );
    } else {
      child = fallback;
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}
