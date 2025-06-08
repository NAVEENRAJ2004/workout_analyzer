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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE keypoints(
            id TEXT PRIMARY KEY,
            keypointsJson TEXT,
            timestamp TEXT,
            imagePath TEXT,
            processedImageUrl TEXT,
            userId TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE keypoints ADD COLUMN processedImageUrl TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE keypoints ADD COLUMN userId TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE keypoints ADD COLUMN synced INTEGER DEFAULT 0');
        }
      },
    );
  }

  static Future<void> insertKeypoint(KeypointEntry entry) async {
    try {
      final db = await database;
      await db.insert('keypoints', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      print('Keypoint inserted/replaced locally: ${entry.id}');
    } catch (e) {
      print('Error inserting/replacing keypoint locally: $e');
      throw Exception('Failed to insert/replace keypoint: $e');
    }
  }

  static Future<List<KeypointEntry>> getAllKeypoints() async {
    try {
      final db = await database;
      final maps = await db.query('keypoints', orderBy: 'timestamp DESC');
      print('Fetched all keypoints locally: ${maps.length} entries');
      return maps.map((map) => KeypointEntry.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching all keypoints locally: $e');
      throw Exception('Failed to get all keypoints: $e');
    }
  }

  static Future<List<KeypointEntry>> getUserKeypoints(String userId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'keypoints',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
      );
      print('Fetched user keypoints locally for $userId: ${maps.length} entries');
      return maps.map((map) => KeypointEntry.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching user keypoints locally for $userId: $e');
      throw Exception('Failed to get user keypoints: $e');
    }
  }

  static Future<void> deleteKeypoint(String id) async {
    try {
      final db = await database;
      await db.delete('keypoints', where: 'id = ?', whereArgs: [id]);
      print('Deleted keypoint locally: $id');
    } catch (e) {
      print('Error deleting keypoint locally $id: $e');
      throw Exception('Failed to delete keypoint: $e');
    }
  }

  static Future<void> deleteUserKeypoints(String userId) async {
    try {
      final db = await database;
      await db.delete('keypoints', where: 'userId = ?', whereArgs: [userId]);
      print('Deleted all keypoints for user locally: $userId');
    } catch (e) {
      print('Error deleting user keypoints locally for $userId: $e');
      throw Exception('Failed to delete user keypoints: $e');
    }
  }

  static Future<List<KeypointEntry>> getUnsyncedKeypoints() async {
    try {
      final db = await database;
      final maps = await db.query(
        'keypoints',
        where: 'synced = ? OR synced IS NULL',
        whereArgs: [0],
        orderBy: 'timestamp DESC',
      );
      print('Fetched ${maps.length} unsynced keypoints locally');
      return maps.map((map) => KeypointEntry.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching unsynced keypoints locally: $e');
      throw Exception('Failed to get unsynced keypoints: $e');
    }
  }

  static Future<void> updateKeypoint(KeypointEntry entry) async {
    try {
      final db = await database;
      await db.update(
        'keypoints',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      print('Updated keypoint locally: ${entry.id}');
    } catch (e) {
      print('Error updating keypoint locally ${entry.id}: $e');
      throw Exception('Failed to update keypoint: $e');
    }
  }
}
