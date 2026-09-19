import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/tag.dart';

class TagService {
  final _db = DatabaseHelper.instance;

  // Famille tonale bleu → ardoise, dans l'esprit du logo (#1565C0) : les tags
  // restent distinguables sans sortir de l'identité de l'app.
  static const _defaultColors = [
    Color(0xFF64B5F6), // Bleu clair
    Color(0xFF1E88E5), // Bleu
    Color(0xFF1565C0), // Bleu ARCA
    Color(0xFF0D47A1), // Bleu profond
    Color(0xFF01579B), // Bleu pétrole
    Color(0xFF37474F), // Ardoise foncé
    Color(0xFF546E7A), // Ardoise
    Color(0xFF78909C), // Ardoise clair
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
