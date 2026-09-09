import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:doc_manager/core/services/scanner_service.dart';
import 'package:doc_manager/features/scanner/screens/preview_screen.dart';

ScannedPage page(int red) {
  final image = img.Image(width: 40, height: 60);
  img.fill(image, color: img.ColorRgb8(red, 40, 100));
  return ScannedPage(
    originalBytes: Uint8List.fromList(img.encodePng(image)),
    imageSize: const Size(40, 60),
  );
}

void main() {
  testWidgets('Sélection, ordre et suppression modifient les pages du PDF', (
    tester,
  ) async {
    final first = page(10);
    final second = page(200);
    var updated = [first, second];
    await tester.pumpWidget(
      MaterialApp(
        home: PreviewScreen(
          pages: updated,
          onPagesUpdated: (pages) => updated = pages,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page 1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Déplacer après'));
    await tester.pumpAndSettle();
    expect(updated, [second, first]);
    expect(find.text('Page 2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Supprimer la page'));
    await tester.pumpAndSettle();
    expect(updated, [second]);
    expect(find.text('Page 1 / 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Supprimer la page'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune page'), findsOneWidget);
    expect(find.text('Créer le PDF'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Les actions restent accessibles sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PreviewScreen(pages: [page(100)], onPagesUpdated: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Recadrer'), findsOneWidget);
    expect(find.byTooltip('Reprendre la photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
