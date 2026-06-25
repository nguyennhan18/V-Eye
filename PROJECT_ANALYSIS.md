# Phân tích Dự án V-Eye (Cập nhật mới nhất)

## 1. Tổng quan dự án
V-Eye là một ứng dụng trợ lý thị giác thông minh dành cho người khiếm thị. Khác với thiết kế gốc (hệ thống bảo tàng quét NFC), dự án hiện tại đã được tinh chỉnh tối đa thành một bản demo Web App tập trung vào AI cốt lõi: **Sử dụng Camera chụp ảnh -> Gửi lên Server phân tích -> Đọc kết quả bằng giọng nói (TTS).**

## 2. Kiến trúc hệ thống
Hệ thống được chia thành 2 phần tách biệt:
- **Backend:** Xây dựng bằng Python với Framework **FastAPI**. Chịu trách nhiệm nhận ảnh, xử lý AI và trả về mô tả.
- **Frontend:** Xây dựng bằng Dart với Framework **Flutter** (biên dịch ra nền tảng Web). Chịu trách nhiệm hiển thị giao diện Camera, tương tác người dùng và phát âm thanh.

---

## 3. Phân tích chi tiết Backend (Thư mục `backend/`)

Backend đóng vai trò là "bộ não" của ứng dụng, có cơ chế **Fallback (Dự phòng thông minh)** để đảm bảo ứng dụng không bao giờ bị sập nếu một API AI bị lỗi.

### Các File Quan Trọng
- **`app/main.py`**: File gốc để khởi chạy ứng dụng FastAPI, cấu hình CORS (cho phép Frontend ở port khác gọi tới) và đăng ký các routes.
- **`app/api/routes.py`**: Chứa cổng giao tiếp (Endpoint) `/api/describe-image`. Nó nhận file ảnh (UploadFile), gọi `vision_service` và trả kết quả về cho Frontend.
- **`app/models/schemas.py`**: Nơi định nghĩa chuẩn cấu trúc dữ liệu trả về cho Frontend (Dùng Pydantic). Cấu trúc hiện tại cực kỳ tối giản, chỉ chứa 1 trường duy nhất là `description` (Nội dung mô tả) và `provider` (Tên AI đã xử lý).
- **`app/services/vision_service.py`**: Đóng vai trò làm nhạc trưởng (Orchestrator). Hàm `analyze_image_with_fallback` sẽ gọi AI Gemini trước. Nếu Gemini bị kẹt mạng (503) hoặc lỗi, nó sẽ tự động bắt lỗi (catch) và đẩy qua OpenAI (GPT-4o) để phân tích.
- **`app/services/gemini_service.py`**: Đảm nhiệm việc kết nối với API của Google Gemini (`gemini-2.5-flash`). Tại đây chứa **Prompt siêu chi tiết** được thiết kế riêng: *"Bạn là trợ lý cho người khiếm thị... Hãy mô tả thật CHI TIẾT, sống động..."*.
- **`app/services/openai_service.py`**: Đảm nhiệm kết nối với OpenAI (GPT-4o) để làm phương án dự phòng.
- **`app/utils/helpers.py`**: Chứa hàm `parse_ai_json`. Do các AI đôi khi trả về chuỗi JSON bị kẹp trong dấu markdown (````json ... ````), hàm này dùng để làm sạch và bóc tách dữ liệu JSON an toàn. Nếu AI trả về định dạng sai, nó sẽ gom toàn bộ câu trả lời đó cho vào trường `description` để tránh sập app.

---

## 4. Phân tích chi tiết Frontend (Thư mục `frontend/`)

Frontend là bộ mặt của ứng dụng, được cấu hình để chạy tối ưu trên trình duyệt Web (Chrome/Safari) giúp việc demo trở nên cực kỳ nhanh chóng.

### Các File Quan Trọng
- **`lib/main.dart`**: Linh hồn của giao diện.
  - Tích hợp `camera` package để load trực tiếp Webcam/Camera điện thoại lên toàn màn hình (`CameraPreview`).
  - Thiết kế UI tối giản với một nút chụp (Capture Button) lớn ở giữa.
  - Quản lý trạng thái (State): Hiện "AI đang phân tích..." khi chờ đợi máy chủ.
  - Tích hợp `flutter_tts` (Text-to-Speech). Ngay khi Backend trả kết quả chữ về, nó sẽ kích hoạt loa máy tính để đọc to bằng tiếng Việt.
- **`lib/services/api_service.dart`**: "Người vận chuyển" dữ liệu.
  - Nhiệm vụ: Gom bức ảnh vừa chụp và gửi lên Backend.
  - **Kỹ thuật Web:** Vì chạy trên Web không có hệ thống File thật, nó không thể dùng đường dẫn ảo (path). File này đã được tối ưu bằng cách dùng lệnh `image.readAsBytes()` để đọc thẳng ảnh từ bộ nhớ RAM, sau đó đính kèm chuẩn `MediaType` (`image/jpeg`) qua thư viện `http_parser` để Bypass bộ lọc bảo mật khắt khe của Backend.
- **`web/index.html`**: File mồi (Bootstrap) của nền tảng Flutter Web. Đóng vai trò nạp JavaScript Engine của Flutter vào trình duyệt để chạy được code Dart.

---

## 5. Quy trình Hoạt động (Workflow Thực tế)

1. **User mở Web:** `main.dart` gọi quyền truy cập Camera và render `CameraPreview` tràn viền.
2. **User bấm nút chụp:** `main.dart` gọi hàm `takePicture()`, lấy được file ảnh (`XFile`).
3. **Gửi lên Server:** `api_service.dart` chuyển đổi ảnh thành dạng Bytes (RAM) và gửi qua cổng `POST http://localhost:8000/api/describe-image`.
4. **Backend nhận & Xử lý:**
   - `routes.py` nhận ảnh -> Đẩy qua `vision_service.py`.
   - `vision_service.py` gọi Gemini 2.5 Flash -> Trả về đoạn JSON chứa mô tả. (Nếu Gemini lỗi 503, tự động chuyển sang gọi OpenAI GPT-4o).
5. **Trả kết quả:** `helpers.py` làm sạch JSON, đóng gói vào `ArtAnalysisResponse` và gửi về lại cho Frontend.
6. **Frontend hiển thị & Đọc:** `main.dart` nhận văn bản, cập nhật lên màn hình và kích hoạt `flutter_tts` để đọc to câu mô tả.

---

## 6. Lệnh Khởi động Dự án
*Lưu ý: Luôn chạy ở 2 cửa sổ Terminal song song*

**Khởi động Backend (Port 8000):**
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload
```

**Khởi động Frontend (Web App):**
```bash
cd frontend
flutter run -d chrome
```
