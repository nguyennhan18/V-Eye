from typing import Dict, Any, Optional
import time
from threading import Lock

class LRUCache:
    def __init__(self, capacity: int = 100, ttl_seconds: int = 3600):
        self.capacity = capacity
        self.ttl = ttl_seconds
        self.cache: Dict[str, Dict[str, Any]] = {}
        self.lock = Lock()

    def get(self, key: str) -> Optional[Any]:
        with self.lock:
            if key in self.cache:
                entry = self.cache[key]
                if time.time() - entry['timestamp'] > self.ttl:
                    del self.cache[key]
                    return None
                
                # Cập nhật thứ tự LRU (xóa và thêm lại vào cuối)
                val = self.cache.pop(key)
                self.cache[key] = val
                return val['data']
            return None

    def set(self, key: str, value: Any):
        with self.lock:
            if key in self.cache:
                del self.cache[key]
            elif len(self.cache) >= self.capacity:
                # Xóa phần tử đầu tiên (ít được sử dụng nhất gần đây)
                oldest_key = next(iter(self.cache))
                del self.cache[oldest_key]
                
            self.cache[key] = {
                'data': value,
                'timestamp': time.time()
            }

    def clear(self):
        with self.lock:
            self.cache.clear()

# Cache toàn cục cho ứng dụng
image_analysis_cache = LRUCache(capacity=50, ttl_seconds=3600)  # Lưu kết quả phân tích ảnh (1 giờ)
