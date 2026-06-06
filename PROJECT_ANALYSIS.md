# Báo cáo Phân tích và Hoàn thiện Dự án V-Eye

## 1. Giới thiệu dự án
**V-Eye** (Trợ lý thị giác thông minh) là dự án cung cấp khả năng mô tả hình ảnh tự động cho người khiếm thị bằng công nghệ Trí tuệ Nhân tạo. 
Ứng dụng sử dụng camera từ thiết bị di động (Flutter) để chụp ảnh, gửi qua máy chủ xử lý (FastAPI), phân tích bằng các mô hình thị giác ngôn ngữ lớn (LLM Vision), và cuối cùng phản hồi kết quả bằng giọng nói (Text-to-Speech).

## 2. Các vấn đề đã giải quyết

### 2.1 Backend (FastAPI)
Trước khi tối ưu, backend có cấu trúc phẳng, thiếu an toàn và thiếu khả năng phục hồi khi lỗi:
- **Tái cấu trúc kiến trúc**: Chuyển sang mô hình Layered Architecture (`api`, `core`, `models`, `services`, `utils`) giúp dễ dàng bảo trì và mở rộng.
- **Quản lý Cấu hình**: Áp dụng Pydantic BaseSettings giúp quản lý biến môi trường an toàn và có kiểm duyệt kiểu dữ liệu.
- **Cơ chế Fallback (Kháng lỗi)**: 
  - AI Vision: Sử dụng Gemini 2.5 Flash làm luồng chính nhờ khả năng xử lý nhanh, GPT-4o Vision làm luồng dự phòng (fallback) nếu Gemini lỗi hoặc quá tải.
  - Text-to-Speech: Sử dụng OpenAI TTS (giọng đọc chất lượng cao) làm chính, và gTTS (Google TTS) làm dự phòng.
- **Tối ưu hóa Hiệu năng (Performance)**:
  - Streaming (Server-Sent Events): Thay vì chờ AI tạo toàn bộ văn bản (mất 4-6 giây), Server truyền từng phần (chunk) văn bản về Frontend ngay khi sinh ra.
  - Caching (Bộ nhớ đệm): Cài đặt LRU Cache bằng mã băm MD5 của ảnh để giảm thời gian phản hồi với các ảnh trùng lặp.
- **Bảo mật và ổn định**: Tích hợp SlowAPI để giới hạn tốc độ truy cập (Rate Limiting).

### 2.2 Frontend (Flutter)
- Cập nhật `ApiService` để lắng nghe chuỗi Server-Sent Events (SSE).
- Cập nhật giao diện `HomeScreen` để hiển thị chữ theo thời gian thực (như gõ phím).
- Tích hợp logic *Progressive Text-to-Speech*: Tách các đoạn văn bản (dựa vào dấu câu) và gọi TTS ngay lập tức mà không phải chờ quá trình sinh nội dung kết thúc. Cải thiện mạnh mẽ thời gian đến byte đầu tiên (Time To First Byte - TTFB) đối với giọng đọc âm thanh.
- Tinh chỉnh làm sạch dữ liệu luồng (loại bỏ cú pháp JSON) trước khi hiển thị lên màn hình.

## 3. Cấu trúc hệ thống hiện tại

```text
project_cdio_4/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   │   └── routes.py         # Các API Endpoint chính (streaming, cache, tts)
│   │   ├── core/
│   │   │   └── config.py         # Cấu hình Pydantic, load biến môi trường
│   │   ├── models/
│   │   │   └── schemas.py        # Schema Validate dữ liệu đầu vào/ra
│   │   ├── services/
│   │   │   ├── gemini_service.py # Xử lý Gemini API (Streaming)
│   │   │   ├── openai_service.py # Xử lý GPT-4o Vision (Fallback)
│   │   │   ├── tts_service.py    # Xử lý Audio (OpenAI TTS / gTTS)
│   │   │   └── vision_service.py # Điều phối (Orchestrator) AI models
│   │   ├── utils/
│   │   │   ├── cache.py          # LRU Caching
│   │   │   └── helpers.py        # Logic Validate, Hash, Parse JSON
│   │   └── main.py               # Khởi tạo FastAPI, CORS, Limiter
│   ├── .env                      # File môi trường
│   └── requirements.txt          # Các gói thư viện
├── frontend/                     # Ứng dụng Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── home_screen.dart      # Giao diện chính xử lý Streaming & UI
│   │   └── services/
│   │       ├── api_service.dart  # Lớp gọi API SSE
│   │       └── tts_service.dart  # Lớp xử lý âm thanh
```

## 4. Hướng dẫn chạy dự án

### Backend
1. Cài đặt các thư viện: `pip install -r requirements.txt`
2. Cập nhật khóa bí mật trong `backend/.env`:
   - `GEMINI_API_KEY=your_key`
   - `OPENAI_API_KEY=your_key`
3. Chạy Server: `uvicorn app.main:app --reload`
4. API tự động cấp phát tài liệu tại: `http://localhost:8000/docs`

### Frontend
1. Cài đặt thư viện: `flutter pub get`
2. Chạy ứng dụng: `flutter run`
*(Lưu ý: Nếu test bằng máy thật, sửa IP trong `api_service.dart` thành IP máy tính chạy backend)*

## 5. Kết luận
Dự án đã đáp ứng hoàn chỉnh mục tiêu tạo ra một trợ lý ảo nhanh, đáng tin cậy. Kiến trúc hiện tại sẵn sàng cho triển khai thực tế trên server cloud hoặc container (Docker).
