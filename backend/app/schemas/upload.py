from pydantic import BaseModel


class ImageUploadRead(BaseModel):
    image_url: str
    image_public_id: str


class MediaUploadRead(BaseModel):
    url: str
    public_id: str
    media_type: str


class EncryptedMediaUploadRead(MediaUploadRead):
    encrypted: bool = True
    content_type: str | None = None
    size_bytes: int
