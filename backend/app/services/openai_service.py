import asyncio
import base64
import logging
from typing import AsyncGenerator
from openai import AsyncOpenAI
from app.core.config import settings
from .gemini_service import VISION_PROMPT

logger = logging.getLogger(__name__)

def get_openai_client():
    if not settings.OPENAI_API_KEY:
        raise ValueError("OPENAI_API_KEY is not configured")
    return AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

async def analyze_with_openai(image_bytes: bytes, mime_type: str = "image/jpeg") -> str:
    """
    Phân tích ảnh toàn bộ (không stream) sử dụng GPT-4o (Vision) làm fallback.
    """
    client = get_openai_client()
    
    # OpenAI Vision API cần ảnh ở dạng base64 data URL
    base64_image = base64.b64encode(image_bytes).decode('utf-8')
    image_url = f"data:{mime_type};base64,{base64_image}"

    logger.info(f"Đang gửi ảnh đến OpenAI GPT-4o...")
    
    try:
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": VISION_PROMPT},
                            {"type": "image_url", "image_url": {"url": image_url}}
                        ]
                    }
                ],
                max_tokens=1000,
            ),
            timeout=40.0,
        )
        logger.info("OpenAI phản hồi thành công.")
        return response.choices[0].message.content or ""
    except asyncio.TimeoutError:
        logger.error("OpenAI timeout sau 40 giây.")
        raise
    except Exception as e:
        logger.error(f"Lỗi khi gọi OpenAI: {e}")
        raise

async def stream_openai_analysis(image_bytes: bytes, mime_type: str = "image/jpeg") -> AsyncGenerator[str, None]:
    """
    Phân tích ảnh và stream kết quả trả về theo từng chunk với GPT-4o
    """
    client = get_openai_client()
    
    base64_image = base64.b64encode(image_bytes).decode('utf-8')
    image_url = f"data:{mime_type};base64,{base64_image}"
    
    logger.info("Bắt đầu stream ảnh đến OpenAI GPT-4o...")
    
    try:
        stream = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": VISION_PROMPT},
                        {"type": "image_url", "image_url": {"url": image_url}}
                    ]
                }
            ],
            max_tokens=1000,
            stream=True
        )
        
        async for chunk in stream:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content
                
    except Exception as e:
        logger.error(f"Lỗi khi stream OpenAI: {e}")
        yield f"\n[Lỗi stream AI: {str(e)}]"
