from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.diary_entry import DiaryEntry
from app.models.entry_reference import EntryReference


def replace_references(db: Session, entry: DiaryEntry, references, user_id):
    if len(references) > 20:
        raise HTTPException(422, "You can link up to 20 memories")
    old = {ref.id: ref for ref in entry.references}
    replacements = []
    seen = set()
    for ref in references:
        target_id = ref.target_entry_id
        if target_id is None:
            previous = old.get(ref.id)
            if previous is None or previous.target_entry_id is not None:
                raise HTTPException(422, "Reference is unavailable")
            title, day = previous.target_title, previous.target_date
        else:
            if target_id == entry.id or target_id in seen:
                raise HTTPException(422, "Choose different memories; an entry cannot link to itself")
            seen.add(target_id)
            target = db.scalar(select(DiaryEntry).where(DiaryEntry.id == target_id, DiaryEntry.user_id == user_id))
            if target is None:
                raise HTTPException(404, "Referenced memory is unavailable")
            title, day = target.title, target.entry_date
        replacements.append(EntryReference(target_entry_id=target_id, target_title=title,
            target_date=day, note=ref.note.strip() or None if ref.note else None))
    entry.references.clear()
    entry.references.extend(replacements)
