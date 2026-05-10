import '../database/database_helper.dart';
import '../models/folder.dart';

class FolderService {
  final _db = DatabaseHelper.instance;

  Future<List<Folder>> getRootFolders() async {
    final db = await _db.database;
    final rows = await db.query(
      'folders',
      where: 'parent_id IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<Folder>> getSubFolders(int parentId) async {
    final db = await _db.database;
    final rows = await db.query(
      'folders',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<Folder> create(String name, {String? description, int? parentId}) async {
    final db = await _db.database;
    final folder = Folder(
      name: name,
      description: description,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    final id = await db.insert('folders', folder.toMap()..remove('id'));
    return folder.copyWith(id: id);
  }

  Future<void> update(Folder folder) async {
    final db = await _db.database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Folder>> search(String query) async {
    final db = await _db.database;
    final rows = await db.query(
      'folders',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<Folder>> getByTag(int tagId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT f.* FROM folders f
      JOIN tag_bindings tb ON tb.folder_id = f.id
      WHERE tb.tag_id = ?
      ORDER BY f.name ASC
    ''', [tagId]);
    return rows.map(Folder.fromMap).toList();
  }
}
