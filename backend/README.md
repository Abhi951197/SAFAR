# Safar API

FastAPI backend for the Safar Flutter app.

## Local setup

```powershell
cd backend
python -m venv .venv
.\\.venv\\Scripts\\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Fill `.env` with Supabase Postgres, Supabase Auth, and Cloudinary values.

```powershell
alembic upgrade head
uvicorn app.main:app --reload
```

## Render start command

```bash
alembic upgrade head && gunicorn app.main:app -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
```
