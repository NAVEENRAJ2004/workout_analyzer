import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MediaPipeService {
  static Future<Map<String, dynamic>> analyzePose(File imageFile) async {
    // Use the correct endpoint: /analyze-pose
    final uri = Uri.parse("http://192.168.1.11:8000/analyze-pose");

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path)); // key must match 'file'

    print("Sending image to $uri");

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("Status Code: ${response.statusCode}");

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      final annotatedImageBase64 = responseData['annotated_image'];
      final keypoints = responseData['keypoints'];
      final pose = responseData['pose'];

      // Decode base64 image to bytes if needed
      final imageBytes = base64Decode(annotatedImageBase64);

      return {
        "imageBytes": imageBytes,
        "keypoints": keypoints,
        "pose": pose,
      };
    } else {
      print("Error: ${response.body}");
      throw Exception("Pose analysis failed: ${response.statusCode}");
    }
  }
}
