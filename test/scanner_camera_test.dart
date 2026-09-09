import 'dart:async';
import 'dart:io';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:doc_manager/features/scanner/screens/scanner_screen.dart';

class FakeCamera extends CameraPlatform {
  final Directory directory;
  bool denied = false;
  int captures = 0;
  int opened = 0;
  int disposed = 0;
  FakeCamera(this.directory);
  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (denied) throw CameraException('CameraAccessDenied', 'Denied');
    return const [
      CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ];
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings settings,
  ) async {
    expect(settings.enableAudio, isFalse);
    return ++opened;
  }

  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(
    CameraInitializedEvent(
      id,
      120,
      160,
      ExposureMode.auto,
      true,
      FocusMode.auto,
      true,
    ),
  );
  @override
  Stream<CameraErrorEvent> onCameraError(int id) =>
      StreamController<CameraErrorEvent>().stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Widget buildPreview(int id) =>
      const ColoredBox(key: Key('fake-camera-preview'), color: Colors.grey);
  @override
  Future<void> dispose(int id) async {
    disposed++;
  }

  @override
  Future<void> setFlashMode(int id, FlashMode mode) async {}
  @override
  Future<XFile> takePicture(int id) async {
    final image = img.Image(width: 120, height: 160);
    img.fill(image, color: img.ColorRgb8(100, 60, 20));
    final file = File('${directory.path}/photo_${++captures}.jpg');
    await file.writeAsBytes(img.encodeJpg(image));
    return XFile(file.path);
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while ((finder.evaluate().isEmpty ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty) &&
      DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

void main() {
  late Directory directory;
  late FakeCamera camera;
  late CameraPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('arca_camera_');
    previous = CameraPlatform.instance;
    camera = FakeCamera(directory);
    CameraPlatform.instance = camera;
  });
  tearDown(() async {
    CameraPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  testWidgets('Capture multiple, reprise et protection des pages au retour', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScannerScreen()));
    await waitFor(tester, find.byKey(const Key('fake-camera-preview')));
    for (var i = 1; i <= 2; i++) {
      await tester.tap(find.byTooltip('Photographier la page'));
      await waitFor(tester, find.text('Scanner · $i page(s)'));
    }
    await tester.tap(find.text('Voir les pages'));
    await waitFor(tester, find.text('Page 1 / 2'));
    expect(camera.disposed, greaterThanOrEqualTo(1));
    await tester.tap(find.byTooltip('Reprendre la photo'));
    await waitFor(tester, find.text('Reprendre la page 1'));
    await waitFor(tester, find.byKey(const Key('fake-camera-preview')));
    await tester.tap(find.byTooltip('Photographier la page'));
    await waitFor(tester, find.text('Page 1 / 2'));
    expect(camera.captures, 3);
    await tester.tap(find.byTooltip('Ajouter une page'));
    await waitFor(tester, find.byKey(const Key('fake-camera-preview')));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Quitter le scan ?'), findsOneWidget);
    await tester.tap(find.text('Continuer le scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scanner · 2 page(s)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Permission refusée puis accordée et reprise après arrière-plan',
    (tester) async {
      camera.denied = true;
      await tester.pumpWidget(const MaterialApp(home: ScannerScreen()));
      await waitFor(
        tester,
        find.text('Autorise l’accès à la caméra pour scanner tes documents.'),
      );
      expect(find.text('Ouvrir les paramètres'), findsOneWidget);
      camera.denied = false;
      await tester.tap(find.text('Réessayer'));
      await waitFor(tester, find.byKey(const Key('fake-camera-preview')));
      final opened = camera.opened;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(camera.disposed, greaterThanOrEqualTo(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await waitFor(tester, find.byKey(const Key('fake-camera-preview')));
      expect(camera.opened, greaterThan(opened));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
