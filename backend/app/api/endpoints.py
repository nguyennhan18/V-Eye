from fastapi import APIRouter, File, UploadFile
router = APIRouter()

@router.get("/health")
async def health():
    return {"status": "ok"}
@router.post("/analyze-art")
async def analyze_art(image: UploadFile = File(...)):
    image_bytes = await image.read()

    return {
        "filename": image.filename,
        "content_type": image.content_type,
        "size": len(image_bytes)
    }
