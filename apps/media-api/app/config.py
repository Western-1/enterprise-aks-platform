from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite+aiosqlite:///./media.db"
    redis_url: str = "redis://localhost:6379/0"
    worker_queue: str = "media:process"
    app_name: str = "media-api"

    db_host: str = ""
    db_user: str = ""
    db_name: str = "media"
    db_port: int = 5432


settings = Settings()