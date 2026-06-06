import asyncio
import logging
import uuid
import os
from fastapi import APIRouter, File, UploadFile, HTTPException, Request
from sse_starlette.sse import EventSourceResponse
from app.models.schemas import ArtAnalysisResponse, AudioGenerationRequest, AudioGenerationResponse
from app.utils.helpers import validate_image, hash_image
from app.utils.cache import image_analysis_cache
from app.services.vision_service import analyze_image_with_fallback, stream_analysis_with_fallback
from app.services.tts_service import generate_audio
from app.core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

@router.get("/health")
async def health():
    """Kiểm tra sức khỏe cơ bản của API."""
    return {"status": "ok"}

@router.get("/status")
async def status():
    """Trạng thái chi tiết của các dịch vụ."""
    return {
        "status": "ok",
        "gemini_configured": bool(settings.GEMINI_API_KEY),
        "openai_configured": bool(settings.OPENAI_API_KEY),
        "cache_size": len(image_analysis_cache.cache)
    }

@router.post("/describe-image", response_model=ArtAnalysisResponse)
async def describe_image(image: UploadFile = File(...)):
    """
    Phân tích ảnh toàn bộ (chờ kết quả đầy đủ).
    Có validate, hash và cache.
    """
    logger.info(f"Nhận ảnh: {image.filename} ({image.content_type})")
    
    try:
        # Validate file
        image_bytes = await validate_image(image)
        
        # Check cache
        img_hash = hash_image(image_bytes)
        cached_result = image_analysis_cache.get(img_hash)
        if cached_result:
            logger.info("Cache hit! Trả về kết quả từ cache.")
            return cached_result
            
        # Phân tích
        result = await analyze_image_with_fallback(image_bytes, image.content_type)
        
        # Lưu cache
        image_analysis_cache.set(img_hash, result)
        
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Lỗi describe-image: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream-description")
async def stream_description(request: Request, image: UploadFile = File(...)):
    """
    Phân tích ảnh dạng Server-Sent Events (SSE) để tối ưu tốc độ phản hồi.
    """
    try:
        image_bytes = await validate_image(image)
        
        async def event_generator():
            try:
                # Gọi service stream
                async for chunk in stream_analysis_with_fallback(image_bytes, image.content_type):
                    # Nếu client disconnect giữa chừng thì dừng
                    if await request.is_disconnected():
                        logger.info("Client ngắt kết nối khi đang stream.")
                        break
                        
                    # Yield data dưới dạng SSE
                    yield {
                        "event": "chunk",
                        "data": chunk
                    }
                    # Nhường control cho event loop
                    await asyncio.sleep(0.01)
                    
                yield {
                    "event": "complete",
                    "data": "done"
                }
            except Exception as stream_err:
                logger.error(f"Lỗi trong event_generator: {stream_err}")
                yield {
                    "event": "error",
                    "data": str(stream_err)
                }

        return EventSourceResponse(event_generator())
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Lỗi khởi tạo stream: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/generate-audio", response_model=AudioGenerationResponse)
async def generate_audio_endpoint(request: AudioGenerationRequest):
    """
    Tạo file audio từ văn bản (TTS).
    """
    try:
        file_path, provider = await generate_audio(request.text)
        filename = os.path.basename(file_path)
        
        # Trả về URL đường dẫn tương đối để frontend có thể tải (cần serve static files)
        audio_url = f"/audio/{filename}"
        
        return AudioGenerationResponse(
            audio_url=audio_url,
            provider=provider
        )
    except Exception as e:
        logger.error(f"Lỗi generate-audio: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Backward compatibility với Flutter cũ
@router.post("/analyze-art")
async def analyze_art_legacy(image: UploadFile = File(...)):
    """Endpoint tương thích ngược."""
    logger.info("Gọi endpoint cũ /analyze-art")
    # Tái sử dụng logic describe_image
    result = await describe_image(image)
    return result.model_dump()
