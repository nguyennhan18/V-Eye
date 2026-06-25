import sqlite3
import os
import threading
from typing import List, Dict, Any
from app.core.config import settings

db_path = settings.DATASET_DIR / "database.db"

# Khởi tạo bảng nếu chưa có
def init_db():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS analysis_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            image_filename TEXT,
            description TEXT,
            audio_url TEXT,
            processing_time_ms INTEGER,
            provider TEXT
        )
    ''')
    conn.commit()
    conn.close()

# Lock để chống đụng độ khi ghi log (vì SQLite không hỗ trợ ghi đồng thời tốt)
db_lock = threading.Lock()

def add_log(image_filename: str, description: str, audio_url: str, processing_time_ms: int, provider: str):
    with db_lock:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO analysis_logs 
            (image_filename, description, audio_url, processing_time_ms, provider)
            VALUES (?, ?, ?, ?, ?)
        ''', (image_filename, description, audio_url, processing_time_ms, provider))
        conn.commit()
        conn.close()

def get_stats() -> Dict[str, Any]:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute('SELECT COUNT(*) FROM analysis_logs')
    total_images = cursor.fetchone()[0]
    
    cursor.execute('SELECT AVG(processing_time_ms) FROM analysis_logs')
    avg_time = cursor.fetchone()[0]
    avg_time = int(avg_time) if avg_time else 0
    
    conn.close()
    return {
        "total_images": total_images,
        "avg_processing_time_ms": avg_time
    }

def get_latest_logs(limit: int = 50) -> List[Dict[str, Any]]:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT * FROM analysis_logs 
        ORDER BY id DESC 
        LIMIT ?
    ''', (limit,))
    
    rows = cursor.fetchall()
    conn.close()
    
    return [dict(row) for row in rows]

# Tự động tạo bảng khi import
init_db()
