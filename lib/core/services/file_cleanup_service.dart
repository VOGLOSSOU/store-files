import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'thumbnail_service.dart';

/// The queue is committed with the deletion, before touching any files.
class FileCleanupService {
  static Future<void> enqueue(DatabaseExecutor txn, String path) async {
    await txn.insert('pending_file_deletions', {
      'file_path': path,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Failed cleanup remains queued and is retried when the database opens.
  static Future<void> drain(Database db) async {
    try {
      final rows = await db.query('pending_file_deletions');
      for (final row in rows) {
        final path = row['file_path'] as String;
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
          // Let any in-flight writer finish before removing its output.
          await ThumbnailService.waitForPending(path);
          final thumbnail = File(ThumbnailService.thumbPathFor(path));
          if (await thumbnail.exists()) await thumbnail.delete();
          await db.delete(
            'pending_file_deletions',
            where: 'file_path = ?',
            whereArgs: [path],
          );
        } catch (error) {
          debugPrint('Nettoyage de fichier différé : $error');
        }
      }
    } catch (error) {
      debugPrint('Impossible de reprendre le nettoyage : $error');
    }
  }
}
