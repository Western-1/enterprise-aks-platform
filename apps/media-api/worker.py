import asyncio
import logging
import uuid

from sqlalchemy import select

from app.config import settings
from app.db import SessionLocal, engine
from app.models import Base, MediaItem
from app.redis_client import get_redis

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("media-worker")


async def process_job(item_id: uuid.UUID) -> None:
    async with SessionLocal() as session:
        item = await session.get(MediaItem, item_id)
        if item is None:
            log.warning("item %s not found, skipping", item_id)
            return
        item.view_count += 1
        await session.commit()
        log.info("item %s processed, views=%d", item_id, item.view_count)


async def main() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    redis_client = get_redis()
    await redis_client.ping()
    log.info("worker started, queue=%s", settings.worker_queue)

    while True:
        try:
            job = await redis_client.brpop(settings.worker_queue, timeout=5)
            if job is None:
                continue
            _, raw_id = job
            item_id = uuid.UUID(raw_id)
            await process_job(item_id)
        except Exception:
            log.exception("worker loop error")
            await asyncio.sleep(2)


if __name__ == "__main__":
    asyncio.run(main())