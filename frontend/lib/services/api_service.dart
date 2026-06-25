import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static Future<Map<String, dynamic>> describeImage(XFile image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/describe-image'),
    );

    final bytes = await image.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name.isEmpty ? 'upload.jpg' : image.name,
        contentType: MediaType.parse(image.mimeType ?? 'image/jpeg'),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final json = jsonDecode(response.body);
    return {
      'description': json['description'] ?? 'Không có mô tả.',
      'audioUrl': json['audio_url'] != null ? '$baseUrl${json['audio_url']}' : null,
    };
  }
}