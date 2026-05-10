import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _dbName = 'doc_manager.db';
  static const _dbVersion = 1;

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
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        description TEXT,
        parent_id  INTEGER REFERENCES folders(id) ON DELETE CASCADE,
        created_at TEXT    NOT NULL
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

    await db.execute('''
      CREATE TABLE tag_bindings (
        tag_id      INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        folder_id   INTEGER REFERENCES folders(id)   ON DELETE CASCADE,
        document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
        PRIMARY KEY (tag_id, folder_id, document_id)
      )
    ''');
  }
}
