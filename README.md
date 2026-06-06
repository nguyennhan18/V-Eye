# 👁️ V-Eye – Trợ lý thị giác thông minh cho người khiếm thị

Ứng dụng AI nhân văn giúp người khiếm thị **"nhìn"** thế giới qua âm thanh. 
Chỉ cần chạm đúp vào màn hình, app tự động chụp ảnh, phân tích theo thời gian thực (Server-Sent Events) bằng mô hình AI Vision (Gemini 2.5 Flash / GPT-4o), và **đọc to** kết quả bằng giọng tiếng Việt (OpenAI TTS).

---

## 🌟 Tính năng chính

- **Chụp ảnh tự động** – Không cần tìm nút, chỉ chạm đúp bất kỳ đâu.
- **Phân tích AI Đa Mô Hình** – Luồng chính: Gemini 2.5 Flash; Luồng dự phòng: GPT-4o Vision.
- **Streaming End-to-End** – Trả kết quả ngay lập tức dưới dạng luồng dữ liệu (chunks), loại bỏ độ trễ (TTFB thấp).
- **Progressive Text-to-Speech** – Đọc ngay từng câu khi backend vừa sinh ra (không cần chờ toàn bộ văn bản).
- **Caching & Rate Limiting** – Bộ nhớ đệm giảm tải AI (LRU Cache MD5) và bảo vệ API (SlowAPI).

---

## 📁 Cấu trúc dự án

```
project_cdio_4/
├── backend/               # FastAPI server
│   ├── app/
│   │   ├── api/routes.py         # Endpoints: /describe-image, /stream-description, /generate-audio
│   │   ├── core/config.py        # Cấu hình Pydantic BaseSettings
│   │   ├── models/schemas.py     # Lược đồ Pydantic
│   │   ├── services/             # Logic xử lý AI (Gemini, OpenAI, TTS)
│   │   ├── utils/                # Cache, validation ảnh
│   │   └── main.py               # Ứng dụng gốc
│   ├── requirements.txt
│   └── .env               # API keys (KHÔNG commit)
│
└── frontend/              # Flutter mobile app
    └── lib/
        ├── main.dart
        ├── home_screen.dart   # Giao diện chính xử lý Streaming & UI
        └── services/
            ├── api_service.dart   # Gọi backend API (hỗ trợ SSE)
            └── tts_service.dart   # Text-to-Speech (flutter_tts)
```

---

## 🚀 Hướng dẫn chạy

### Backend

```bash
# 1. Vào thư mục backend
cd backend

# 2. Tạo môi trường ảo
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate

# 3. Cài dependencies
pip install -r requirements.txt

# 4. Tạo file .env (thêm API Key)
# Mở file .env và điền:
# GEMINI_API_KEY=your_key
# OPENAI_API_KEY=your_key

# 5. Chạy server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Server chạy tại: `http://0.0.0.0:8000`
API Docs (Swagger): `http://localhost:8000/docs`

### Frontend (Flutter)

```bash
# 1. Vào thư mục frontend
cd frontend

# 2. Cài packages
flutter pub get

# 3. Cấu hình địa chỉ backend (lib/services/api_service.dart)
# - Android emulator: http://10.0.2.2:8000
# - iOS Simulator:    http://127.0.0.1:8000
# - Thiết bị vật lý:  http://<IP-máy-tính-LAN>:8000

# 4. Chạy app
flutter run
```

---

## 🌐 API Endpoints mới

| Method | Path | Mô tả |
|--------|------|-------|
| `GET` | `/` | Home & Rate Limiting |
| `GET` | `/api/status` | Tình trạng cấu hình API & Cache |
| `POST` | `/api/describe-image` | Phân tích ảnh và trả về toàn bộ JSON ngay một lần |
| `POST` | `/api/stream-description` | Phân tích ảnh và stream text dưới dạng Server-Sent Events |
| `POST` | `/api/generate-audio` | Tạo âm thanh TTS từ text (OpenAI / gTTS) |

---

## 🛠️ Công nghệ sử dụng

| Lớp | Công nghệ |
|-----|-----------|
| Backend | Python 3.11, FastAPI, Pydantic, SlowAPI, SSE-Starlette |
| AI | Google Gemini-2.5-flash, OpenAI GPT-4o, OpenAI TTS |
| Frontend | Flutter, Dart |
| Core Packages | `flutter_tts`, `camera`, `http` |

