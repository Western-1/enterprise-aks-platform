import asyncio
import sys
from pathlib import Path
from urllib.parse import quote_plus

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from app.config import settings

_scope = "https://ossrdbms-aad.database.windows.net/.default"


async def main() -> int:
    if not settings.db_host:
        print("DB_HOST is not set, nothing to bootstrap", flush=True)
        return 0

    from azure.identity import DefaultAzureCredential

    credential = DefaultAzureCredential()
    token = quote_plus(credential.get_token(_scope).token, safe="")

    admin_url = (
        f"postgresql+asyncpg://{settings.db_user}:{token}@"
        f"{settings.db_host}:{settings.db_port}/postgres?ssl=require"
    )
    engine = create_async_engine(admin_url, echo=False)
    try:
        async with engine.connect() as conn:
            await conn.execution_options(isolation_level="AUTOCOMMIT")
            exists = await conn.scalar(
                text("SELECT 1 FROM pg_database WHERE datname = :name"), {"name": settings.db_name}
            )
            if exists:
                print(f"database '{settings.db_name}' already exists", flush=True)
                return 0
            await conn.execute(text(f'CREATE DATABASE "{settings.db_name}"'))
            print(f"database '{settings.db_name}' created", flush=True)
            return 0
    finally:
        await engine.dispose()


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))