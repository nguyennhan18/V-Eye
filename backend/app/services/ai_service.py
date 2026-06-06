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
            Bạn là trợ lý mô tả tranh nghệ thuật dành cho người khiếm thị.

            Hãy phân tích bức tranh trong ảnh và trả lời BẮT BUỘC bằng JSON hợp lệ.
            Không dùng markdown. Không bọc trong ```json.

            Schema bắt buộc:
            {
            "tang_1": "Thông tin định danh nhanh: tên tác phẩm, họa sĩ, niên đại, trường phái. Tối đa 2 câu.",
            "tang_2": "Mô tả thị giác nghệ thuật: bố cục, màu sắc, nét cọ, cảm xúc, thông điệp hoặc bối cảnh văn hóa."
            }

            Nếu không nhận diện chắc chắn tên tranh, vẫn mô tả những gì nhìn thấy và ghi rõ là chưa chắc chắn.
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

