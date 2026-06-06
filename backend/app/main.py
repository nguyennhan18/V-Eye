import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from app.api.routes import router
from app.core.config import settings

# Cấu hình logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(settings.LOG_DIR / "app.log")
    ]
)
logger = logging.getLogger(__name__)

# Cấu hình Rate Limiting
limiter = Limiter(key_func=get_remote_address)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("V-Eye Backend đang khởi động...")
    if not settings.GEMINI_API_KEY and not settings.OPENAI_API_KEY:
        logger.warning("CẢNH BÁO: Không có API key nào được cấu hình!")
    yield
    # Shutdown
    logger.info("V-Eye Backend đang tắt...")

app = FastAPI(
    title="V-Eye Backend",
    description="API phân tích hình ảnh hỗ trợ người khiếm thị",
    version="2.0.0",
    lifespan=lifespan
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Phục vụ file audio tĩnh
app.mount("/audio", StaticFiles(directory=str(settings.AUDIO_DIR)), name="audio")

app.include_router(router, prefix="/api")

@app.get("/")
@limiter.limit("10/minute")
async def root(request: Request):
    return {
        "message": "Chào mừng đến V-Eye Backend v2.0!", 
        "status": "ok",
        "docs": "/docs"
    }