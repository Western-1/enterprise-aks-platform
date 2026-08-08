from urllib.parse import quote_plus

from azure.identity import DefaultAzureCredential
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from .config import settings

_scope = "https://ossrdbms-aad.database.windows.net/.default"


def _azure_token() -> str:
    credential = DefaultAzureCredential()
    return credential.get_token(_scope).token


if settings.db_host:
    token = quote_plus(_azure_token(), safe="")
    _url = (
        f"postgresql+asyncpg://{settings.db_user}:{token}@"
        f"{settings.db_host}:{settings.db_port}/{settings.db_name}"
    )
else:
    _url = settings.database_url
    if _url.startswith("postgresql://"):
        _url = _url.replace("postgresql://", "postgresql+asyncpg://", 1)

engine = create_async_engine(_url, echo=False, pool_pre_ping=True)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_session():
    async with SessionLocal() as session:
        yield session