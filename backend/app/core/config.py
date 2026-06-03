import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[2] # thay duong dan toi thu muc backend (file nam o backend/app/core/config.py)
load_dotenv(BASE_DIR / '.env')

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')