from pydantic import BaseModel, Field
from typing import List, Optional

class ArtAnalysisResponse(BaseModel):
    """
    Response schema cho kết quả phân tích ảnh trả về frontend
    """
    description: str = Field(description="Mô tả bức ảnh do AI sinh ra", default="")
    provider: str = Field(description="Dịch vụ AI được sử dụng (gemini hoặc openai)", default="gemini")
    audio_url: Optional[str] = Field(description="Đường dẫn đến file audio được generate tự động", default=None)
    
    @property
    def full_description(self) -> str:
        return self.description


class AudioGenerationRequest(BaseModel):
    text: str = Field(..., description="Văn bản cần chuyển thành giọng nói")
    
class AudioGenerationResponse(BaseModel):
    audio_url: str = Field(..., description="URL để tải/nghe file audio")
    provider: str = Field(..., description="Dịch vụ TTS (openai hoặc gtts)")
