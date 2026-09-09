import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/document.dart';
import 'document_service.dart';

class ScannedPage {
  final Uint8List originalBytes;
  final Uint8List? croppedBytes;
  final List<Offset>? cropQuad;
  final Size imageSize;

  const ScannedPage({
    required this.originalBytes,
    required this.imageSize,
    this.croppedBytes,
    this.cropQuad,
  });

  Uint8List get effectiveBytes => croppedBytes ?? originalBytes;
}

class ScannerService {
  Future<ScannedPage> preparePage(Uint8List bytes) => compute(_prepare, bytes);

  Future<ScannedPage> rotatePage(ScannedPage page) =>
      compute(_rotate, page.effectiveBytes);

  Future<ScannedPage> cropPage(ScannedPage page, List<Offset> quad) async {
    final bytes = await compute(_crop, (page.originalBytes, quad));
    return ScannedPage(
      originalBytes: page.originalBytes,
      imageSize: page.imageSize,
      croppedBytes: bytes,
      cropQuad: List.unmodifiable(quad),
    );
  }

  Future<Uint8List> generatePdf(List<Uint8List> pages) => compute(_pdf, pages);

  /// The staging file is private to this save; import owns the permanent copy.
  Future<Document> saveDocument({
    required List<ScannedPage> pages,
    required String name,
    required int folderId,
  }) async {
    final title = normalizeName(name);
    if (title.isEmpty) throw const FormatException('Donne un nom au document.');
    final bytes = await generatePdf(
      pages.map((p) => p.effectiveBytes).toList(),
    );
    final root = await getTemporaryDirectory();
    final staging = await root.createTemp('scan_');
    try {
      final file = File('${staging.path}/$title.pdf');
      await file.writeAsBytes(bytes, flush: true);
      return await DocumentService().importFile(file.path, folderId);
    } finally {
      // A cleanup failure must not turn a successful import into a retry.
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // The OS can reclaim temporary files later.
      }
    }
  }

  static String normalizeName(String name) => name
      .trim()
      .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_')
      .trim();
}

img.Image _decode(Uint8List bytes) {
  try {
    final image = bytes.isEmpty ? null : img.decodeImage(bytes);
    if (image != null) return image;
  } catch (_) {
    // Decoders can throw on truncated data instead of returning null.
  }
  throw const FormatException('Image illisible. Reprends la photo.');
}

ScannedPage _page(img.Image image) => ScannedPage(
  originalBytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
  imageSize: Size(image.width.toDouble(), image.height.toDouble()),
);

ScannedPage _prepare(Uint8List bytes) {
  var image = img.bakeOrientation(_decode(bytes));
  // Bound memory use while retaining enough detail for an A4 document.
  if (math.max(image.width, image.height) > 2400) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 2400)
        : img.copyResize(image, height: 2400);
  }
  return _page(image);
}

ScannedPage _rotate(Uint8List bytes) =>
    _page(img.copyRotate(_decode(bytes), angle: 90));

Uint8List _crop((Uint8List, List<Offset>) input) {
  final image = _decode(input.$1);
  final quad = input.$2;
  if (quad.length != 4) throw const FormatException('Sélection invalide.');
  for (var i = 0; i < 4; i++) {
    final p = quad[i];
    final a = quad[(i + 1) % 4] - p;
    final b = quad[(i + 2) % 4] - quad[(i + 1) % 4];
    if (!p.dx.isFinite ||
        !p.dy.isFinite ||
        p.dx < 0 ||
        p.dy < 0 ||
        p.dx > image.width - 1 ||
        p.dy > image.height - 1 ||
        a.dx * b.dy - a.dy * b.dx <= 0) {
      throw const FormatException(
        'Les coins doivent former un cadre sans croisement.',
      );
    }
  }
  final width = math
      .max((quad[1] - quad[0]).distance, (quad[2] - quad[3]).distance)
      .round();
  final height = math
      .max((quad[3] - quad[0]).distance, (quad[2] - quad[1]).distance)
      .round();
  if (width < 16 || height < 16) {
    throw const FormatException('Le cadre est trop petit.');
  }
  img.Point point(int i) => img.Point(quad[i].dx, quad[i].dy);
  final cropped = img.copyRectify(
    image,
    topLeft: point(0),
    topRight: point(1),
    bottomRight: point(2),
    bottomLeft: point(3),
    interpolation: img.Interpolation.linear,
    toImage: img.Image(width: width, height: height),
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
}

Future<Uint8List> _pdf(List<Uint8List> pages) async {
  if (pages.isEmpty) throw const FormatException('Ajoute au moins une page.');
  final pdf = pw.Document();
  for (final bytes in pages) {
    final image = _decode(bytes);
    pdf.addPage(
      pw.Page(
        pageFormat: image.width > image.height
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      ),
    );
  }
  return pdf.save();
}
