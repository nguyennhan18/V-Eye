from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parents[2]

class Settings(BaseSettings):
    GEMINI_API_KEY: str = ""
    OPENAI_API_KEY: str = ""
    
    # Thư mục lưu trữ
    UPLOAD_DIR: Path = BASE_DIR / "uploads"
    AUDIO_DIR: Path = BASE_DIR / "audio"
    LOG_DIR: Path = BASE_DIR / "logs"

    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), 
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()

# Đảm bảo thư mục tồn tại
settings.UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
settings.AUDIO_DIR.mkdir(parents=True, exist_ok=True)
settings.LOG_DIR.mkdir(parents=True, exist_ok=True)