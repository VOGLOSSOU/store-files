import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../services/file_cleanup_service.dart';

class DatabaseHelper {
  static const _dbName = 'doc_manager.db';
  static const _dbVersion = 3;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: FileCleanupService.drain,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCleanupTable(db);
    await db.execute('''
      CREATE TABLE folders (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        description TEXT,
        parent_id   INTEGER REFERENCES folders(id) ON DELETE CASCADE,
        created_at  TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        file_path       TEXT    NOT NULL UNIQUE,
        type            TEXT    NOT NULL,
        folder_id       INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        imported_at     TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        label       TEXT    NOT NULL UNIQUE,
        color_value INTEGER NOT NULL
      )
    ''');

    // Deux tables séparées → pas de NULL dans les clés primaires
    await db.execute('''
      CREATE TABLE folder_tag_bindings (
        tag_id    INTEGER NOT NULL REFERENCES tags(id)    ON DELETE CASCADE,
        folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
        PRIMARY KEY (tag_id, folder_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE document_tag_bindings (
        tag_id      INTEGER NOT NULL REFERENCES tags(id)      ON DELETE CASCADE,
        document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
        PRIMARY KEY (tag_id, document_id)
      )
    ''');
  }

  Future<void> _createCleanupTable(Database db) => db.execute('''
    CREATE TABLE pending_file_deletions (
      file_path TEXT PRIMARY KEY NOT NULL
    )
  ''');

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migre les données existantes de tag_bindings vers les deux nouvelles tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS folder_tag_bindings (
          tag_id    INTEGER NOT NULL REFERENCES tags(id)    ON DELETE CASCADE,
          folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
          PRIMARY KEY (tag_id, folder_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS document_tag_bindings (
          tag_id      INTEGER NOT NULL REFERENCES tags(id)      ON DELETE CASCADE,
          document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
          PRIMARY KEY (tag_id, document_id)
        )
      ''');

      final legacy = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'tag_bindings'],
      );
      if (legacy.isNotEmpty) {
        // onUpgrade is transactional: any copy failure preserves the old table.
        // DISTINCT handles duplicate legacy bindings without hiding bad data.
        await db.execute('''
          INSERT INTO folder_tag_bindings (tag_id, folder_id)
          SELECT DISTINCT old.tag_id, old.folder_id FROM tag_bindings old
          WHERE old.folder_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM folder_tag_bindings current
            WHERE current.tag_id = old.tag_id
              AND current.folder_id = old.folder_id
          )
        ''');
        await db.execute('''
          INSERT INTO document_tag_bindings (tag_id, document_id)
          SELECT DISTINCT old.tag_id, old.document_id FROM tag_bindings old
          WHERE old.document_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM document_tag_bindings current
            WHERE current.tag_id = old.tag_id
              AND current.document_id = old.document_id
          )
        ''');
        await db.execute('DROP TABLE tag_bindings');
      }
    }
    if (oldVersion < 3) await _createCleanupTable(db);
  }
}
