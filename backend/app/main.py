import asyncio
import logging
from contextlib import asynccontextmanager
from contextlib import suppress

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import ai, auth, backup, entries, health, upload
from app.core.config import settings
from app.db.session import SessionLocal
from app.models.user import User
from app.services.backups import backup_worker, queue_snapshot
from app.services.recovery import decode_archive, restore_archive
from sqlalchemy import select


@asynccontextmanager
async def lifespan(app: FastAPI):
    with SessionLocal() as db:
        if settings.safar_recovery_archive_b64:
            try:
                inserted = restore_archive(db, decode_archive(settings.safar_recovery_archive_b64))
                db.commit()
            except Exception:
                db.rollback()
                # Validation exceptions can contain input diary text: never log them.
                raise RuntimeError("Diary recovery failed; transaction rolled back") from None
            logging.getLogger(__name__).warning("Diary recovery verified: inserted=%d", inserted)
        if settings.safar_backup_enabled:
            for user in db.scalars(select(User)).all():
                queue_snapshot(db, user)
            db.commit()
    stop = asyncio.Event()
    worker = asyncio.create_task(backup_worker(stop)) if settings.safar_backup_enabled else None
    try:
        yield
    finally:
        stop.set()
        if worker is not None:
            try:
                await asyncio.wait_for(worker, timeout=5)
            except TimeoutError:
                worker.cancel()
                with suppress(asyncio.CancelledError):
                    await worker


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.api_cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(health.router)
    app.include_router(auth.router, prefix="/auth", tags=["auth"])
    app.include_router(ai.router, prefix="/ai", tags=["ai"])
    app.include_router(entries.router, prefix="/entries", tags=["entries"])
    app.include_router(upload.router, prefix="/upload", tags=["upload"])
    app.include_router(backup.router, prefix="/backup", tags=["backup"])
    return app


app = create_app()
