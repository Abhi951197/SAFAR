from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import ai, auth, entries, health, upload
from app.core.config import settings


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name)
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
    return app


app = create_app()
