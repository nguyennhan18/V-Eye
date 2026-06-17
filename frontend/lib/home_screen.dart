import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'services/api_service.dart';
import 'services/tts_service.dart';
import 'services/nfc_service.dart';
import 'services/mlkit_utils.dart';

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
  bool _isScanningFrame = false;
  bool _isListening = false;
  String _statusText = 'Chạm đúp hoặc Quét NFC để phân tích';

  String _streamedText = '';
  String _errorText = '';
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // ── Camera & ML Kit ─────────────────────────
  CameraController? _cameraController;
  bool _cameraReady = false;
  ObjectDetector? _objectDetector;
  bool _canProcessFrame = true;
  int _lastGuidanceTime = 0;

  // ── Services ───────────────────────────────
  final TtsService _tts = TtsService();
  final NfcService _nfc = NfcService();
  final SpeechToText _speechToText = SpeechToText();

  // ── Animation ──────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initServices();
  }

  Future<void> _initServices() async {
    await _initCamera();
    await _tts.init();

    // Khởi tạo ML Kit
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);

    // Khởi tạo Speech To Text
    await _speechToText.initialize();

    // Khởi tạo NFC
    await _nfc.init();
    await _nfc.startListening(_onNfcScanned);
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
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: _cameraImageFormatGroup,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = 'Lỗi camera: $e');
    }
  }

  ImageFormatGroup get _cameraImageFormatGroup {
    if (kIsWeb) {
      return ImageFormatGroup.unknown;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ImageFormatGroup.nv21;
    }
    return ImageFormatGroup.bgra8888;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _cameraController?.dispose();
    _objectDetector?.close();
    _tts.dispose();
    _nfc.stopListening();
    super.dispose();
  }

  // ── LUỒNG 1: NFC & AUTO FRAMING ────────────
  void _onNfcScanned() {
    if (_isScanningFrame || _isProcessing) return;

    setState(() {
      _isScanningFrame = true;
      _statusText = 'Giơ điện thoại lên phía trước...';
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    });

    _tts.speak("Đã tìm thấy tranh. Giơ điện thoại lên phía trước.");
    _startAutoFraming();
  }

  void _startAutoFraming() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_canProcessFrame || !_isScanningFrame) return;
      _canProcessFrame = false;

      final inputImage =
          MLKitUtils.inputImageFromCameraImage(image, _cameraController!);
      if (inputImage == null) {
        _canProcessFrame = true;
        return;
      }

      try {
        final objects = await _objectDetector!.processImage(inputImage);

        final now = DateTime.now().millisecondsSinceEpoch;
        final shouldSpeakGuidance =
            (now - _lastGuidanceTime) > 2000 && !_tts.isSpeaking;

        if (objects.isNotEmpty) {
          final box = objects.first.boundingBox;
          final imgWidth = image.width.toDouble();
          final imgHeight = image.height.toDouble();

          final boxCenterX = box.center.dx;
          final boxCenterY = box.center.dy;

          final frameCenterX = imgWidth / 2;
          final frameCenterY = imgHeight / 2;

          bool isCentered =
              (boxCenterX - frameCenterX).abs() < (imgWidth * 0.2) &&
                  (boxCenterY - frameCenterY).abs() < (imgHeight * 0.2);
          bool isLargeEnough =
              (box.width * box.height) > (imgWidth * imgHeight * 0.3);

          if (isCentered && isLargeEnough) {
            _cameraController!.stopImageStream();
            setState(() => _isScanningFrame = false);
            _tts.speak("Tốt rồi, giữ nguyên.");

            await Future.delayed(const Duration(seconds: 1));
            _captureAndAnalyze();
          } else if (shouldSpeakGuidance) {
            _lastGuidanceTime = now;
            if (!isLargeEnough) {
              _tts.speak("Tiến lại gần một chút.");
            } else if (boxCenterY > frameCenterY + 100) {
              _tts.speak("Lên cao hơn.");
            } else if (boxCenterY < frameCenterY - 100) {
              _tts.speak("Xuống thấp hơn.");
            }
          }
        }
      } catch (e) {
        debugPrint('ML Kit frame processing failed: $e');
      }
      _canProcessFrame = true;
    });
  }

  // ── LUỒNG 2: MANUAL CAPTURE ─────────────────
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

    if (_isScanningFrame) {
      _cameraController?.stopImageStream();
      _isScanningFrame = false;
    }

    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _captureAndAnalyze();
  }

  // ── XỬ LÝ CHỤP & STREAMING ──────────────────
  Future<void> _captureAndAnalyze() async {
    setState(() {
      _isCapturing = true;
      _streamedText = '';
      _errorText = '';
      _statusText = 'Đang chụp ảnh...';
    });

    XFile? imageFile;
    try {
      if (!_cameraReady || _cameraController == null) {
        throw Exception('Camera chưa sẵn sàng.');
      }
      imageFile = await _cameraController!.takePicture();
    } catch (e) {
      _handleError('Không thể chụp ảnh: $e');
      return;
    }

    setState(() {
      _isCapturing = false;
      _isProcessing = true;
      _statusText = 'AI đang phân tích...';
      _isSpeaking = true;
    });

    try {
      String bufferText = '';

      // Lắng nghe stream với session_id
      await for (final chunk
          in ApiService.streamDescription(imageFile, _sessionId)) {
        if (!mounted || !_isProcessing) break;

        setState(() => _streamedText += chunk);

        bufferText += chunk;
        if (bufferText.contains('.') ||
            bufferText.contains('\n') ||
            bufferText.contains('?') ||
            bufferText.contains('!')) {
          String cleanTextToSpeak = bufferText
              .replaceAll(RegExp(r'["{}[\]]'), '')
              .replaceAll(
                  RegExp(
                      r'(scene|objects|colors|positions|warnings|confidence|tang_1|tang_2|provider):'),
                  '')
              .trim();

          if (cleanTextToSpeak.isNotEmpty && cleanTextToSpeak.length > 5) {
            _tts.speak(cleanTextToSpeak);
          }
          bufferText = '';
        }
      }

      if (bufferText.trim().isNotEmpty) {
        String cleanText = bufferText
            .replaceAll(RegExp(r'["{}[\]]'), '')
            .replaceAll(RegExp(r'(.*):'), '')
            .trim();
        if (cleanText.isNotEmpty) _tts.speak(cleanText);
      }

      _waitForTtsAndListen();
    } on ApiException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('Lỗi không xác định: $e');
    }
  }

  // ── LUỒNG 3: VOICE CHAT ─────────────────────
  void _waitForTtsAndListen() async {
    setState(() => _isProcessing = false);

    while (_tts.isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = true;
        _statusText = 'Đang lắng nghe câu hỏi...';
      });
      _tts.speak("Bạn có muốn hỏi thêm gì không?");

      await Future.delayed(const Duration(seconds: 2));

      _speechToText.listen(
        onResult: (result) async {
          if (result.finalResult) {
            _speechToText.stop();
            setState(() => _isListening = false);
            _sendChatMessage(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'vi_VN',
          listenFor: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> _sendChatMessage(String question) async {
    if (question.trim().isEmpty) {
      setState(() => _statusText = 'Chạm đúp hoặc Quét NFC để phân tích lại');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'Đang trả lời...';
      _streamedText += '\n\n🗣️ Bạn: $question\n🤖 AI: ';
    });

    try {
      String bufferText = '';

      await for (final chunk in ApiService.chat(_sessionId, question)) {
        if (!mounted || !_isProcessing) break;

        setState(() => _streamedText += chunk);

        bufferText += chunk;
        if (bufferText.contains('.') ||
            bufferText.contains('\n') ||
            bufferText.contains('?') ||
            bufferText.contains('!')) {
          String cleanTextToSpeak = bufferText
              .replaceAll(RegExp(r'["{}[\]]'), '')
              .replaceAll(
                  RegExp(
                      r'(scene|objects|colors|positions|warnings|confidence|tang_1|tang_2|provider):'),
                  '')
              .trim();

          if (cleanTextToSpeak.isNotEmpty && cleanTextToSpeak.length > 5) {
            _tts.speak(cleanTextToSpeak);
          }
          bufferText = '';
        }
      }

      if (bufferText.trim().isNotEmpty) {
        String cleanText = bufferText
            .replaceAll(RegExp(r'["{}[\]]'), '')
            .replaceAll(RegExp(r'(.*):'), '')
            .trim();
        if (cleanText.isNotEmpty) _tts.speak(cleanText);
      }

      _waitForTtsAndListen();
    } on ApiException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('Lỗi không xác định: $e');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _isCapturing = false;
      _isProcessing = false;
      _isSpeaking = false;
      _isScanningFrame = false;
      _isListening = false;
      _errorText = message;
      _statusText = 'Chạm đúp để thử lại';
    });
    _tts.speak('Đã có lỗi xảy ra. $message');
  }

  // ── UI HELPERS ──────────────────────────────
  List<Color> get _buttonColors {
    if (_isCapturing || _isScanningFrame) {
      return [const Color(0xFF00C896), const Color(0xFF00A878)];
    }
    if (_isProcessing) {
      return [const Color(0xFFFF9500), const Color(0xFFFFCC00)];
    }
    if (_isListening) return [const Color(0xFFFF4081), const Color(0xFFC51162)];
    if (_isSpeaking) return [const Color(0xFF6C63FF), const Color(0xFF3B82F6)];
    return [const Color(0xFF6C63FF), const Color(0xFF3B82F6)];
  }

  Color get _accentColor {
    if (_isCapturing || _isScanningFrame) return const Color(0xFF00C896);
    if (_isProcessing) return const Color(0xFFFF9500);
    if (_isListening) return const Color(0xFFFF4081);
    if (_isSpeaking) return const Color(0xFF6C63FF);
    return const Color(0xFF6C63FF);
  }

  IconData get _buttonIcon {
    if (_isCapturing) return Icons.camera_alt;
    if (_isScanningFrame) return Icons.document_scanner;
    if (_isProcessing) return Icons.auto_awesome;
    if (_isListening) return Icons.mic;
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
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
                ),
              ),
            ),
            _buildTopBar(),
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
            if (_streamedText.isNotEmpty) _buildResultCard(),
            if (_errorText.isNotEmpty) _buildErrorCard(),
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
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('V-Eye',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                Text('Trợ lý thị giác thông minh',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
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
                  Text(_cameraReady ? 'Sẵn sàng' : 'Đang khởi động',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    final bool isActive = _isCapturing ||
        _isProcessing ||
        _isSpeaking ||
        _isScanningFrame ||
        _isListening;
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) => CustomPaint(
                size: const Size(260, 260),
                painter: RipplePainter(
                    progress: _waveController.value, color: _accentColor),
              ),
            ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: isActive ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _buttonColors),
                  boxShadow: [
                    BoxShadow(
                        color: _accentColor.withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 10)
                  ],
                ),
                child: Icon(_buttonIcon, color: Colors.white, size: 60),
              ),
            ),
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
            color: _accentColor,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildResultCard() {
    String displayString = _streamedText
        .replaceAll(RegExp(r'["{}[\]]'), '')
        .replaceAll('scene:', '\n📍 Khung cảnh:\n')
        .replaceAll('objects:', '\n📦 Vật thể:\n')
        .replaceAll('colors:', '\n🎨 Màu sắc:\n')
        .replaceAll('positions:', '\n🗺️ Vị trí:\n')
        .replaceAll('warnings:', '\n⚠️ Cảnh báo:\n')
        .replaceAll('tang_1:', '\n🖼️ Định danh:\n')
        .replaceAll('tang_2:', '\n✨ Mô tả:\n')
        .trim();

    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.06)
              ]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTag(
                    Icons.auto_awesome, 'AI mô tả', const Color(0xFF6C63FF)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(displayString,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                        letterSpacing: 0.3)),
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
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
                child: Text(_errorText,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 14, height: 1.5))),
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
            Icon(Icons.touch_app,
                color: Colors.white.withValues(alpha: 0.2), size: 14),
            const SizedBox(width: 6),
            Text(
              _streamedText.isNotEmpty
                  ? 'Chạm đúp để phân tích lại'
                  : 'Chạm đúp để phân tích',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
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
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => true;
}
