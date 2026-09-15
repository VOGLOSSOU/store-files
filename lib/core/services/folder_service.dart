import 'file_cleanup_service.dart';
import '../database/database_helper.dart';
import '../models/folder.dart';

class FolderService {
  final _db = DatabaseHelper.instance;

  Future<Folder?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Folder.fromMap(rows.first);
  }

  /// Counts direct children without a query for each card.
  Future<Map<int, int>> getItemCounts() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT parent_id AS folder_id, COUNT(*) AS total FROM (
        SELECT parent_id FROM folders WHERE parent_id IS NOT NULL
        UNION ALL SELECT folder_id AS parent_id FROM documents
      ) GROUP BY parent_id
    ''');
    return {
      for (final row in rows) row['folder_id'] as int: row['total'] as int,
    };
  }

  Future<List<Folder>> getPath(int id) async {
    final path = <Folder>[];
    final visited = <int>{};
    int? current = id;
    while (current != null && visited.add(current)) {
      final folder = await getById(current);
      if (folder == null) break;
      path.insert(0, folder);
      current = folder.parentId;
    }
    return path;
  }

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

  Future<Folder> create(
    String name, {
    String? description,
    int? parentId,
  }) async {
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
    await db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        WITH RECURSIVE descendants(id) AS (
          SELECT id FROM folders WHERE id = ?
          UNION
          SELECT f.id FROM folders f JOIN descendants d ON f.parent_id = d.id
        )
        SELECT file_path FROM documents
        WHERE folder_id IN (SELECT id FROM descendants)
      ''', [id]);
      for (final row in rows) {
        await FileCleanupService.enqueue(txn, row['file_path'] as String);
      }
      await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
    });
    await FileCleanupService.drain(db);
  }

  Future<List<Folder>> search(String query) async {
    final db = await _db.database;
    final rows = await db.query(
      'folders',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<List<Folder>> getByTag(int tagId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT f.* FROM folders f
      JOIN folder_tag_bindings tb ON tb.folder_id = f.id
      WHERE tb.tag_id = ?
      ORDER BY f.name ASC
    ''',
      [tagId],
    );
    return rows.map(Folder.fromMap).toList();
  }
}
