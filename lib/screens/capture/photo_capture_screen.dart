import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../controllers/capture_controller.dart';
import '../../models/keypoint_model.dart';
import '../../services/local_db_service.dart';
import '../../services/firebase_service.dart';
import 'package:uuid/uuid.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  bool _isLoading = false;
  String? _poseName;
  String? _savedImagePath;
  final ImagePicker _picker = ImagePicker();


  Future<void> _processImage(File imageFile) async {
    try {
      setState(() {
        _isLoading = true;
        _poseName = null;
        _savedImagePath = null;
      });

      final result = await CaptureController.handleImageCapture(imageFile);

      setState(() {
        _poseName = result['pose'];
        _savedImagePath = result['saved_image_path'];
      });

      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Generate a unique ID for this entry
      final entryId = const Uuid().v4();

      // Upload the analyzed image to Firebase Storage
      String? imageUrl;
      if (_savedImagePath != null) {
        imageUrl = await FirebaseService.uploadImage(File(_savedImagePath!), entryId, user.uid);
      }

      // Save to local DB and Firebase
      if (result['keypoints'] != null && _savedImagePath != null) {
        final entry = KeypointEntry(
          id: entryId,
          keypointsJson: result['keypoints'] is String
              ? result['keypoints']
              : result['keypoints'].toString(),
          timestamp: DateTime.now(),
          imagePath: _savedImagePath!,
          processedImageUrl: imageUrl,
          userId: user.uid, synced: false,
        );

        // Save to local DB
        await LocalDBService.insertKeypoint(entry);

        // Upload to Firebase
        await FirebaseService.uploadKeypointEntry(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pose analyzed and uploaded: $_poseName"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Camera error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gallery error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImagePreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_savedImagePath!),
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'Error displaying image',
                  style: TextStyle(color: Colors.red),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Detected Pose:',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),
          Text(
            _poseName ?? "Unknown",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(8, 78, 74, 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    double? width,
    double? height,
    double fontSize = 16,
    double iconSize = 24,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.white.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF084E4A), size: iconSize),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF084E4A),
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF084E4A), Color(0xFF0E736D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Makes the scaffold inherit gradient
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: Column(
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.white, // Match spinner to theme
                    ),
                  )
                else
                  if (_savedImagePath != null)
                    _buildImagePreviewCard()
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 20),
                      child: Column(
                        children: [
                          Lottie.asset(
                            'assets/lottie/Animation - 1749388922811.json',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: 30),
                          Text(
                            'Analyze Your Pose!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Capture a workout pose or upload a photo to analyze it using AI.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildGlassButton(
                      icon: Icons.camera_alt,
                      label: "Take Photo",
                      width: 160,
                      onTap: _isLoading ? null : _captureFromCamera,
                    ),
                    _buildGlassButton(
                      icon: Icons.photo_library,
                      label: "Gallery",
                      width: 160,
                      onTap: _isLoading ? null : _pickFromGallery,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}