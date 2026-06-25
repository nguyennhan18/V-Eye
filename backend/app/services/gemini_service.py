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

VISION_PROMPT = """
Bạn đang mô tả hình ảnh cho một người khiếm thị hoàn toàn, người không có khái niệm thị giác trước đó hoặc đã mất thị lực. Mục tiêu là giúp họ dựng lại hình ảnh trong tâm trí một cách chính xác và hữu ích, KHÔNG phải để "cảm nhận nghệ thuật" mà để HIỂU và AN TOÀN khi cần.

Hãy mô tả theo cấu trúc sau:
1. Câu mở đầu ngắn: nêu loại ảnh và nội dung chính trong 1 câu.
2. Bố cục không gian: mô tả từ tổng quan đến chi tiết, theo thứ tự gần → xa hoặc trái → phải, nêu rõ vị trí, khoảng cách tương đối của các vật thể.
3. Chi tiết quan trọng cho an toàn/tương tác: vật cản, bậc thang, biển báo, người, phương tiện — ưu tiên nêu trước nếu liên quan đến di chuyển.
4. Màu sắc & ánh sáng: chỉ gọi tên rõ ràng khi có ý nghĩa thông tin (đèn đỏ, biển báo).
5. Văn bản trong ảnh: đọc nguyên văn nếu có.

Nguyên tắc viết QUAN TRỌNG:
- CHỈ MÔ TẢ NHỮNG GÌ CÓ TRONG ẢNH. Tuyệt đối KHÔNG nhắc đến những thứ không tồn tại.
- Ví dụ: Nếu ảnh không có chữ, KHÔNG ĐƯỢC nói "Trong ảnh không có văn bản". Nếu ảnh an toàn, KHÔNG ĐƯỢC nói "Không có vật cản nguy hiểm". Cứ việc bỏ qua và không nhắc tới.
- Câu ngắn, rõ, không dùng ẩn dụ thị giác mơ hồ.
- Ưu tiên thông tin hữu ích cho ra quyết định/di chuyển.
- Độ dài: 2-4 câu cho mô tả nhanh.

BẮT BUỘC trả về bằng định dạng JSON hợp lệ:
{
    "description": "Câu mô tả theo cấu trúc trên..."
}
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
    
    # Dùng async generator để yield dữ liệu realtime
    async for chunk in await client.aio.models.generate_content_stream(
        model="gemini-2.5-flash",
        contents=[VISION_PROMPT, image_part]
    ):
        if chunk.text:
            yield chunk.text

async def stream_gemini_chat(image_bytes: bytes, mime_type: str, question: str) -> AsyncGenerator[str, None]:
    """
    Hỏi thêm chi tiết về bức ảnh (Follow-up Chat).
    """
    client = get_gemini_client()
    image_part = types.Part.from_bytes(
        mime_type=mime_type,
        data=image_bytes,
    )
    
    chat_prompt = f"""
    Bạn là một trợ lý thông minh cho người khiếm thị. Bạn đang xem bức ảnh này.
    Người dùng hỏi: "{question}"
    Hãy trả lời thật ngắn gọn, dễ hiểu, trực tiếp vào câu hỏi, bằng tiếng Việt.
    Không dùng markdown định dạng phức tạp.
    """
    
    logger.info(f"Bắt đầu stream chat Gemini: {question}")
    
    try:
        async for chunk in await client.aio.models.generate_content_stream(
            model="gemini-2.5-flash",
            contents=[image_part, chat_prompt]
        ):
            if chunk.text:
                yield chunk.text
    except Exception as e:
        logger.error(f"Lỗi khi stream chat Gemini: {e}")
        yield f"\n[Lỗi AI: {str(e)}]"
