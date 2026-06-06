import os
import uuid
import logging
from gtts import gTTS
from app.core.config import settings

logger = logging.getLogger(__name__)

def _generate_filename() -> str:
    return f"{uuid.uuid4().hex}.mp3"

async def generate_audio(text: str) -> tuple[str, str]:
    """
    Tạo audio từ text. Ưu tiên OpenAI TTS, fallback sang gTTS.
    Trả về: (file_path, provider)
    """
    filename = _generate_filename()
    file_path = settings.AUDIO_DIR / filename
    
    try:
        if settings.OPENAI_API_KEY:
            # Ưu tiên OpenAI TTS
            from openai import AsyncOpenAI
            client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
            
            logger.info("Đang tạo audio bằng OpenAI TTS...")
            response = await client.audio.speech.create(
                model="tts-1",
                voice="alloy", # Hoặc các giọng khác: echo, fable, onyx, nova, shimmer
                input=text
            )
            response.stream_to_file(file_path)
            return str(file_path), "openai"
        else:
            raise ValueError("Không có OPENAI_API_KEY")
            
    except Exception as e:
        logger.warning(f"Lỗi OpenAI TTS ({e}). Fallback sang gTTS...")
        
        # Fallback sang gTTS
        try:
            tts = gTTS(text=text, lang='vi', slow=False)
            tts.save(str(file_path))
            return str(file_path), "gtts"
        except Exception as e2:
            logger.error(f"Lỗi gTTS fallback: {e2}")
            raise RuntimeError(f"Không thể tạo audio: {e2}")
