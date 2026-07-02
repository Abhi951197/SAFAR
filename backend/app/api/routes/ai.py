import json
import re
import urllib.error
import urllib.request

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_user
from app.core.config import settings
from app.models.user import User
from app.schemas.ai import (
    AiEnhanceRead,
    AiSummaryRead,
    AiTextRequest,
    AiTitleSuggestionsRead,
)

router = APIRouter()


def _call_ai(instructions: str, text: str, max_output_tokens: int = 500) -> str:
    errors: list[tuple[str, HTTPException]] = []
    try:
        return _call_gemini(instructions, text, max_output_tokens)
    except HTTPException as error:
        errors.append(("Gemini", error))
        if error.status_code != status.HTTP_429_TOO_MANY_REQUESTS:
            raise

    try:
        return _call_groq(instructions, text, max_output_tokens)
    except HTTPException as error:
        errors.append(("Groq", error))
        if error.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            detail = "; ".join(
                f"{provider} rate limited: {err.detail}"
                for provider, err in errors
                if err.status_code == status.HTTP_429_TOO_MANY_REQUESTS
            )
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=detail or "Gemini and Groq are rate limited.",
            ) from error
        raise


def _call_gemini(instructions: str, text: str, max_output_tokens: int) -> str:
    if not settings.gemini_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Gemini AI writing is not configured.",
        )

    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{settings.gemini_text_model}:generateContent"
    )
    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": (
                            f"{instructions}\n\nDiary text:\n{text.strip()}"
                        )
                    }
                ]
            }
        ],
        "generationConfig": {
            "maxOutputTokens": max(max_output_tokens, 512),
            "temperature": 0.6,
            "thinkingConfig": {"thinkingBudget": 0},
        },
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-goog-api-key": settings.gemini_api_key,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = "Gemini AI writing is temporarily unavailable."
        try:
            error_body = json.loads(error.read().decode("utf-8"))
            detail = error_body.get("error", {}).get("message", detail)
        except (json.JSONDecodeError, UnicodeDecodeError):
            pass
        response_status = (
            status.HTTP_429_TOO_MANY_REQUESTS
            if error.code == status.HTTP_429_TOO_MANY_REQUESTS
            else status.HTTP_502_BAD_GATEWAY
        )
        raise HTTPException(
            status_code=response_status,
            detail=f"Gemini: {detail}",
        ) from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Gemini AI writing is temporarily unavailable.",
        ) from error

    try:
        candidate = data["candidates"][0]
        parts = candidate.get("content", {}).get("parts", [])
        output = "\n".join(
            part.get("text", "") for part in parts if part.get("text")
        ).strip()
        finish_reason = candidate.get("finishReason")
    except (KeyError, IndexError, TypeError, AttributeError) as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Gemini AI writing returned an unexpected response.",
        ) from error
    if finish_reason == "MAX_TOKENS":
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Gemini stopped early before finishing the AI response. Please try again.",
        )
    if not output:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI writing returned an empty response.",
        )
    return output


def _call_groq(instructions: str, text: str, max_output_tokens: int) -> str:
    if not settings.groq_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Groq AI writing is not configured.",
        )

    payload = {
        "model": settings.groq_text_model,
        "messages": [
            {
                "role": "system",
                "content": instructions,
            },
            {
                "role": "user",
                "content": f"Diary text:\n{text.strip()}",
            },
        ],
        "temperature": 0.6,
        "max_tokens": max(max_output_tokens, 512),
    }
    request = urllib.request.Request(
        "https://api.groq.com/openai/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {settings.groq_api_key}",
            "User-Agent": "Safar/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = "Groq AI writing is temporarily unavailable."
        try:
            error_body = json.loads(error.read().decode("utf-8"))
            detail = error_body.get("error", {}).get("message", detail)
        except (json.JSONDecodeError, UnicodeDecodeError):
            pass
        response_status = (
            status.HTTP_429_TOO_MANY_REQUESTS
            if error.code == status.HTTP_429_TOO_MANY_REQUESTS
            else status.HTTP_502_BAD_GATEWAY
        )
        raise HTTPException(
            status_code=response_status,
            detail=f"Groq: {detail}",
        ) from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Groq AI writing is temporarily unavailable.",
        ) from error

    try:
        output = data["choices"][0]["message"]["content"].strip()
        finish_reason = data["choices"][0].get("finish_reason")
    except (KeyError, IndexError, TypeError, AttributeError) as error:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Groq AI writing returned an unexpected response.",
        ) from error
    if finish_reason == "length":
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Groq stopped early before finishing the AI response. Please try again.",
        )
    if not output:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Groq AI writing returned an empty response.",
        )
    return output


@router.post("/summarize", response_model=AiSummaryRead)
def summarize(
    payload: AiTextRequest,
    _current_user: User = Depends(get_current_user),
) -> AiSummaryRead:
    summary = _call_ai(
        "Summarize this diary entry in 2-3 casual sentences. "
        "Keep the user's language, emotional tone, slang, and important details. "
        "Do not make it sound corporate, polished, motivational, or AI-written. "
        "Do not invent events.",
        payload.text,
        max_output_tokens=220,
    )
    return AiSummaryRead(summary=summary)


@router.post("/enhance", response_model=AiEnhanceRead)
def enhance(
    payload: AiTextRequest,
    _current_user: User = Depends(get_current_user),
) -> AiEnhanceRead:
    enhanced = _call_ai(
        "You are lightly cleaning a private diary entry, not writing a professional note. "
        "Keep the user's exact vibe: feelings, casual tone, slang, emojis, Hinglish or any mixed language, punctuation energy, and first-person voice. "
        "Preserve emojis exactly where possible; never replace them with question marks. "
        "Do not shorten away events or emotions. Keep all concrete details, movies, times, frustrations, jokes, and small side thoughts. "
        "Only fix readability, flow, and tiny grammar issues where useful. "
        "Do not make it sound polished, corporate, poetic, motivational, or AI-written. "
        "Do not add new events, advice, headings, bullets, or explanation. Return only the rewritten diary text.",
        payload.text,
        max_output_tokens=4096,
    )
    return AiEnhanceRead(enhanced_text=enhanced)


@router.post("/suggest-titles", response_model=AiTitleSuggestionsRead)
def suggest_titles(
    payload: AiTextRequest,
    _current_user: User = Depends(get_current_user),
) -> AiTitleSuggestionsRead:
    raw = _call_ai(
        "Suggest 5 short diary titles for this entry. "
        "Match the user's casual tone, language, slang, feelings, and emojis when natural. "
        "Make them feel like personal diary titles, not article headlines. "
        "Avoid clickbait, corporate wording, and fake positivity. Do not invent events. "
        'Return only JSON shaped like {"titles":["title one","title two"]}.',
        payload.text,
        max_output_tokens=1024,
    )
    raw = _extract_json_object(raw)
    try:
        decoded = json.loads(raw)
        titles = decoded.get("titles", [])
    except (json.JSONDecodeError, AttributeError):
        titles = [line.strip(" -0123456789.") for line in raw.splitlines()]
    cleaned = []
    for title in titles:
        value = str(title).strip().strip('"')
        if value and value not in cleaned:
            cleaned.append(value[:80])
    return AiTitleSuggestionsRead(titles=cleaned[:5])


def _extract_json_object(text: str) -> str:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    match = re.search(r"\{.*\}", cleaned, flags=re.DOTALL)
    return match.group(0) if match else cleaned
