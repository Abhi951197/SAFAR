from urllib.parse import urlsplit
from pathlib import Path
import sys

from sqlalchemy.engine import make_url

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings


def mask(value: str | None, visible: int = 4) -> str:
    if not value:
        return "<empty>"
    if len(value) <= visible:
        return "<set>"
    return f"{value[:visible]}...<length {len(value)}>"


def main() -> None:
    database = make_url(settings.database_url)
    checks = {
        "DATABASE_URL scheme": database.drivername,
        "DATABASE_URL username": database.username or "<missing>",
        "DATABASE_URL host": database.host or "<missing>",
        "DATABASE_URL port": str(database.port or "<missing>"),
        "DATABASE_URL database": database.database or "<missing>",
        "SUPABASE_URL": settings.supabase_url,
        "SUPABASE_PUBLISHABLE_KEY": mask(settings.supabase_publishable_key),
        "SUPABASE_SECRET_KEY": mask(settings.supabase_secret_key),
        "SUPABASE_JWKS_URL": settings.supabase_jwks_url or "<missing>",
        "CLOUDINARY_CLOUD_NAME": mask(settings.cloudinary_cloud_name),
    }
    for key, value in checks.items():
        print(f"{key}: {value}")

    if database.host and database.host.startswith("@"):
        print("ERROR: DATABASE_URL host starts with '@'. Remove extra @ characters before the host.")
    if database.drivername != "postgresql+psycopg":
        print("ERROR: DATABASE_URL should use postgresql+psycopg after normalization.")


if __name__ == "__main__":
    main()
