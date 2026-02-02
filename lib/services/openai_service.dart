import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String baseUrl = 'https://<YOUR_FIREBASE_PROJECT>/us-central1/api/analyze';

  static Future<Map<String, dynamic>> analyzeAudio(String filePath) async {
    final request = http.MultipartRequest('POST', Uri.parse(baseUrl));

    request.files.add(await http.MultipartFile.fromPath('audio', filePath));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to analyze audio: $responseBody');
    }
  }
}
