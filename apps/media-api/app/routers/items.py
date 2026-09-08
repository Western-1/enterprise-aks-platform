import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..models import MediaItem
from ..redis_client import get_redis
from ..schemas import MediaItemCreate, MediaItemRead

router = APIRouter(prefix="/media/items", tags=["items"])


@router.get("", response_model=list[MediaItemRead])
async def list_items(session: AsyncSession = Depends(get_session)):
    result = await session.scalars(select(MediaItem).order_by(MediaItem.created_at.desc()))
    return result.all()


@router.post("", response_model=MediaItemRead, status_code=status.HTTP_201_CREATED)
async def create_item(payload: MediaItemCreate, session: AsyncSession = Depends(get_session)):
    item = MediaItem(title=payload.title, description=payload.description)
    session.add(item)
    await session.commit()
    await session.refresh(item)

    redis_client = get_redis()
    await redis_client.lpush("media:process", str(item.id))
    return item


@router.get("/{item_id}", response_model=MediaItemRead)
async def get_item(item_id: uuid.UUID, session: AsyncSession = Depends(get_session)):
    item = await session.get(MediaItem, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item