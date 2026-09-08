from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

import pytest

from app.db import engine
from app.main import app


@pytest.mark.asyncio
async def test_healthz():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/healthz")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["db"] is True
    assert body["redis"] is True


@pytest.mark.asyncio
async def test_create_and_list():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        created = await client.post(
            "/media/items", json={"title": "Test item", "description": "hello"}
        )
        assert created.status_code == 201
        item = created.json()
        assert item["title"] == "Test item"

        listed = await client.get("/media/items")
        assert listed.status_code == 200
        ids = [i["id"] for i in listed.json()]
        assert item["id"] in ids


@pytest.mark.asyncio
async def test_get_missing_item():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/media/items/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404