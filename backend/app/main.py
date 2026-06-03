from fastapi import FastAPI
from .api.endpoints import router
app = FastAPI(title="V-Art backend")

app.include_router(router, prefix="/api")

@app.get("/")
async def root():
    return {"message": "Welcome to V-Art backend!"}