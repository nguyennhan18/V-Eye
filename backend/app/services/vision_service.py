import logging
from typing import AsyncGenerator
from app.models.schemas import ArtAnalysisResponse
from app.utils.helpers import parse_ai_json
from .gemini_service import analyze_with_gemini, stream_gemini_analysis
from .openai_service import analyze_with_openai, stream_openai_analysis

logger = logging.getLogger(__name__)

async def analyze_image_with_fallback(image_bytes: bytes, mime_type: str = "image/jpeg") -> ArtAnalysisResponse:
    """
    Phân tích ảnh với Gemini, nếu lỗi thì fallback sang GPT-4o.
    Trả về response chuẩn Pydantic.
    """
    try:
        raw_result = await analyze_with_gemini(image_bytes, mime_type)
        parsed = parse_ai_json(raw_result)
        parsed["provider"] = "gemini"
        return ArtAnalysisResponse(**parsed)
    except Exception as gemini_err:
        logger.warning(f"Gemini lỗi ({gemini_err}). Đang fallback sang OpenAI...")
        
        try:
            raw_result = await analyze_with_openai(image_bytes, mime_type)
            parsed = parse_ai_json(raw_result)
            parsed["provider"] = "openai"
            return ArtAnalysisResponse(**parsed)
        except Exception as openai_err:
            logger.error(f"Cả Gemini và OpenAI đều lỗi: {openai_err}")
            raise RuntimeError(f"Không thể phân tích ảnh: {openai_err}")

async def stream_analysis_with_fallback(image_bytes: bytes, mime_type: str = "image/jpeg") -> AsyncGenerator[str, None]:
    """
    Stream phân tích ảnh với Gemini, nếu lỗi thì fallback stream sang GPT-4o.
    """
    try:
        # Check xem có thể khởi tạo client không trước khi bắt đầu stream
        from .gemini_service import get_gemini_client
        get_gemini_client()
        
        logger.info("Sử dụng Gemini cho streaming...")
        async for chunk in stream_gemini_analysis(image_bytes, mime_type):
            yield chunk
            
    except Exception as gemini_err:
        logger.warning(f"Gemini stream lỗi ({gemini_err}). Fallback sang OpenAI streaming...")
        
        try:
            async for chunk in stream_openai_analysis(image_bytes, mime_type):
                yield chunk
        except Exception as openai_err:
            logger.error(f"Cả Gemini và OpenAI stream đều lỗi: {openai_err}")
            yield f"\n[Lỗi hệ thống: Không thể xử lý yêu cầu]"
