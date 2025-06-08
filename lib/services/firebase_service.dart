import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/keypoint_model.dart';
import '../services/local_db_service.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<String> uploadImage(File imageFile, String entryId, String userId) async {
    try {
      if (_auth.currentUser?.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      final ref = _storage.ref().child('users/$userId/keypoint_images/$entryId.jpg');
      
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: ${imageFile.path}');
      }

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'timestamp': DateTime.now().toIso8601String(),
            'userId': userId,
            'entryId': entryId,
          },
        ),
      );
      
      return await uploadTask.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print('Firebase Storage error: ${e.message}');
      throw Exception('Firebase Storage error: ${e.message}');
    } catch (e) {
      print('Failed to upload image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  static Future<void> uploadKeypointEntry(KeypointEntry entry) async {
    try {
      if (_auth.currentUser?.uid != entry.userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      if (entry.keypointsJson.isEmpty) {
        throw Exception('Keypoints JSON is empty');
      }

      print('Uploading keypoint entry to Firestore: ${entry.id}');
      
      final docRef = _firestore
          .collection('users')
          .doc(entry.userId)
          .collection('keypoints')
          .doc(entry.id);
      
      await docRef.set(entry.toMap());
      print('Successfully uploaded keypoint entry to Firestore: ${entry.id}');
    } on FirebaseException catch (e) {
      print('Firestore error: ${e.message}');
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      print('Failed to upload keypoint entry: $e');
      throw Exception('Failed to upload keypoint entry: $e');
    }
  }

  static Future<List<KeypointEntry>> fetchUserKeypoints(String userId) async {
    try {
      if (_auth.currentUser?.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      print('Fetching keypoints for user: $userId');
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('keypoints')
          .orderBy('timestamp', descending: true)
          .get();

      final entries = snapshot.docs.map((doc) => KeypointEntry.fromMap(doc.data())).toList();
      print('Fetched ${entries.length} keypoint entries');
      return entries;
    } on FirebaseException catch (e) {
      print('Failed to fetch keypoints: ${e.message}');
      throw Exception('Failed to fetch keypoints: ${e.message}');
    } catch (e) {
      print('Failed to fetch keypoints: $e');
      throw Exception('Failed to fetch keypoints: $e');
    }
  }

  static Future<void> syncUserData(String userId) async {
    try {
      if (_auth.currentUser?.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      print('Starting data sync for user: $userId');
      
      // Fetch cloud data
      final cloudEntries = await fetchUserKeypoints(userId);
      
      // Fetch local data
      final localEntries = await LocalDBService.getUserKeypoints(userId);
      
      // Create maps for easy lookup
      final cloudMap = {for (var e in cloudEntries) e.id: e};
      final localMap = {for (var e in localEntries) e.id: e};
      
      // Upload local entries that don't exist in cloud
      for (final localEntry in localEntries) {
        if (!cloudMap.containsKey(localEntry.id)) {
          print('Uploading missing entry to cloud: ${localEntry.id}');
          await uploadKeypointEntry(localEntry);
        }
      }
      
      // Download cloud entries that don't exist locally
      for (final cloudEntry in cloudEntries) {
        if (!localMap.containsKey(cloudEntry.id)) {
          print('Downloading missing entry to local: ${cloudEntry.id}');
          await LocalDBService.insertKeypoint(cloudEntry);
        }
      }
      
      print('Data sync completed for user: $userId');
    } catch (e) {
      print('Failed to sync user data: $e');
      throw Exception('Failed to sync user data: $e');
    }
  }

  static Future<void> deleteKeypointEntry(String entryId, String userId) async {
    try {
      if (_auth.currentUser?.uid != userId) {
        throw Exception('Unauthorized: User ID mismatch');
      }

      print('Deleting entry: $entryId');
      
      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('keypoints')
          .doc(entryId)
          .delete();
      
      // Delete image from Storage
      await _storage.ref().child('users/$userId/keypoint_images/$entryId.jpg').delete();
      
      print('Successfully deleted entry: $entryId');
    } on FirebaseException catch (e) {
      print('Failed to delete entry: ${e.message}');
      throw Exception('Failed to delete entry: ${e.message}');
    } catch (e) {
      print('Failed to delete entry: $e');
      throw Exception('Failed to delete entry: $e');
    }
  }
}
