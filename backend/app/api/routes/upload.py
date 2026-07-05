import cloudinary
import cloudinary.uploader
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.api.deps import get_current_user
from app.core.config import settings
from app.models.user import User
from app.schemas.upload import EncryptedMediaUploadRead, ImageUploadRead, MediaUploadRead

router = APIRouter()

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/webm"}
ALLOWED_AUDIO_TYPES = {"audio/mpeg", "audio/mp4", "audio/aac", "audio/wav", "audio/webm", "audio/ogg"}

@router.post("/image", response_model=ImageUploadRead)
async def upload_image(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> ImageUploadRead:
    if image.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only JPG, PNG, and WEBP images are allowed")

    data = await image.read()
    cloudinary.config(
        cloud_name=settings.cloudinary_cloud_name,
        api_key=settings.cloudinary_api_key,
        api_secret=settings.cloudinary_api_secret,
        secure=True,
    )
    result = cloudinary.uploader.upload(
        data,
        folder=f"{settings.cloudinary_upload_folder}/{current_user.id}",
        resource_type="image",
    )
    return ImageUploadRead(image_url=result["secure_url"], image_public_id=result["public_id"])


@router.post("/encrypted", response_model=EncryptedMediaUploadRead)
async def upload_encrypted_media(
    file: UploadFile = File(...),
    media_type: Literal["image", "video", "audio"] = Form(...),
    content_type: str | None = Form(default=None),
    current_user: User = Depends(get_current_user),
) -> EncryptedMediaUploadRead:
    data = await file.read()
    cloudinary.config(
        cloud_name=settings.cloudinary_cloud_name,
        api_key=settings.cloudinary_api_key,
        api_secret=settings.cloudinary_api_secret,
        secure=True,
    )
    result = cloudinary.uploader.upload(
        data,
        folder=f"{settings.cloudinary_upload_folder}/{current_user.id}/encrypted/{media_type}",
        resource_type="raw",
    )
    return EncryptedMediaUploadRead(
        url=result["secure_url"],
        public_id=result["public_id"],
        media_type=media_type,
        content_type=content_type,
        size_bytes=len(data),
    )


@router.post("/video", response_model=MediaUploadRead)
async def upload_video(
    video: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> MediaUploadRead:
    return await _upload_media(video, "video", current_user)


@router.post("/audio", response_model=MediaUploadRead)
async def upload_audio(
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> MediaUploadRead:
    return await _upload_media(audio, "audio", current_user)


async def _upload_media(file: UploadFile, media_type: str, current_user: User) -> MediaUploadRead:
    allowed_types = ALLOWED_VIDEO_TYPES if media_type == "video" else ALLOWED_AUDIO_TYPES
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported {media_type} file type")

    data = await file.read()
    cloudinary.config(
        cloud_name=settings.cloudinary_cloud_name,
        api_key=settings.cloudinary_api_key,
        api_secret=settings.cloudinary_api_secret,
        secure=True,
    )
    result = cloudinary.uploader.upload(
        data,
        folder=f"{settings.cloudinary_upload_folder}/{current_user.id}/{media_type}",
        resource_type="video",
    )
    return MediaUploadRead(url=result["secure_url"], public_id=result["public_id"], media_type=media_type)
