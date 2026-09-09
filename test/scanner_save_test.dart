import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:doc_manager/core/database/database_helper.dart';
import 'package:doc_manager/core/models/document.dart';
import 'package:doc_manager/core/services/document_service.dart';
import 'package:doc_manager/core/services/folder_service.dart';
import 'package:doc_manager/core/services/scanner_service.dart';
import 'package:doc_manager/features/scanner/screens/save_scan_screen.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while ((finder.evaluate().isEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty) &&
      DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Choisir un autre dossier, créer un sous-dossier et enregistrer le PDF',
    (tester) async {
      late Directory temporary;
      late int originalId;
      await tester.runAsync(() async {
        temporary = await Directory.systemTemp.createTemp('arca_save_ui_');
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        await databaseFactory.setDatabasesPath(temporary.path);
        final service = FolderService();
        originalId = (await service.create('Départ')).id!;
        final other = await service.create('Archives');
        await service.create('Travail', parentId: other.id);
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temporary.path,
      );
      final image = img.Image(width: 40, height: 60);
      final page = ScannedPage(
        originalBytes: Uint8List.fromList(img.encodePng(image)),
        imageSize: const Size(40, 60),
      );
      Document? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.push<Document>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SaveScanScreen(
                        pages: [page, page],
                        initialFolderId: originalId,
                      ),
                    ),
                  );
                },
                child: const Text('Ouvrir le scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir le scan'));
      await waitFor(tester, find.text('Départ'));
      await tester.enterText(find.byType(TextFormField), 'Contrat.pdf');
      await tester.tap(find.text('Départ'));
      await waitFor(tester, find.text('Classer dans « Départ »'));
      await tester.tap(find.text('Tous les dossiers'));
      await waitFor(tester, find.text('Archives'));
      await tester.tap(find.text('Archives'));
      await waitFor(tester, find.text('Travail'));
      await tester.tap(find.text('Travail'));
      await waitFor(tester, find.text('Classer dans « Travail »'));
      await tester.tap(find.byTooltip('Créer un dossier ici'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '2026');
      await tester.tap(find.text('Créer'));
      await waitFor(tester, find.text('Classer dans « 2026 »'));
      await tester.tap(find.text('Classer dans « 2026 »'));
      await waitFor(tester, find.text('Enregistrer le PDF'));
      await tester.tap(find.text('Enregistrer'));
      await waitFor(tester, find.text('Ouvrir le scan'));
      expect(saved, isNotNull);
      expect(saved!.name, 'Contrat');
      await tester.runAsync(() async {
        final folder = await FolderService().getById(saved!.folderId);
        expect(folder!.name, '2026');
        expect(
          (await DocumentService().getByFolder(saved!.folderId)).length,
          1,
        );
        expect(await File(saved!.filePath).exists(), isTrue);
        expect(await DocumentService().getByFolder(originalId), isEmpty);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await (await DatabaseHelper.instance.database).close();
        await temporary.delete(recursive: true);
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    },
  );
}
