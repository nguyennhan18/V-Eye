import 'package:flutter/material.dart';
import 'home_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _guides = [
    {
      'icon': Icons.touch_app,
      'color': const Color(0xFF6C63FF),
      'title': 'Chạm đúp để bắt đầu',
      'desc': 'Chạm đúp vào bất kỳ đâu trên màn hình để bắt đầu đặt câu hỏi cho AI',
    },
    {
      'icon': Icons.mic,
      'color': const Color(0xFFFF3B5C),
      'title': 'Nói câu hỏi của bạn',
      'desc': 'Sau khi chạm đúp, hãy nói to câu hỏi của bạn. Ví dụ: "Trước mặt tôi có gì?"',
    },
    {
      'icon': Icons.camera_alt,
      'color': const Color(0xFF00C896),
      'title': 'AI phân tích ảnh',
      'desc': 'App tự động chụp ảnh và gửi lên AI để phân tích. Không cần làm gì thêm!',
    },
    {
      'icon': Icons.volume_up,
      'color': const Color(0xFFFF9500),
      'title': 'Nghe kết quả',
      'desc': 'AI sẽ đọc to kết quả cho bạn nghe. Bạn không cần nhìn màn hình!',
    },
  ];

  void _nextPage() {
    if (_currentPage < _guides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  ),
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _guides.length,
                itemBuilder: (context, index) {
                  final guide = _guides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (guide['color'] as Color).withOpacity(0.15),
                            border: Border.all(
                              color: (guide['color'] as Color).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            guide['icon'] as IconData,
                            color: guide['color'] as Color,
                            size: 70,
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Title
                        Text(
                          guide['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        // Description
                        Text(
                          guide['desc'] as String,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _guides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF6C63FF)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Next button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GestureDetector(
                onTap: _nextPage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6C63FF),
                        Color(0xFF3B82F6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    _currentPage == _guides.length - 1
                        ? 'Bắt đầu ngay!'
                        : 'Tiếp theo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}