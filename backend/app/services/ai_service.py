import asyncio
import logging
from google import genai
from google.genai import types
from app.core.config import GEMINI_API_KEY

logger = logging.getLogger(__name__)

client = genai.Client(api_key=GEMINI_API_KEY)

async def analyze_art_with_gemini(image_bytes: bytes, content_type: str | None) -> str:
    """
    Phân tích bức tranh/ảnh bằng Gemini và trả về mô tả JSON.
    
    Args:
        image_bytes: Dữ liệu ảnh dưới dạng bytes.
        content_type: MIME type của ảnh (ví dụ: "image/jpeg").
    
    Returns:
        Chuỗi JSON với hai trường tang_1 và tang_2.
    
    Raises:
        asyncio.TimeoutError: Nếu Gemini không phản hồi trong 30 giây.
    """
    model_name = "gemini-2.5-flash"

    prompt = """
            Bạn là trợ lý cho người khiếm thị.
            Đây KHÔNG PHẢI là kết quả giả lập. Hãy chứng minh khả năng AI của bạn bằng cách mô tả thật CHI TIẾT, sống động và tự nhiên bức tranh/khung cảnh trong ảnh này có những gì (màu sắc, ánh sáng, bố cục, các vật thể và ý nghĩa nếu có).
            BẮT BUỘC trả về bằng định dạng JSON hợp lệ. Không dùng markdown, không bọc trong ```json.

            Schema bắt buộc:
            {
                "description": "Nội dung mô tả chi tiết bức tranh..."
            }
            """
    image_part = types.Part.from_bytes(
        mime_type=content_type or "image/jpeg",
        data=image_bytes,
    )

    logger.info("Đang gửi ảnh đến Gemini (%s bytes)...", len(image_bytes))

    try:
        response = await asyncio.wait_for(
            client.aio.models.generate_content(
                model=model_name,
                contents=[prompt, image_part]
            ),
            timeout=30.0,
        )
        logger.info("Gemini phản hồi thành công.")
        return response.text
    except asyncio.TimeoutError:
        logger.error("Gemini timeout sau 30 giây.")
        raise
    except Exception as e:
        logger.error("Lỗi khi gọi Gemini: %s", str(e))
        raise

