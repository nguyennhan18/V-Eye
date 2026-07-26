import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visual_assistant/services/api_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Lỗi khởi tạo camera: ${e.code}, ${e.description}');
  }
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
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'SF Pro Display',
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  // khoi tao doi tuong phat am thanh
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    // Chọn camera sau, giảm độ phân giải xuống medium để tải lên siêu tốc
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("Lỗi setup camera: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });
    
    // Ngừng nhạc nếu đang phát kết quả cũ
    await _audioPlayer.stop();

    try {
      // 1. Chụp ảnh
      XFile file = await _cameraController!.takePicture();
      
      // 2. Gọi API lấy cả text mô tả và link file audio cùng một lúc
      final result = await ApiService.describeImage(file);
      final audioUrl = result['audioUrl'];

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      // 3. Phát audio từ URL
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
      } else {
        print("Lỗi hệ thống: Không có link audio trả về.");
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      print("Lỗi hệ thống: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Camera Preview (Full screen)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // 2. Loading overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Hệ thống đang xử lý...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    )
                  ],
                ),
              ),
            ),

          // 3. Capture Button (Bottom)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePictureAndAnalyze,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isProcessing ? Colors.grey : Colors.redAccent,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}