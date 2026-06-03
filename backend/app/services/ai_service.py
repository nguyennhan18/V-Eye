from google import genai
from google.genai import types
from app.core.config import GEMINI_API_KEY, OPENAI_API_KEY


client = genai.Client(api_key=GEMINI_API_KEY)
async def analyze_art_with_gemini(image_bytes: bytes, content_type: str | None) -> str:
    model_name = "gemini-2.5-flash"

    prompt = """
            Bạn là trợ lý mô tả tranh nghệ thuật dành cho người khiếm thị.
            Hãy nhận diện nhanh bức tranh trong ảnh.

            Trả lời ngắn gọn bằng tiếng Việt, tối đa 2 câu.
            Bao gồm nếu có thể:
            - Tên tác phẩm
            - Họa sĩ
            - Trường phái
            - Bối cảnh ngắn
            """
    image_part = types.Part.from_bytes(
        mime_type =  content_type or "image/jpeg",
        data = image_bytes,
    )

    response = await client.aio.models.generate_content(
        model = model_name,
        contents = [prompt, image_part]
    )
    return response.text
