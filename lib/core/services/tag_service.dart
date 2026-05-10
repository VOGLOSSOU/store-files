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

  Future<Tag> createTag(String label) async {
    final db = await _db.database;
    final colorIndex = (await getAllTags()).length % _defaultColors.length;
    final tag = Tag(
      label: label,
      colorValue: _defaultColors[colorIndex].toARGB32(),
    );
    final map = tag.toMap()..remove('id');
    final id = await db.insert('tags', map);
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
      JOIN tag_bindings tb ON tb.tag_id = t.id
      WHERE tb.folder_id = ?
    ''', [folderId]);
    return rows.map(Tag.fromMap).toList();
  }

  Future<List<Tag>> getTagsForDocument(int documentId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT t.* FROM tags t
      JOIN tag_bindings tb ON tb.tag_id = t.id
      WHERE tb.document_id = ?
    ''', [documentId]);
    return rows.map(Tag.fromMap).toList();
  }

  Future<void> bindToFolder(int tagId, int folderId) async {
    final db = await _db.database;
    await db.insert(
      'tag_bindings',
      {'tag_id': tagId, 'folder_id': folderId, 'document_id': null},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unbindFromFolder(int tagId, int folderId) async {
    final db = await _db.database;
    await db.delete(
      'tag_bindings',
      where: 'tag_id = ? AND folder_id = ?',
      whereArgs: [tagId, folderId],
    );
  }

  Future<void> bindToDocument(int tagId, int documentId) async {
    final db = await _db.database;
    await db.insert(
      'tag_bindings',
      {'tag_id': tagId, 'folder_id': null, 'document_id': documentId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unbindFromDocument(int tagId, int documentId) async {
    final db = await _db.database;
    await db.delete(
      'tag_bindings',
      where: 'tag_id = ? AND document_id = ?',
      whereArgs: [tagId, documentId],
    );
  }
}
