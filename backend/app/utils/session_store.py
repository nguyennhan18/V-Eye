import time
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

class SessionStore:
    def __init__(self):
        # { session_id: { "image_bytes": bytes, "mime_type": str, "last_accessed": float } }
        self.sessions: Dict[str, Dict[str, Any]] = {}

    def set_session(self, session_id: str, image_bytes: bytes, mime_type: str):
        self.sessions[session_id] = {
            "image_bytes": image_bytes,
            "mime_type": mime_type,
            "last_accessed": time.time()
        }
        self.cleanup_old_sessions()
        logger.info(f"Đã lưu session: {session_id}. Tổng số session: {len(self.sessions)}")

    def get_session(self, session_id: str) -> Dict[str, Any]:
        session = self.sessions.get(session_id)
        if session:
            session["last_accessed"] = time.time()
            return session
        return None

    def cleanup_old_sessions(self, max_age_seconds: int = 3600):
        current_time = time.time()
        keys_to_delete = [
            k for k, v in self.sessions.items() 
            if current_time - v["last_accessed"] > max_age_seconds
        ]
        for k in keys_to_delete:
            del self.sessions[k]

# Singleton
session_store = SessionStore()
