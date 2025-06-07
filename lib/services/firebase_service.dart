import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/keypoint_model.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<String> uploadImage(File imageFile, String entryId) async {
    final ref = _storage.ref().child('keypoint_images/$entryId.jpg');
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  static Future<void> uploadKeypointEntry(KeypointEntry entry) async {
    await _firestore.collection('keypoints').doc(entry.id).set(entry.toMap());
  }

  static Future<List<KeypointEntry>> fetchAllKeypoints() async {
    final snapshot = await _firestore.collection('keypoints').orderBy('timestamp', descending: true).get();
    return snapshot.docs.map((doc) => KeypointEntry.fromMap(doc.data())).toList();
  }
}
