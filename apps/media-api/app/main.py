from contextlib import asynccontextmanager

from fastapi import FastAPI

from sqlalchemy import text

from .db import engine
from .models import Base
from .redis_client import get_redis
from .routers import items


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    redis_client = get_redis()
    await redis_client.ping()
    yield
    await engine.dispose()


app = FastAPI(title="media-api", version="1.0.0", lifespan=lifespan)

app.include_router(items.router)


@app.get("/healthz", tags=["health"])
async def healthz():
    db_ok = True
    redis_ok = True
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    try:
        await get_redis().ping()
    except Exception:
        redis_ok = False

    status_code = 200 if db_ok and redis_ok else 503
    return {"status": "ok" if status_code == 200 else "degraded", "db": db_ok, "redis": redis_ok, "http": 200}