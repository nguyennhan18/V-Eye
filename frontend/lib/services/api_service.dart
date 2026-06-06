import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// Kết quả phân tích ảnh từ AI (đầy đủ)
class ArtAnalysisResult {
  final String scene;
  final List<String> objects;
  final List<String> colors;
  final String positions;
  final List<String> warnings;
  final double confidence;
  final String tang1;
  final String tang2;
  final String provider;

  const ArtAnalysisResult({
    this.scene = '',
    this.objects = const [],
    this.colors = const [],
    this.positions = '',
    this.warnings = const [],
    this.confidence = 0.0,
    this.tang1 = '',
    this.tang2 = '',
    this.provider = 'gemini',
  });

  factory ArtAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ArtAnalysisResult(
      scene: json['scene'] as String? ?? '',
      objects: (json['objects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      colors: (json['colors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      positions: json['positions'] as String? ?? '',
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      tang1: json['tang_1'] as String? ?? '',
      tang2: json['tang_2'] as String? ?? '',
      provider: json['provider'] as String? ?? 'gemini',
    );
  }

  String get fullDescription {
    List<String> parts = [];
    if (tang1.isNotEmpty) parts.add(tang1);
    if (tang2.isNotEmpty) parts.add(tang2);
    if (warnings.isNotEmpty) parts.add('Cảnh báo nguy hiểm: ${warnings.join(", ")}');
    return parts.join('. ');
  }
}

class ApiService {
  // Thay đổi IP dựa trên thiết bị:
  // Android Emulator: 10.0.2.2
  // iOS Simulator: 127.0.0.1
  // Real Device: IP máy tính trong mạng LAN
  static const String _baseUrl = 'http://127.0.0.1:8001';

  /// Endpoint cũ: chờ toàn bộ phân tích xong
  static Future<ArtAnalysisResult> analyzeImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/describe-image');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 40),
        onTimeout: () => throw ApiException('Kết nối quá thời gian. Vui lòng thử lại.'),
      );

      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
        return ArtAnalysisResult.fromJson(json);
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        throw ApiException(body['detail']?.toString() ?? 'Lỗi không xác định.');
      }
    } on SocketException {
      throw ApiException('Không thể kết nối đến server. Kiểm tra lại địa chỉ IP.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi: $e');
    }
  }

  /// Endpoint mới: Stream nội dung Server-Sent Events (SSE)
  static Stream<String> streamDescription(File imageFile) async* {
    final uri = Uri.parse('$_baseUrl/api/stream-description');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        // Cố gắng đọc body lỗi
        String errorBody = await response.stream.transform(utf8.decoder).join();
        try {
          final jsonError = jsonDecode(errorBody);
          throw ApiException(jsonError['detail'] ?? 'Lỗi server');
        } catch (_) {
          throw ApiException('Lỗi HTTP ${response.statusCode}');
        }
      }

      String currentEvent = '';
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
            
        if (line.isEmpty) continue;

        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          
          if (currentEvent == 'chunk') {
            yield data;
          } else if (currentEvent == 'error') {
            throw ApiException(data);
          } else if (currentEvent == 'complete') {
            break;
          }
        }
      }
    } on SocketException {
      throw ApiException('Không thể kết nối đến server.');
    } finally {
      client.close();
    }
  }

  /// Endpoint mới: Gọi backend tạo file MP3 từ văn bản
  static Future<String> generateAudio(String text) async {
    final uri = Uri.parse('$_baseUrl/api/generate-audio');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const ApiException('Kết nối TTS quá thời gian.'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final audioUrl = json['audio_url'];
        return '$_baseUrl$audioUrl';
      } else {
        throw ApiException('Lỗi tạo audio: HTTP ${response.statusCode}');
      }
    } on SocketException {
      throw const ApiException('Không thể kết nối đến server Audio.');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
