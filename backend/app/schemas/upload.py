from pydantic import BaseModel


class ImageUploadRead(BaseModel):
    image_url: str
    image_public_id: str


class MediaUploadRead(BaseModel):
    url: str
    public_id: str
    media_type: str
