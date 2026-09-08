import pytest
import pytest_asyncio

import app.main as main_module
import app.routers.items as items_module
from app.db import engine
from app.models import Base


class FakeRedis:
    def __init__(self):
        self.lists = {}

    async def ping(self):
        return True

    async def lpush(self, key, value):
        self.lists.setdefault(key, []).insert(0, value)
        return len(self.lists[key])


@pytest_asyncio.fixture(autouse=True)
async def _db_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


@pytest.fixture(autouse=True)
def _fake_redis(monkeypatch):
    fake = FakeRedis()
    monkeypatch.setattr(main_module, "get_redis", lambda: fake)
    monkeypatch.setattr(items_module, "get_redis", lambda: fake)
    return fake