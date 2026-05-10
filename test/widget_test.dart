import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:doc_manager/app.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App démarre et affiche l\'écran d\'accueil', (tester) async {
    await tester.pumpWidget(const DocManagerApp());
    await tester.pump(); // premier frame — AppBar déjà rendu
    expect(find.text('Mon Classeur'), findsOneWidget);
  });
}
