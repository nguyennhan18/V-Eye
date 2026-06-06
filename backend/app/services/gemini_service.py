import asyncio
import logging
from typing import AsyncGenerator
from google import genai
from google.genai import types
from app.core.config import settings

logger = logging.getLogger(__name__)

# Khởi tạo client lazily để không bị crash nếu key trống lúc import
def get_gemini_client():
    if not settings.GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY is not configured")
    return genai.Client(api_key=settings.GEMINI_API_KEY)

# Prompt chung cho phân tích ảnh
VISION_PROMPT = """
Bạn là trợ lý mô tả tranh nghệ thuật dành cho người khiếm thị.
Hãy phân tích bức tranh trong ảnh và trả lời BẮT BUỘC bằng JSON hợp lệ.
Không dùng markdown. Không bọc trong ```json.

Schema bắt buộc:
{
"scene": "Mô tả tổng quát khung cảnh. Tối đa 2 câu.",
"objects": ["đối tượng 1", "đối tượng 2"],
"colors": ["màu 1", "màu 2"],
"positions": "Vị trí tương đối của các vật thể.",
"warnings": ["cảnh báo 1", "cảnh báo 2"],
"confidence": 0.95,
"tang_1": "Thông tin định danh nhanh: tên tác phẩm, họa sĩ, niên đại, trường phái. Tối đa 2 câu.",
"tang_2": "Mô tả thị giác nghệ thuật: bố cục, màu sắc, nét cọ, cảm xúc, thông điệp hoặc bối cảnh văn hóa."
}

Lưu ý:
- warnings: Các yếu tố có thể gây nguy hiểm (ví dụ: xe cộ, lửa) nếu đây là ảnh đời thực, hoặc mảng màu chói gắt. Nếu không có gì nguy hiểm, trả về danh sách rỗng [].
- Nếu không nhận diện chắc chắn tên tranh (tang_1), vẫn mô tả những gì nhìn thấy và ghi rõ là chưa chắc chắn.
"""

async def analyze_with_gemini(image_bytes: bytes, mime_type: str = "image/jpeg") -> str:
    """
    Phân tích ảnh toàn bộ (không stream)
    """
    client = get_gemini_client()
    image_part = types.Part.from_bytes(
        mime_type=mime_type,
        data=image_bytes,
    )

    logger.info(f"Đang gửi ảnh đến Gemini ({len(image_bytes)} bytes)...")
    
    try:
        response = await asyncio.wait_for(
            client.aio.models.generate_content(
                model="gemini-2.5-flash",
                contents=[VISION_PROMPT, image_part]
            ),
            timeout=30.0,
        )
        logger.info("Gemini phản hồi thành công.")
        return response.text
    except asyncio.TimeoutError:
        logger.error("Gemini timeout sau 30 giây.")
        raise
    except Exception as e:
        logger.error(f"Lỗi khi gọi Gemini: {e}")
        raise

async def stream_gemini_analysis(image_bytes: bytes, mime_type: str = "image/jpeg") -> AsyncGenerator[str, None]:
    """
    Phân tích ảnh và stream kết quả trả về theo từng chunk
    Lưu ý: stream thường không đảm bảo cấu trúc JSON nguyên vẹn khi đang nhận.
    Tuy nhiên, frontend sẽ tự ghép lại và đọc dần.
    """
    client = get_gemini_client()
    image_part = types.Part.from_bytes(
        mime_type=mime_type,
        data=image_bytes,
    )
    
    logger.info("Bắt đầu stream ảnh đến Gemini...")
    
    try:
        # Dùng async generator để yield dữ liệu realtime
        async for chunk in await client.aio.models.generate_content_stream(
            model="gemini-2.5-flash",
            contents=[VISION_PROMPT, image_part]
        ):
            if chunk.text:
                yield chunk.text
    except Exception as e:
        logger.error(f"Lỗi khi stream Gemini: {e}")
        yield f"\n[Lỗi stream AI: {str(e)}]"
