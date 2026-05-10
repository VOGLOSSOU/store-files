import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/document.dart';

class DocumentService {
  final _db = DatabaseHelper.instance;

  Future<String> get _storageDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/documents');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<List<Document>> getByFolder(int folderId) async {
    final db = await _db.database;
    final rows = await db.query(
      'documents',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'imported_at DESC',
    );
    return rows.map(Document.fromMap).toList();
  }

  Future<Document> importFile(String sourcePath, int folderId) async {
    final storageDir = await _storageDir;
    final fileName = _uniqueFileName(sourcePath);
    final destPath = '$storageDir/$fileName';

    await File(sourcePath).copy(destPath);

    final stat = await File(destPath).stat();
    final ext = p.extension(sourcePath).replaceFirst('.', '');
    final type = DocumentTypeExt.fromExtension(ext);

    final doc = Document(
      name: p.basenameWithoutExtension(sourcePath),
      filePath: destPath,
      type: type,
      folderId: folderId,
      fileSizeBytes: stat.size,
      importedAt: DateTime.now(),
    );

    final db = await _db.database;
    final map = doc.toMap()..remove('id');
    final id = await db.insert('documents', map);
    return Document(
      id: id,
      name: doc.name,
      filePath: doc.filePath,
      type: doc.type,
      folderId: doc.folderId,
      fileSizeBytes: doc.fileSizeBytes,
      importedAt: doc.importedAt,
    );
  }

  Future<void> delete(Document doc) async {
    final db = await _db.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [doc.id]);
    final file = File(doc.filePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> rename(Document doc, String newName) async {
    final db = await _db.database;
    await db.update(
      'documents',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<List<Document>> search(String query) async {
    final db = await _db.database;
    final rows = await db.query(
      'documents',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return rows.map(Document.fromMap).toList();
  }

  Future<List<Document>> getByTag(int tagId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT d.* FROM documents d
      JOIN tag_bindings tb ON tb.document_id = d.id
      WHERE tb.tag_id = ?
      ORDER BY d.name ASC
    ''', [tagId]);
    return rows.map(Document.fromMap).toList();
  }

  String _uniqueFileName(String sourcePath) {
    final ext = p.extension(sourcePath);
    final base = p.basenameWithoutExtension(sourcePath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${base}_$ts$ext';
  }
}
