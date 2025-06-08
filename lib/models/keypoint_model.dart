import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../services/local_db_service.dart';
import '../services/firebase_service.dart';

class KeypointEntry {
  final String id;
  final String keypointsJson;
  final DateTime timestamp;
  final String imagePath; // Can be local path or URL
  final String? processedImageUrl; // URL of the processed image with pose overlay
  final String userId; // ID of the user who created this entry
  final bool synced;

  KeypointEntry({
    required this.id,
    required this.keypointsJson,
    required this.timestamp,
    required this.imagePath,
    required this.userId,
    this.processedImageUrl,
    required this.synced,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'keypointsJson': keypointsJson,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'processedImageUrl': processedImageUrl,
      'userId': userId,
      'synced': synced ? 1 : 0,
    };
  }

  factory KeypointEntry.fromMap(Map<String, dynamic> map) {
    return KeypointEntry(
      id: map['id'] as String,
      keypointsJson: map['keypointsJson'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      imagePath: map['imagePath'] as String,
      processedImageUrl: map['processedImageUrl'] as String?,
      userId: map['userId'] as String,
      synced: (map['synced'] ?? 0) == 1,
    );
  }

  String toJson() => json.encode(toMap());

  factory KeypointEntry.fromJson(String source) => KeypointEntry.fromMap(json.decode(source));

  KeypointEntry copyWith({
    String? id,
    String? keypointsJson,
    DateTime? timestamp,
    String? imagePath,
    String? processedImageUrl,
    String? userId,
    bool? synced,
  }) {
    return KeypointEntry(
      id: id ?? this.id,
      keypointsJson: keypointsJson ?? this.keypointsJson,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      processedImageUrl: processedImageUrl ?? this.processedImageUrl,
      userId: userId ?? this.userId,
      synced: synced ?? this.synced,
    );
  }
}

Future<void> syncUnsyncedEntries() async {
  print('Starting sync of unsynced entries');
  final unsyncedEntries = await LocalDBService.getUnsyncedKeypoints();
  print('Found ${unsyncedEntries.length} unsynced entries');
  
  for (final entry in unsyncedEntries) {
    try {
      print('Processing entry: ${entry.id}');
      // Upload image to Firebase Storage
      final imageFile = File(entry.imagePath);
      if (!await imageFile.exists()) {
        print('Image file not found: ${entry.imagePath}');
        continue;
      }

      print('Uploading image to Firebase Storage');
      final imageUrl = await FirebaseService.uploadImage(imageFile, entry.id, entry.userId);
      print('Image uploaded successfully: $imageUrl');
      
      // Create updated entry with image URL and synced status
      final updatedEntry = entry.copyWith(
        processedImageUrl: imageUrl,
        synced: true,
      );

      print('Uploading keypoints to Firestore');
      // Upload keypoints to Firestore
      await FirebaseService.uploadKeypointEntry(updatedEntry);
      print('Keypoints uploaded successfully');
      
      // Update local DB only after successful cloud sync
      await LocalDBService.updateKeypoint(updatedEntry);
      print('Local DB updated successfully');
      
      print('Successfully synced entry: ${entry.id}');
    } catch (e) {
      print('Failed to sync entry ${entry.id}: $e');
      // Keep the entry as unsynced for retry
    }
  }
  print('Finished syncing unsynced entries');
}

// Add a function to handle individual entry sync with retry
Future<bool> syncEntryWithRetry(KeypointEntry entry, {int maxRetries = 3}) async {
  int retryCount = 0;
  while (retryCount < maxRetries) {
    try {
      final imageFile = File(entry.imagePath);
      if (!await imageFile.exists()) {
        print('Image file not found: ${entry.imagePath}');
        return false;
      }

      final imageUrl = await FirebaseService.uploadImage(imageFile, entry.id, entry.userId);
      
      final updatedEntry = entry.copyWith(
        processedImageUrl: imageUrl,
        synced: true,
      );

      await FirebaseService.uploadKeypointEntry(updatedEntry);
      await LocalDBService.updateKeypoint(updatedEntry);
      
      print('Successfully synced entry: ${entry.id}');
      return true;
    } catch (e) {
      retryCount++;
      print('Retry $retryCount failed for entry ${entry.id}: $e');
      if (retryCount == maxRetries) {
        print('Max retries reached for entry ${entry.id}');
        return false;
      }
      // Wait before retrying (exponential backoff)
      await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
    }
  }
  return false;
}
