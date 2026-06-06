import 'dart:collection';
import 'package:audioplayers/audioplayers.dart';
import 'api_service.dart';

/// Service Text-to-Speech sử dụng Backend (OpenAI TTS)
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  
  final AudioPlayer _player = AudioPlayer();
  final Queue<String> _queue = Queue<String>();
  
  bool _isSpeaking = false;
  bool _isProcessing = false;
  bool get isSpeaking => _isSpeaking || _queue.isNotEmpty || _isProcessing;

  TtsService._internal() {
    // Lắng nghe sự kiện phát xong 1 file MP3
    _player.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      _playNext();
    });
  }

  Future<void> init() async {
    // Với audioplayers không cần cấu hình phức tạp ban đầu
  }

  /// Đọc to [text] bằng cách đẩy vào hàng đợi
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _queue.add(text);
    if (!_isSpeaking && !_isProcessing) {
      _playNext();
    }
  }

  /// Phát file MP3 tiếp theo trong hàng đợi
  Future<void> _playNext() async {
    if (_queue.isEmpty) return;
    
    _isProcessing = true;
    final text = _queue.removeFirst();
    
    try {
      // 1. Gửi request tạo file MP3 lên backend
      final audioUrl = await ApiService.generateAudio(text);
      
      // 2. Phát file URL được trả về
      _isSpeaking = true;
      _isProcessing = false;
      await _player.play(UrlSource(audioUrl));
      
    } catch (e) {
      // Nếu lỗi tạo âm thanh, bỏ qua và chạy câu tiếp theo
      _isSpeaking = false;
      _isProcessing = false;
      _playNext();
    }
  }

  /// Dừng đọc và dọn hàng đợi
  Future<void> stop() async {
    _queue.clear();
    await _player.stop();
    _isSpeaking = false;
    _isProcessing = false;
  }

  /// Giải phóng bộ nhớ
  Future<void> dispose() async {
    await _player.dispose();
  }
}
