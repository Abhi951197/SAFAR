from pydantic import BaseModel, Field


class AiTextRequest(BaseModel):
    text: str = Field(min_length=1, max_length=12000)


class AiSummaryRead(BaseModel):
    summary: str


class AiEnhanceRead(BaseModel):
    enhanced_text: str


class AiTitleSuggestionsRead(BaseModel):
    titles: list[str]
