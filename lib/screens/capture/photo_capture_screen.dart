import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/capture_controller.dart';
import '../../models/keypoint_model.dart';
import '../../services/local_db_service.dart';
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

      // Save to local DB
      if (result['keypoints'] != null && _savedImagePath != null) {
        final entry = KeypointEntry(
          id: const Uuid().v4(),
          keypointsJson: result['keypoints'] is String ? result['keypoints'] : result['keypoints'].toString(),
          timestamp: DateTime.now(),
          imagePath: _savedImagePath!,
        );
        await LocalDBService.insertKeypoint(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pose analyzed: $_poseName"),
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

  Widget _buildImagePreview() {
    if (_savedImagePath == null) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _isValidImageFile(_savedImagePath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError || !snapshot.data!) {
          return const Text(
            'Error loading image',
            style: TextStyle(color: Colors.red),
          );
        }

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_savedImagePath!),
                height: 300,
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
              'Detected Pose: $_poseName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isValidImageFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      if (bytes.length < 2) return false;

      // Check for JPEG magic numbers
      return bytes[0] == 0xFF && bytes[1] == 0xD8;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pose Analysis'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_savedImagePath != null)
                _buildImagePreview()
              else
                const Text(
                  'Take a photo or select from gallery to analyze your pose',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _captureFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}