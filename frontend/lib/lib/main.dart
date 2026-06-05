import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visual Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: const SplashScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  bool _isListening = false;
  bool _isProcessing = false;
  String _resultText = '';

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  final List<String> _fakeResults = [
    'Trước mặt bạn có một quyển sách màu đỏ, cách khoảng 50cm',
    'Đây là một ly cà phê, còn đang nóng',
    'Trước mặt bạn có một chiếc điện thoại màu đen',
    'Đây là một quyển vở, có chữ viết bên trong',
    'Trước mặt bạn có một chiếc bút bi màu xanh',
  ];
  int _resultIndex = 0;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (_isProcessing) return;

    if (!_isListening) {
      setState(() {
        _isListening = true;
        _resultText = '';
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _isProcessing = true;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _resultText = _fakeResults[_resultIndex % _fakeResults.length];
            _resultIndex++;
            _isProcessing = false;
          });
        });
      });
    } else {
      setState(() {
        _isListening = false;
        _isProcessing = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _resultText = _fakeResults[_resultIndex % _fakeResults.length];
          _resultIndex++;
          _isProcessing = false;
        });
      });
    }
  }

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
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF0A0A0A),
                  ],
                ),
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visual AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'Trợ lý thị giác thông minh',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FF88),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Sẵn sàng',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main center button
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ripple + button
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple rings khi đang nghe
                        if (_isListening) ...[
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(260, 260),
                                painter: RipplePainter(
                                  progress: _waveController.value,
                                  color: const Color(0xFFFF3B5C),
                                ),
                              );
                            },
                          ),
                        ],

                        // Nút chính
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isListening ? _pulseAnimation.value : 1.0,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isListening
                                        ? [
                                            const Color(0xFFFF3B5C),
                                            const Color(0xFFFF6B35),
                                          ]
                                        : _isProcessing
                                            ? [
                                                const Color(0xFFFF9500),
                                                const Color(0xFFFFCC00),
                                              ]
                                            : [
                                                const Color(0xFF6C63FF),
                                                const Color(0xFF3B82F6),
                                              ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isListening
                                              ? const Color(0xFFFF3B5C)
                                              : _isProcessing
                                                  ? const Color(0xFFFF9500)
                                                  : const Color(0xFF6C63FF))
                                          .withOpacity(0.5),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isListening
                                      ? Icons.mic
                                      : _isProcessing
                                          ? Icons.auto_awesome
                                          : Icons.mic_none,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isListening
                          ? 'Đang nghe...'
                          : _isProcessing
                              ? 'AI đang phân tích...'
                              : 'Chạm đúp để bắt đầu',
                      key: ValueKey(_isListening.toString() + _isProcessing.toString()),
                      style: TextStyle(
                        color: _isListening
                            ? const Color(0xFFFF3B5C)
                            : _isProcessing
                                ? const Color(0xFFFF9500)
                                : Colors.white60,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Kết quả AI
            if (_resultText.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Container(
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
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFF6C63FF),
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'AI mô tả',
                                  style: TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _resultText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.6,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.white.withOpacity(0.2),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chạm đúp bất kỳ đâu trên màn hình',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ripple effect painter
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