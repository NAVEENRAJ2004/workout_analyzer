import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class CaptureController extends GetxController {
  // Use your actual local IP where the FastAPI server is running
  static const String baseUrl = 'http://192.168.1.11:8000';

  static Future<Map<String, dynamic>> handleImageCapture(File imageFile) async {
    try {
      // Validate JPEG image
      if (!await _isValidImage(imageFile)) {
        throw Exception('Invalid image format. Please upload a valid JPEG file.');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze-pose'),
      );

      // 'file' must match the FastAPI param name
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['annotated_image'] != null) {
          final String base64Image = jsonResponse['annotated_image'];
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/pose_${DateTime.now().millisecondsSinceEpoch}.jpg';

          final decodedImage = base64Decode(base64Image);
          final file = File(filePath);
          await file.writeAsBytes(decodedImage);

          if (!await _isValidImage(file)) {
            throw Exception('Invalid image returned from server');
          }

          jsonResponse['saved_image_path'] = filePath;
        }

        return jsonResponse;
      } else {
        String errorMessage;
        try {
          final errorJson = json.decode(response.body);
          errorMessage = errorJson['detail'] ?? 'Unknown error';
        } catch (_) {
          errorMessage = 'Server error: ${response.statusCode}';
        }

        throw Exception('Failed: $errorMessage');
      }
    } on SocketException {
      throw Exception('Cannot connect to server. Check internet/Wi-Fi connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  static Future<bool> _isValidImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    } catch (_) {
      return false;
    }
  }
}