import hashlib
import json
import logging
from fastapi import UploadFile, HTTPException

logger = logging.getLogger(__name__)

ALLOWED_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB

async def validate_image(image: UploadFile) -> bytes:
    """
    Validate định dạng và kích thước của ảnh upload.
    Trả về bytes của ảnh nếu hợp lệ.
    """
    if image.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=400, detail=f"Định dạng không hỗ trợ. Chấp nhận: {ALLOWED_MIME_TYPES}")
    
    image_bytes = await image.read()
    
    if len(image_bytes) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="Kích thước file vượt quá 10MB.")
        
    return image_bytes

def hash_image(image_bytes: bytes) -> str:
    """
    Tạo mã băm MD5 cho ảnh để dùng làm cache key.
    """
    return hashlib.md5(image_bytes).hexdigest()

def parse_ai_json(text: str) -> dict:
    """
    Trích xuất JSON hợp lệ từ chuỗi text trả về của AI.
    
    Xử lý các trường hợp AI trả về markdown fences (```json ... ```)
    hoặc văn bản thừa bao quanh JSON.
    """
    cleaned_text = text.strip()

    if cleaned_text.startswith("```json"):
        cleaned_text = cleaned_text.removeprefix("```json").strip()
    elif cleaned_text.startswith("```"):
        cleaned_text = cleaned_text.removeprefix("```").strip()
    
    if cleaned_text.endswith("```"):
        cleaned_text = cleaned_text.removesuffix("```").strip()

    start_index = cleaned_text.find("{")
    end_index = cleaned_text.rfind("}")

    if start_index == -1 or end_index == -1:
        logger.warning("Không tìm thấy JSON hợp lệ trong phản hồi AI. Trả về text thô.")
        return {
            "tang_1": cleaned_text[:100],  # Lấy 100 ký tự đầu làm định danh tạm
            "tang_2": cleaned_text
        }

    json_text = cleaned_text[start_index:end_index + 1]
    
    try:
        parsed = json.loads(json_text)
        return parsed
    except json.JSONDecodeError as e:
        logger.error(f"Lỗi parse JSON: {e}")
        return {
            "tang_1": "Lỗi parse dữ liệu",
            "tang_2": cleaned_text
        }
