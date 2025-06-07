import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class CaptureController extends GetxController {
  static const String baseUrl = 'http://10.0.2.2:8000'; // For Android emulator
  // static const String baseUrl = 'http://localhost:8000'; // For iOS simulator
  // static const String baseUrl = 'http://your-server-ip:8000'; // For physical device

  static Future<Map<String, dynamic>> handleImageCapture(File imageFile) async {
    try {
      // Validate image before sending
      if (!await _isValidImage(imageFile)) {
        throw Exception('Invalid image format. Please ensure the image is a valid JPEG file.');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze-pose'),
      );

      // Add the image file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      // Send the request with timeout
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out. Please try again.');
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Parse the response
        var jsonResponse = json.decode(response.body);

        // Save the analyzed image
        if (jsonResponse['annotated_image'] != null) {
          final String base64Image = jsonResponse['annotated_image'];

          // Get the temporary directory
          final directory = await getTemporaryDirectory();
          final String fileName = 'pose_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String filePath = '${directory.path}/$fileName';

          // Decode and save the image
          final imageBytes = base64Decode(base64Image);
          final file = File(filePath);
          await file.writeAsBytes(imageBytes);

          // Verify the image is valid
          if (!await _isValidImage(file)) {
            throw Exception('Invalid image received from server');
          }

          // Update the response with the saved file path
          jsonResponse['saved_image_path'] = filePath;
        }

        return jsonResponse;
      } else {
        // Handle different error status codes
        String errorMessage;
        try {
          var errorJson = json.decode(response.body);
          errorMessage = errorJson['detail'] ?? 'Unknown error occurred';
        } catch (e) {
          errorMessage = 'Server error: ${response.statusCode}';
        }

        switch (response.statusCode) {
          case 400:
            throw Exception('Invalid request: $errorMessage');
          case 413:
            throw Exception('Image file too large. Please choose a smaller image.');
          case 500:
            throw Exception('Server error: $errorMessage');
          default:
            throw Exception('Error analyzing pose: $errorMessage');
        }
      }
    } on SocketException {
      throw Exception('Network error. Please check your internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      throw Exception('Error analyzing pose: $e');
    }
  }

  static Future<bool> _isValidImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 2) return false;

      // Check for JPEG magic numbers
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}