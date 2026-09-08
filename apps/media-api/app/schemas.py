import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class MediaItemCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = ""


class MediaItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str
    view_count: int
    created_at: datetime
    updated_at: datetime