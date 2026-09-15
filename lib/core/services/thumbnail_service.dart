import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/document.dart';

class ThumbnailService {
  static const _channel = MethodChannel('com.devapp.doc_manager/pdf_thumbnail');

  static final _pending = <String, Future<String?>>{};

  static Future<void> waitForPending(String path) async {
    await _pending[path];
  }

  static String thumbPathFor(String filePath) => '$filePath.thumb.jpg';

  static bool hasThumbnail(String filePath) {
    try {
      return File(thumbPathFor(filePath)).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Génère la miniature d'un PDF :
  /// - Soit à partir des octets de la première page déjà en mémoire (ex: scan)
  /// - Soit via le PdfRenderer natif d'Android (ex: document importé)
  static Future<String?> generatePdfThumbnail(
    String pdfPath, {
    Uint8List? firstPageBytes,
  }) {
    return _pending.putIfAbsent(pdfPath, () {
      return _generate(pdfPath, firstPageBytes: firstPageBytes).whenComplete(() {
        _pending.remove(pdfPath);
      });
    });
  }

  static Future<String?> _generate(
    String pdfPath, {
    Uint8List? firstPageBytes,
  }) async {
    final thumbPath = thumbPathFor(pdfPath);
    try {
      if (!await File(pdfPath).exists()) return null;
      if (await File(thumbPath).exists()) return thumbPath;
      if (firstPageBytes != null && firstPageBytes.isNotEmpty) {
        await compute(_saveThumbFromBytes, (firstPageBytes, thumbPath));
        if (!await File(pdfPath).exists()) {
          if (await File(thumbPath).exists()) await File(thumbPath).delete();
          return null;
        }
        return await File(thumbPath).exists() ? thumbPath : null;
      }

      // Si aucun octet direct n'est fourni, on tente le rendu natif Android
      final success = await _channel.invokeMethod<bool>('renderFirstPage', {
        'pdfPath': pdfPath,
        'thumbPath': thumbPath,
        'maxWidth': 360,
      });

      if (!await File(pdfPath).exists()) {
        if (await File(thumbPath).exists()) await File(thumbPath).delete();
        return null;
      }
      if (success == true && await File(thumbPath).exists()) {
        return thumbPath;
      }
    } catch (e) {
      debugPrint('ThumbnailService: échec génération miniature: $e');
    }
    return null;
  }

  /// S'assure qu'une miniature existe pour le document (si c'est un PDF).
  static Future<String?> ensureThumbnail(Document doc) async {
    if (!doc.type.isPdf) return null;
    return generatePdfThumbnail(doc.filePath);
  }
}

Future<void> _saveThumbFromBytes((Uint8List, String) args) async {
  final (bytes, outPath) = args;
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return;
    final resized = image.width > image.height
        ? img.copyResize(image, width: 360)
        : img.copyResize(image, height: 360);
    final jpg = img.encodeJpg(resized, quality: 80);
    final file = File(outPath);
    await file.writeAsBytes(jpg, flush: true);
  } catch (e) {
    debugPrint('ThumbnailService isolate error: $e');
  }
}
