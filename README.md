# 👁️ V-Eye – Trợ lý thị giác thông minh cho người khiếm thị

Ứng dụng AI giúp người khiếm thị **"nhìn"** thế giới qua âm thanh.  
Chụp ảnh → Phân tích bằng AI (Gemini 2.5 Flash / GPT-4o) → Đọc to kết quả bằng giọng tiếng Việt.

---

## 🌟 Tính năng chính

- **Chụp ảnh 1 chạm** – Giao diện Zero-Friction, nút chụp lớn cố định ở giữa màn hình
- **AI Fallback tự động** – Luồng chính: Gemini 2.5 Flash → Dự phòng: GPT-4o Vision
- **TTS Fallback tự động** – OpenAI TTS (`tts-1`, giọng `alloy`) → Dự phòng: gTTS tiếng Việt
- **LRU Cache MD5** – Ảnh giống nhau trả kết quả dưới 15ms, không gọi lại AI
- **Server-Sent Events (SSE)** – Streaming kết quả theo thời gian thực
- **Admin Dashboard** – Giám sát lịch sử chụp ảnh, phát lại audio tại `localhost:8000/admin`
- **Chat Session** – Hỏi đáp tiếp về bức ảnh vừa chụp qua `/api/chat`

---

## 📁 Cấu trúc dự án

```
project_cdio_4/
├── admin_dashboard/           # Giao diện Admin (HTML/CSS/JS + Chart.js)
│   ├── index.html
│   ├── style.css
│   └── script.js
│
├── backend/                   # FastAPI server (Python)
│   ├── app/
│   │   ├── main.py            # Điểm khởi động, CORS, Rate Limiting, Static files
│   │   ├── api/routes.py      # Toàn bộ endpoints
│   │   ├── core/
│   │   │   ├── config.py      # Đọc API keys từ .env
│   │   │   └── database.py    # SQLite: lưu lịch sử phân tích
│   │   ├── models/schemas.py  # Pydantic schemas
│   │   ├── services/
│   │   │   ├── gemini_service.py   # Kết nối Google Gemini
│   │   │   ├── openai_service.py   # Kết nối OpenAI GPT-4o (fallback)
│   │   │   ├── tts_service.py      # Text-to-Speech (OpenAI TTS + gTTS)
│   │   │   └── vision_service.py   # Orchestrator: Gemini → GPT-4o fallback
│   │   └── utils/
│   │       ├── cache.py            # LRU Cache với TTL
│   │       ├── helpers.py          # Validate ảnh, băm MD5, parse JSON
│   │       └── session_store.py    # Lưu phiên chat theo ảnh
│   ├── audio/                 # File MP3 sinh ra khi chạy (gitignored)
│   ├── dataset/               # Ảnh upload & SQLite DB (gitignored)
│   ├── logs/                  # Log file (gitignored)
│   ├── uploads/               # Thư mục upload tạm (gitignored)
│   ├── requirements.txt
│   └── .env                   # API Keys – KHÔNG commit lên git!
│
└── frontend/                  # Flutter Web app
    ├── lib/
    │   ├── main.dart               # Giao diện camera, nút chụp, phát audio
    │   └── services/api_service.dart  # Gửi ảnh lên backend, nhận audioUrl
    ├── web/                    # Flutter Web entry point
    │   ├── index.html
    │   └── manifest.json
    └── pubspec.yaml
```

---

## 🚀 Hướng dẫn khởi động

> ⚠️ **Quan trọng:** Cần mở **2 terminal** riêng chạy song song.

### Terminal 1 — Backend (FastAPI)

```bash
# Bắt buộc phải vào đúng thư mục backend trước khi chạy uvicorn
cd backend

# Cài dependencies (chỉ cần làm 1 lần)
pip install -r requirements.txt

# Chạy server
uvicorn app.main:app --reload
```

Server khởi động tại: `http://localhost:8000`  
Swagger API Docs: `http://localhost:8000/docs`  
Admin Dashboard: `http://localhost:8000/admin`

### Terminal 2 — Frontend (Flutter Web)

```bash
cd frontend

# Cài packages (chỉ cần làm 1 lần)
flutter pub get

# Chạy trên trình duyệt Chrome
flutter run -d chrome
```

---

## ⚙️ Cấu hình môi trường

Tạo file `backend/.env` (xem `backend/.env.example` nếu có) với nội dung:

```env
GEMINI_API_KEY=your_gemini_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
```

---

## 🌐 API Endpoints

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| `GET`  | `/` | Kiểm tra server (Rate limit: 10 req/phút) |
| `GET`  | `/api/status` | Trạng thái API keys & kích thước cache |
| `POST` | `/api/describe-image` | Phân tích ảnh, trả JSON + URL file MP3 |
| `POST` | `/api/stream-description` | Phân tích ảnh, stream text qua SSE |
| `POST` | `/api/chat` | Hỏi đáp tiếp về ảnh (dùng session_id) |
| `POST` | `/api/generate-audio` | Tạo file MP3 từ văn bản |
| `GET`  | `/api/dashboard/stats` | Thống kê tổng quan cho Dashboard |
| `GET`  | `/api/dashboard/history` | Lịch sử 50 lượt phân tích gần nhất |

---

## 🛠️ Tech Stack

| Thành phần | Công nghệ |
|-----------|-----------|
| Backend | Python 3.11+, FastAPI, Uvicorn (ASGI), Pydantic, SlowAPI |
| AI Vision | Google Gemini 2.5 Flash (chính) + OpenAI GPT-4o (dự phòng) |
| AI TTS | OpenAI TTS `tts-1` (chính) + Google gTTS (dự phòng) |
| Database | SQLite (nhúng, không cần server riêng) |
| Frontend | Flutter 3.x, Dart — build target: **Web only** |
| Dashboard | HTML5 + Vanilla CSS + Vanilla JS + Chart.js |
