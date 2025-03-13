import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../models/track.dart';
import '../models/folder.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('music_library.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, filePath);
    debugPrint('Database path: $path');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        debugPrint('Creating database...');
        await db.execute('''
          CREATE TABLE folders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            duration INTEGER NOT NULL,
            filePath TEXT,
            folderId INTEGER,
            FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE SET NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          debugPrint('Upgrading to version 2...');
          await db.execute('ALTER TABLE tracks ADD COLUMN filePath TEXT');
        }
        if (oldVersion < 3) {
          debugPrint('Upgrading to version 3...');
          await db.execute('''
            CREATE TABLE temp_tracks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              artist TEXT NOT NULL,
              duration INTEGER NOT NULL,
              filePath TEXT,
              folderId INTEGER,
              FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE SET NULL
            )
          ''');
          await db.execute('''
            INSERT INTO temp_tracks (id, title, artist, duration, filePath)
            SELECT id, title, artist, duration, filePath FROM tracks
          ''');
          await db.execute('DROP TABLE tracks');
          await db.execute('ALTER TABLE temp_tracks RENAME TO tracks');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS folders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // Методы для папок
  Future<void> insertFolder(Folder folder) async {
    final db = await database;
    try {
      final id = await db.insert('folders', folder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Inserted folder with id: $id');
    } catch (e) {
      debugPrint('Error inserting folder: $e');
    }
  }

  Future<List<Folder>> getFolders() async {
    final db = await database;
    final result = await db.query('folders');
    debugPrint('Fetched ${result.length} folders');
    return result.map((map) => Folder.fromMap(map)).toList();
  }

  // Методы для треков
  Future<void> insertTrack(Track track) async {
    final db = await database;
    try {
      final id = await db.insert('tracks', track.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Inserted track with id: $id');
    } catch (e) {
      debugPrint('Error inserting track: $e');
    }
  }

  Future<void> updateTrack(Track track) async {
    final db = await database;
    try {
      final rowsAffected = await db.update(
        'tracks',
        track.toMap(),
        where: 'id = ?',
        whereArgs: [track.id],
      );
      debugPrint('Updated $rowsAffected track(s) with id: ${track.id}');
    } catch (e) {
      debugPrint('Error updating track: $e');
    }
  }

  Future<List<Track>> getTracks({int? folderId}) async {
    final db = await database;
    final result = folderId == null
        ? await db.query('tracks')
        : await db.query('tracks', where: 'folderId = ?', whereArgs: [folderId]);
    debugPrint('Fetched ${result.length} tracks');
    return result.map((map) => Track.fromMap(map)).toList();
  }
}