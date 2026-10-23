from pydantic import Field
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Safar API"
    environment: str = "local"
    api_cors_origins: list[str] = Field(default_factory=lambda: ["*"])

    database_url: str

    @field_validator("database_url")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        if value.startswith("postgres://"):
            return value.replace("postgres://", "postgresql+psycopg://", 1)
        if value.startswith("postgresql://"):
            return value.replace("postgresql://", "postgresql+psycopg://", 1)
        return value

    supabase_url: str
    supabase_publishable_key: str | None = None
    supabase_secret_key: str | None = None
    supabase_jwks_url: str | None = None
    supabase_jwt_audience: str = "authenticated"
    supabase_jwt_secret: str | None = None

    cloudinary_cloud_name: str
    cloudinary_api_key: str
    cloudinary_api_secret: str
    cloudinary_upload_folder: str = "safar"

    gemini_api_key: str | None = None
    gemini_text_model: str = "gemini-flash-latest"
    groq_api_key: str | None = None
    groq_text_model: str = "llama-3.1-8b-instant"

    safar_backup_enabled: bool = False
    safar_backup_url: str | None = None
    safar_backup_key: str | None = None
    safar_backup_bucket: str = "safar-diary-backups"
    safar_backup_interval_seconds: int = Field(default=60, ge=10)
    # One-time recovery data. Never put diary content in source control.
    safar_recovery_archive_b64: str | None = None


settings = Settings()
