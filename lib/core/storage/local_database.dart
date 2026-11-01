import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  Future<Database>? _databaseFuture;

  Future<Database> get database => _databaseFuture ??= _open();

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'medquest.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_cases (
            user_id TEXT NOT NULL,
            case_id INTEGER NOT NULL,
            json TEXT NOT NULL,
            cached_at TEXT NOT NULL,
            PRIMARY KEY (user_id, case_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_answers (
            client_id TEXT PRIMARY KEY,
            user_id TEXT,
            case_id INTEGER NOT NULL,
            answer_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Call only after pending answers have been synchronized or the user has
  /// explicitly confirmed that unsynchronized work may be discarded.
  Future<void> clearAccountData({required String userId}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_cases', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('pending_answers', where: 'user_id = ?', whereArgs: [userId]);
    });
  }
}

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});
