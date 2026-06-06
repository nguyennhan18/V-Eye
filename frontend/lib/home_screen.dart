import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'services/api_service.dart';
import 'services/tts_service.dart';

// ─────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _statusText = 'Chạm đúp để phân tích';
  
  // Lưu trữ text cho streaming
  String _streamedText = '';
  String _errorText = '';

  // ── Camera ─────────────────────────────────
  CameraController? _cameraController;
  bool _cameraReady = false;

  // ── Services ───────────────────────────────
  final TtsService _tts = TtsService();

  // ── Animation ──────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
    _tts.init();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorText = 'Không tìm thấy camera.');
        return;
      }
      // Ưu tiên camera sau (rear)
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Lỗi camera: $e');
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _cameraController?.dispose();
    _tts.dispose();
    super.dispose();
  }

  // ── Main action: chạm đúp ─────────────────
  Future<void> _onDoubleTap() async {
    if (_isCapturing || _isProcessing || _isSpeaking) {
      if (_isSpeaking || _isProcessing) {
        await _tts.stop();
        setState(() {
          _isSpeaking = false;
          _isProcessing = false;
          _statusText = 'Chạm đúp để phân tích';
        });
      }
      return;
    }

    setState(() {
      _isCapturing = true;
      _streamedText = '';
      _errorText = '';
      _statusText = 'Đang chụp ảnh...';
    });

    File? imageFile;
    try {
      if (!_cameraReady || _cameraController == null) {
        throw Exception('Camera chưa sẵn sàng.');
      }
      final xFile = await _cameraController!.takePicture();
      imageFile = File(xFile.path);
    } catch (e) {
      _handleError('Không thể chụp ảnh: $e');
      return;
    }

    setState(() {
      _isCapturing = false;
      _isProcessing = true;
      _statusText = 'AI đang phân tích và đọc...';
      _isSpeaking = true;
    });

    try {
      String bufferText = '';
      
      // Lắng nghe stream
      await for (final chunk in ApiService.streamDescription(imageFile)) {
        if (!mounted || !_isProcessing) break; // Bị hủy
        
        setState(() {
          _streamedText += chunk;
        });

        // Xử lý đọc theo từng câu:
        // Đơn giản hóa: Cứ mỗi khi có dấu chấm, chấm hỏi, chấm than, hoặc \n thì đọc đoạn đó
        bufferText += chunk;
        if (bufferText.contains('.') || bufferText.contains('\n') || bufferText.contains('?') || bufferText.contains('!')) {
          // Lọc bỏ các ngoặc nhọn, ngoặc kép, json keys
          String cleanTextToSpeak = bufferText
            .replaceAll(RegExp(r'["{}[\]]'), '')
            .replaceAll(RegExp(r'(scene|objects|colors|positions|warnings|confidence|tang_1|tang_2|provider):'), '')
            .trim();
            
          if (cleanTextToSpeak.isNotEmpty && cleanTextToSpeak.length > 5) {
            _tts.speak(cleanTextToSpeak);
          }
          bufferText = ''; // clear buffer
        }
      }
      
      // Đọc nốt phần còn lại
      if (bufferText.trim().isNotEmpty) {
        String cleanTextToSpeak = bufferText
            .replaceAll(RegExp(r'["{}[\]]'), '')
            .replaceAll(RegExp(r'(scene|objects|colors|positions|warnings|confidence|tang_1|tang_2|provider):'), '')
            .trim();
        if (cleanTextToSpeak.isNotEmpty) {
          _tts.speak(cleanTextToSpeak);
        }
      }

    } on ApiException catch (e) {
      _handleError(e.message);
      return;
    } catch (e) {
      _handleError('Lỗi không xác định: $e');
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isSpeaking = false; // Note: TTS may still be speaking in background, but we reset UI state
        _statusText = 'Chạm đúp để phân tích lại';
      });
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _isCapturing = false;
      _isProcessing = false;
      _isSpeaking = false;
      _errorText = message;
      _statusText = 'Chạm đúp để thử lại';
    });
    _tts.speak('Đã có lỗi xảy ra. $message');
  }

  // ── Màu nút chính theo trạng thái ────────
  List<Color> get _buttonColors {
    if (_isCapturing) return [const Color(0xFF00C896), const Color(0xFF00A878)];
    if (_isProcessing) return [const Color(0xFFFF9500), const Color(0xFFFFCC00)];
    if (_isSpeaking) return [const Color(0xFF6C63FF), const Color(0xFF3B82F6)];
    return [const Color(0xFF6C63FF), const Color(0xFF3B82F6)];
  }

  Color get _accentColor {
    if (_isCapturing) return const Color(0xFF00C896);
    if (_isProcessing) return const Color(0xFFFF9500);
    if (_isSpeaking) return const Color(0xFF6C63FF);
    return const Color(0xFF6C63FF);
  }

  IconData get _buttonIcon {
    if (_isCapturing) return Icons.camera_alt;
    if (_isProcessing) return Icons.auto_awesome;
    if (_isSpeaking) return Icons.volume_up;
    return _streamedText.isNotEmpty ? Icons.replay : Icons.camera_alt_outlined;
  }

  // ── BUILD ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: GestureDetector(
        onDoubleTap: _onDoubleTap,
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
                ),
              ),
            ),

            // Top bar
            _buildTopBar(),

            // Main center button
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMainButton(),
                  const SizedBox(height: 30),
                  _buildStatusText(),
                ],
              ),
            ),

            // Kết quả AI
            if (_streamedText.isNotEmpty) _buildResultCard(),

            // Thông báo lỗi
            if (_errorText.isNotEmpty) _buildErrorCard(),

            // Bottom hint
            _buildBottomHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'V-Eye',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Trợ lý thị giác thông minh',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _cameraReady
                          ? const Color(0xFF00FF88)
                          : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _cameraReady ? 'Sẵn sàng' : 'Đang khởi động',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    final bool isActive = _isCapturing || _isProcessing || _isSpeaking;

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          if (isActive)
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(260, 260),
                  painter: RipplePainter(
                    progress: _waveController.value,
                    color: _accentColor,
                  ),
                );
              },
            ),

          // Nút chính
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isActive ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _buttonColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(_buttonIcon, color: Colors.white, size: 60),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _statusText,
        key: ValueKey(_statusText),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _isCapturing
              ? const Color(0xFF00C896)
              : _isProcessing
                  ? const Color(0xFFFF9500)
                  : _isSpeaking
                      ? const Color(0xFF6C63FF)
                      : Colors.white60,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    // Làm sạch chuỗi JSON đang stream để hiển thị dễ nhìn hơn
    String displayString = _streamedText
      .replaceAll(RegExp(r'["{}[\]]'), '')
      .replaceAll('scene:', '\n📍 Khung cảnh:\n')
      .replaceAll('objects:', '\n📦 Vật thể:\n')
      .replaceAll('colors:', '\n🎨 Màu sắc:\n')
      .replaceAll('positions:', '\n🗺️ Vị trí:\n')
      .replaceAll('warnings:', '\n⚠️ Cảnh báo:\n')
      .replaceAll('tang_1:', '\n🖼️ Định danh:\n')
      .replaceAll('tang_2:', '\n✨ Mô tả nghệ thuật:\n')
      .replaceAll('confidence:', '\n✅ Độ tin cậy:\n')
      .replaceAll('provider:', '\n🤖 Provider:\n')
      .trim();

    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        height: 250, // Cố định chiều cao và cho phép cuộn
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildTag(Icons.auto_awesome, 'AI mô tả realtime', const Color(0xFF6C63FF)),
                const Spacer(),
                // Nút phát lại
                if (!_isProcessing)
                  GestureDetector(
                    onTap: () async {
                      if (displayString.isNotEmpty) {
                        setState(() {
                          _isSpeaking = true;
                          _statusText = 'AI đang đọc lại...';
                        });
                        await _tts.speak(displayString);
                        if (mounted) {
                          setState(() {
                            _isSpeaking = false;
                            _statusText = 'Chạm đúp để phân tích lại';
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.volume_up, color: Colors.white54, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Phát lại',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  displayString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorText,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomHint() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, color: Colors.white.withOpacity(0.2), size: 14),
            const SizedBox(width: 6),
            Text(
              'Chạm đúp bất kỳ đâu để chụp & phân tích',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Ripple Painter
// ─────────────────────────────────────────────
class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final animProgress = (progress + i / 3) % 1.0;
      final radius = 80.0 + animProgress * 50;
      final opacity = (1.0 - animProgress) * 0.4;
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => true;
}