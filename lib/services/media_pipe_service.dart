import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MediaPipeService {
  static Future<Map<String, dynamic>> analyzePose(File imageFile) async {
    final uri = Uri.parse("http://<your-local-ip>:5000/pose");
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode == 200) {
      final bytes = await streamedResponse.stream.toBytes();

      // Decode keypoints and pose from headers
      final keypointsHeader = streamedResponse.headers['keypoints'];
      final poseHeader = streamedResponse.headers['pose'];

      final keypoints = jsonDecode(keypointsHeader ?? "[]");

      return {
        "imageBytes": bytes,
        "keypoints": keypoints,
        "pose": poseHeader ?? "Unknown"
      };
    } else {
      throw Exception("Pose analysis failed");
    }
  }
}
