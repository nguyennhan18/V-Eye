from fastapi import APIRouter, File, UploadFile, HTTPException
from app.services.ai_service import analyze_art_with_gemini

router = APIRouter()

@router.get("/health")
async def health():
    return {"status": "ok"}

@router.post("/analyze-art")
async def analyze_art(image: UploadFile = File(...)):
    try:
        images_bytes = await image.read()
        result = await analyze_art_with_gemini(images_bytes, image.content_type)

        return{
            "result" : result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
