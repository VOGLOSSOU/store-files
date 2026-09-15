import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:doc_manager/core/database/database_helper.dart';
import 'package:doc_manager/core/services/document_service.dart';
import 'package:doc_manager/core/services/folder_service.dart';
import 'package:doc_manager/core/services/scanner_service.dart';

Uint8List fixture() {
  final image = img.Image(width: 120, height: 80);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  img.fillRect(
    image,
    x1: 30,
    y1: 20,
    x2: 89,
    y2: 59,
    color: img.ColorRgb8(0, 255, 0),
  );
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ScannerService();

  test('Recadrage réel : dimensions et contenu de la zone choisie', () async {
    final original = await service.preparePage(fixture());
    final cropped = await service.cropPage(original, const [
      Offset(32, 22),
      Offset(87, 22),
      Offset(87, 57),
      Offset(32, 57),
    ]);
    final image = img.decodeImage(cropped.effectiveBytes)!;
    expect(image.width, 55);
    expect(image.height, 35);
    expect(image.getPixel(10, 10).g, greaterThan(220));
    expect(image.getPixel(10, 10).r, lessThan(30));
    expect(cropped.originalBytes, same(original.originalBytes));
  });

  test(
    'Rotation du résultat recadré, puis nouveau recadrage possible',
    () async {
      final page = await service.preparePage(fixture());
      final cropped = await service.cropPage(page, const [
        Offset(32, 22),
        Offset(87, 22),
        Offset(87, 57),
        Offset(32, 57),
      ]);
      final rotated = await service.rotatePage(cropped);
      expect(rotated.imageSize, const Size(35, 55));
      final result = await service.cropPage(rotated, const [
        Offset(1, 1),
        Offset(33, 1),
        Offset(33, 53),
        Offset(1, 53),
      ]);
      expect(img.decodeImage(result.effectiveBytes)!.width, 32);
    },
  );

  test('Images invalides, cadres croisés et PDF vide sont refusés', () async {
    await expectLater(service.preparePage(Uint8List(0)), throwsFormatException);
    await expectLater(service.generatePdf([]), throwsFormatException);
    final page = await service.preparePage(fixture());
    await expectLater(
      service.cropPage(page, const [
        Offset(0, 0),
        Offset(119, 79),
        Offset(119, 0),
        Offset(0, 79),
      ]),
      throwsFormatException,
    );
  });

  test('PDF avec une ou plusieurs pages dans l’ordre fourni', () async {
    final first = await service.preparePage(fixture());
    final second = await service.rotatePage(first);
    for (final pages in [
      [first],
      [first, second],
    ]) {
      final bytes = await service.generatePdf(
        pages.map((p) => p.effectiveBytes).toList(),
      );
      final text = latin1.decode(bytes);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, pages.length);
      expect(text, contains('%%EOF'));
    }
  });

  test(
    'Enregistrement dans un dossier profond, sans copie temporaire restante',
    () async {
      final root = await Directory.systemTemp.createTemp('arca_scan_test_');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath('${root.path}/db');
      final documents = Directory('${root.path}/app')..createSync();
      final temporary = Directory('${root.path}/tmp')..createSync();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async {
              if (call.method == 'getApplicationDocumentsDirectory') {
                return documents.path;
              }
              if (call.method == 'getTemporaryDirectory') return temporary.path;
              return null;
            },
          );
      try {
        final folders = FolderService();
        final parent = await folders.create('Administratif');
        final child = await folders.create('Identité', parentId: parent.id);
        final leaf = await folders.create('2026', parentId: child.id);
        final page = await service.preparePage(fixture());
        final first = await service.saveDocument(
          pages: [page, page],
          name: 'Mon document.pdf',
          folderId: leaf.id!,
        );
        final second = await service.saveDocument(
          pages: [page],
          name: 'Mon document.pdf',
          folderId: leaf.id!,
        );
        expect(first.name, 'Mon document');
        expect(first.filePath, isNot(second.filePath));
        expect((await DocumentService().getByFolder(leaf.id!)).length, 2);
        expect(await File(first.filePath).exists(), isTrue);
        expect(await temporary.list().toList(), isEmpty);
        final docs1 = await Directory('${documents.path}/documents')
            .list()
            .where((e) => e.path.endsWith('.pdf'))
            .toList();
        expect(docs1.length, 2);
        await expectLater(
          service.saveDocument(pages: [page], name: 'Échec', folderId: -1),
          throwsA(isA<DatabaseException>()),
        );
        final docs2 = await Directory('${documents.path}/documents')
            .list()
            .where((e) => e.path.endsWith('.pdf'))
            .toList();
        expect(docs2.length, 2);
        expect(await temporary.list().toList(), isEmpty);
      } finally {
        await (await DatabaseHelper.instance.database).close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
        await root.delete(recursive: true);
      }
    },
  );
}
