from pydantic import BaseModel, Field
from typing import List, Optional

class ArtAnalysisResponse(BaseModel):
    """
    Response schema cho kết quả phân tích ảnh trả về frontend
    """
    scene: str = Field(description="Mô tả tổng quát khung cảnh", default="")
    objects: List[str] = Field(description="Danh sách các đối tượng nhận diện được", default_factory=list)
    colors: List[str] = Field(description="Màu sắc chủ đạo", default_factory=list)
    positions: str = Field(description="Vị trí tương đối của các vật thể", default="")
    warnings: List[str] = Field(description="Các cảnh báo nguy hiểm nếu có (vd: cầu thang, xe cộ)", default_factory=list)
    confidence: float = Field(description="Độ tin cậy của phân tích (0.0 - 1.0)", default=0.0)
    
    tang_1: str = Field(description="Thông tin định danh nhanh", default="")
    tang_2: str = Field(description="Mô tả thị giác nghệ thuật chi tiết", default="")
    
    provider: str = Field(description="Dịch vụ AI được sử dụng (gemini hoặc openai)", default="gemini")
    
    @property
    def full_description(self) -> str:
        parts = []
        if self.tang_1:
            parts.append(self.tang_1)
        if self.tang_2:
            parts.append(self.tang_2)
        if self.warnings:
            parts.append("Cảnh báo: " + ", ".join(self.warnings))
        return ". ".join(parts)

class AudioGenerationRequest(BaseModel):
    text: str = Field(..., description="Văn bản cần chuyển thành giọng nói")
    
class AudioGenerationResponse(BaseModel):
    audio_url: str = Field(..., description="URL để tải/nghe file audio")
    provider: str = Field(..., description="Dịch vụ TTS (openai hoặc gtts)")
