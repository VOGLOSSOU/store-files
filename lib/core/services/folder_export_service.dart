import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/document.dart';
import '../models/folder.dart';

class FolderExportService {
  /// Snapshot the hierarchy, then stream the ZIP in a worker isolate.
  Future<File> exportZip(int folderId) async {
    final db = await DatabaseHelper.instance.database;
    final snapshot = await db.transaction((txn) async {
      const subtree = '''
        WITH RECURSIVE subtree(id) AS (
          SELECT id FROM folders WHERE id = ?
          UNION
          SELECT f.id FROM folders f JOIN subtree s ON f.parent_id = s.id
        )
      ''';
      final folders = await txn.rawQuery(
        '$subtree SELECT * FROM folders WHERE id IN (SELECT id FROM subtree) ORDER BY id',
        [folderId],
      );
      final documents = await txn.rawQuery(
        '$subtree SELECT * FROM documents WHERE folder_id IN (SELECT id FROM subtree) ORDER BY id',
        [folderId],
      );
      return (
        folders.map(Folder.fromMap).toList(),
        documents.map(Document.fromMap).toList(),
      );
    });
    if (snapshot.$1.isEmpty) {
      throw const FormatException('Ce dossier n’existe plus.');
    }
    final temp = await getTemporaryDirectory();
    final exports = Directory(p.join(temp.path, 'folder_exports'));
    await exports.create(recursive: true);
    // Keep recent archives available to receiving apps after the share sheet closes.
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final item in exports.list(followLinks: false)) {
      try {
        if (item is Directory && (await item.stat()).modified.isBefore(cutoff)) {
          await item.delete(recursive: true);
        }
      } on FileSystemException catch (error) {
        debugPrint('Nettoyage d’un ancien export différé : $error');
      }
    }
    final staging = await exports.createTemp('zip_');
    try {
      final path = await compute(
        _writeZip,
        (folderId, snapshot.$1, snapshot.$2, staging.path),
      );
      return File(path);
    } catch (_) {
      try {
        await staging.delete(recursive: true);
      } on FileSystemException {
        // Preserve the export error; a later export retries temporary cleanup.
      }
      rethrow;
    }
  }
}

String _safeName(String value) {
  var name = value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f\x7f]'), '_').trim();
  // Keep ordinary names intact and leave room for extensions and suffixes.
  final characters = <int>[];
  var byteLength = 0;
  for (final rune in name.runes) {
    final size = utf8.encode(String.fromCharCode(rune)).length;
    if (byteLength + size > 200) break;
    characters.add(rune);
    byteLength += size;
  }
  name = String.fromCharCodes(characters);
  name = name.replaceFirst(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'Sans nom';
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
          caseSensitive: false)
      .hasMatch(name)) {
    name = '_$name';
  }
  return name;
}

String _uniqueName(Set<String> used, String stem, [String extension = '']) {
  var name = '$stem$extension';
  var suffix = 2;
  while (!used.add(name.toLowerCase())) {
    name = '$stem (${suffix++})$extension';
  }
  return name;
}

void _checkZipPath(String path) {
  // ZIP stores filename length in an unsigned 16-bit field, even in ZIP64.
  if (utf8.encode(path).length > 65535) {
    throw const FormatException(
      'Ce dossier contient une arborescence trop profonde pour un ZIP. Exporte un sous-dossier.',
    );
  }
}

String _writeZip((int, List<Folder>, List<Document>, String) input) {
  final (rootId, folders, documents, outputDirectory) = input;
  final root = folders.firstWhere((folder) => folder.id == rootId);
  final rootName = _safeName(root.name);
  final zipPath = p.join(outputDirectory, '$rootName.zip');
  final children = <int, List<Folder>>{};
  final contents = <int, List<Document>>{};
  for (final folder in folders) {
    if (folder.id != rootId && folder.parentId != null) {
      children.putIfAbsent(folder.parentId!, () => []).add(folder);
    }
  }
  for (final document in documents) {
    contents.putIfAbsent(document.folderId, () => []).add(document);
  }
  final output = OutputFileStream(zipPath);
  try {
    final encoder = ZipEncoder()..startEncode(output);
    final queue = <(int, String)>[(rootId, rootName)];
    final visited = <int>{};
    for (var index = 0; index < queue.length; index++) {
      final (id, path) = queue[index];
      if (!visited.add(id)) {
        throw const FormatException('L’arborescence du dossier est invalide.');
      }
      _checkZipPath('$path/');
      // Unix directory type plus 0755 permissions for desktop extraction.
      encoder.add(ArchiveFile.directory('$path/')..mode = 0x41ed);
      final usedNames = <String>{};
      for (final child in children[id] ?? <Folder>[]) {
        final name = _uniqueName(usedNames, _safeName(child.name));
        queue.add((child.id!, '$path/$name'));
      }
      for (final document in contents[id] ?? <Document>[]) {
        final sourceExtension = p.extension(document.filePath);
        final extension = RegExp(r'^\.[a-zA-Z0-9]{1,10}$').hasMatch(sourceExtension)
            ? sourceExtension
            : '';
        var title = document.name;
        if (extension.isNotEmpty &&
            title.toLowerCase().endsWith(extension.toLowerCase())) {
          title = title.substring(0, title.length - extension.length);
        }
        final name = _uniqueName(usedNames, _safeName(title), extension);
        final entryPath = '$path/$name';
        _checkZipPath(entryPath);
        final InputFileStream source;
        try {
          source = InputFileStream(document.filePath);
        } on FileSystemException {
          throw FormatException(
            'Impossible de lire « ${document.name} ». Vérifie que le fichier est accessible.',
          );
        }
        try {
          final entry = ArchiveFile.stream(entryPath, source);
          // The encoder buffers compressed data per file. Store large files
          // directly to keep memory bounded, while still producing a valid ZIP.
          if (source.length > 16 * 1024 * 1024) {
            entry.compression = CompressionType.none;
          }
          entry.lastModTime = document.importedAt.millisecondsSinceEpoch ~/ 1000;
          encoder.add(entry, autoClose: false);
        } finally {
          source.closeSync();
        }
      }
    }
    encoder.endEncode();
  } finally {
    output.closeSync();
  }
  return zipPath;
}
