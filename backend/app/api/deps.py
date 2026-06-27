from collections.abc import Generator
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionLocal
from app.models.user import User

security = HTTPBearer(auto_error=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _verify_supabase_token(token: str) -> dict:
    if not settings.supabase_url:
        raise HTTPException(status_code=500, detail="SUPABASE_URL is not configured")

    try:
        if settings.supabase_jwt_secret:
            return jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                audience=settings.supabase_jwt_audience,
                options={"verify_iss": False},
            )
        jwks_url = settings.supabase_jwks_url or f"{settings.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"
        jwk_client = PyJWKClient(jwks_url)
        signing_key = jwk_client.get_signing_key_from_jwt(token)
        return jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256", "RS256"],
            audience=settings.supabase_jwt_audience,
            options={"verify_iss": False},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        ) from exc


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authentication token")

    claims = _verify_supabase_token(credentials.credentials)
    auth_user_id = claims.get("sub")
    email = claims.get("email")
    if not auth_user_id or not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token is missing user identity")

    user = db.scalar(select(User).where(User.auth_user_id == UUID(auth_user_id)))
    metadata = claims.get("user_metadata") or {}
    name = metadata.get("full_name") or metadata.get("name") or claims.get("name")
    avatar_url = metadata.get("avatar_url") or claims.get("picture")

    if user is None:
        user = User(auth_user_id=UUID(auth_user_id), email=email, name=name, avatar_url=avatar_url)
        db.add(user)
    else:
        user.email = email
        user.name = name or user.name
        user.avatar_url = avatar_url or user.avatar_url

    db.commit()
    db.refresh(user)
    return user
