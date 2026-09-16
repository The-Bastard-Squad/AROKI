import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/download_models.dart';

class DownloadTaskStore {
  static const _databaseName = 'aroki_downloads.db';
  static const _databaseVersion = 1;
  static const tableName = 'download_tasks';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$_databaseName';
    final opened = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            connectorId TEXT NOT NULL,
            familyID TEXT NOT NULL,
            titleID TEXT NOT NULL,
            episodeID TEXT NOT NULL,
            variant TEXT NOT NULL,
            quality TEXT NOT NULL,
            url TEXT NOT NULL,
            headers TEXT NOT NULL,
            kind TEXT NOT NULL,
            state TEXT NOT NULL,
            bytesTransferred INTEGER NOT NULL DEFAULT 0,
            bytesTotal INTEGER,
            contentUri TEXT,
            error TEXT,
            createdAt INTEGER NOT NULL,
            completedAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_download_tasks_episode
          ON $tableName (connectorId, episodeID, variant, state)
        ''');
      },
    );
    _database = opened;
    return opened;
  }

  Future<int> upsertTask(DownloadTask task) async {
    final db = await database;
    if (task.id != null) {
      await db.update(
        tableName,
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      return task.id!;
    }

    return db.insert(
      tableName,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isOffline({
    required String connectorId,
    required String episodeID,
    required String variant,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      columns: const ['id'],
      where:
          'connectorId = ? AND episodeID = ? AND variant = ? AND state = ? AND contentUri IS NOT NULL',
      whereArgs: [connectorId, episodeID, variant, DownloadTaskState.done.name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<DownloadTask>> tasksForEpisode({
    required String connectorId,
    required String episodeID,
    required String variant,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'connectorId = ? AND episodeID = ? AND variant = ?',
      whereArgs: [connectorId, episodeID, variant],
      orderBy: 'createdAt DESC',
    );
    return rows.map(DownloadTask.fromMap).toList();
  }
}
