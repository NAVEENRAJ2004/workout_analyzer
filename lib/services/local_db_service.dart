import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/keypoint_model.dart';

class LocalDBService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'keypoints.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE keypoints(
            id TEXT PRIMARY KEY,
            keypointsJson TEXT,
            timestamp TEXT,
            imagePath TEXT
          )
        ''');
      },
    );
  }

  static Future<void> insertKeypoint(KeypointEntry entry) async {
    final db = await database;
    await db.insert('keypoints', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<KeypointEntry>> getAllKeypoints() async {
    final db = await database;
    final maps = await db.query('keypoints', orderBy: 'timestamp DESC');
    return maps.map((map) => KeypointEntry.fromMap(map)).toList();
  }

  static Future<void> deleteKeypoint(String id) async {
    final db = await database;
    await db.delete('keypoints', where: 'id = ?', whereArgs: [id]);
  }
}
