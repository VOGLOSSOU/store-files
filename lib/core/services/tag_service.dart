import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/tag.dart';

class TagService {
  final _db = DatabaseHelper.instance;

  static const _defaultColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  Future<List<Tag>> getAllTags() async {
    final db = await _db.database;
    final rows = await db.query('tags', orderBy: 'label ASC');
    return rows.map(Tag.fromMap).toList();
  }

  /// Crée un tag ou retourne l'existant si le label est déjà pris.
  Future<Tag> createTag(String label) async {
    final db = await _db.database;

    final existing = await db.query(
      'tags',
      where: 'label = ?',
      whereArgs: [label],
      limit: 1,
    );
    if (existing.isNotEmpty) return Tag.fromMap(existing.first);

    final all = await getAllTags();
    final colorIndex = all.length % _defaultColors.length;
    final tag = Tag(
      label: label,
      colorValue: _defaultColors[colorIndex].toARGB32(),
    );
    final id = await db.insert('tags', tag.toMap()..remove('id'));
    return Tag(id: id, label: tag.label, colorValue: tag.colorValue);
  }

  Future<void> deleteTag(int tagId) async {
    final db = await _db.database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  Future<List<Tag>> getTagsForFolder(int folderId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT t.* FROM tags t
      JOIN folder_tag_bindings b ON b.tag_id = t.id
      WHERE b.folder_id = ?
      ORDER BY t.label ASC
    ''', [folderId]);
    return rows.map(Tag.fromMap).toList();
  }

  Future<List<Tag>> getTagsForDocument(int documentId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT t.* FROM tags t
      JOIN document_tag_bindings b ON b.tag_id = t.id
      WHERE b.document_id = ?
      ORDER BY t.label ASC
    ''', [documentId]);
    return rows.map(Tag.fromMap).toList();
  }

  Future<void> bindToFolder(int tagId, int folderId) async {
    final db = await _db.database;
    await db.insert(
      'folder_tag_bindings',
      {'tag_id': tagId, 'folder_id': folderId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unbindFromFolder(int tagId, int folderId) async {
    final db = await _db.database;
    await db.delete(
      'folder_tag_bindings',
      where: 'tag_id = ? AND folder_id = ?',
      whereArgs: [tagId, folderId],
    );
  }

  Future<void> bindToDocument(int tagId, int documentId) async {
    final db = await _db.database;
    await db.insert(
      'document_tag_bindings',
      {'tag_id': tagId, 'document_id': documentId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unbindFromDocument(int tagId, int documentId) async {
    final db = await _db.database;
    await db.delete(
      'document_tag_bindings',
      where: 'tag_id = ? AND document_id = ?',
      whereArgs: [tagId, documentId],
    );
  }
}
