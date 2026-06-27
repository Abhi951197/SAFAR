# Daily Diary Setup

## 1. Supabase

Create a Supabase project and copy:

- Project URL -> `SUPABASE_URL`
- Publishable key -> backend `SUPABASE_PUBLISHABLE_KEY` and Flutter `SUPABASE_ANON_KEY`/publishable key
- Secret key -> backend `SUPABASE_SECRET_KEY`
- JWKS URL -> backend `SUPABASE_JWKS_URL`
- Database connection string -> backend `DATABASE_URL`
- JWT secret, if your project uses HS256 tokens -> backend `SUPABASE_JWT_SECRET`

Enable authentication providers:

- Email/password
- Google OAuth

## Google Auth

There are no `GOOGLE_CLIENT_ID` or `GOOGLE_CLIENT_SECRET` variables in `backend/.env`. The backend only verifies Supabase JWTs. The Flutter app uses the public Google web client id, receives a Google ID token, and exchanges it for a Supabase session.

In Supabase Dashboard:

```text
Authentication -> Providers -> Google
```

Enable Google. For native/mobile ID-token login, make sure your Google client id is accepted by the Supabase Google provider.

Add these redirect URLs in Supabase Auth URL configuration while developing:

```text
http://127.0.0.1:5174
http://127.0.0.1:5173
dailydiary://login-callback
```

For the Android OAuth client in Google Cloud, use:

```text
Package name: com.abhishekpal.dailydiary
```

Generate the SHA-1/SHA-256 fingerprints from the Android project when you are ready to test Google login on an emulator or physical device.

Current public Google web client id used by Flutter:

```text
33551217855-eo6g9c37peqhimofdk6ulcoh6tqsfj89.apps.googleusercontent.com
```

## 2. Cloudinary

Create a Cloudinary account and copy:

- Cloud name -> `CLOUDINARY_CLOUD_NAME`
- API key -> `CLOUDINARY_API_KEY`
- API secret -> `CLOUDINARY_API_SECRET`

The FastAPI backend uploads images to Cloudinary, so the API secret must never be placed in Flutter.

## 3. Backend

```powershell
cd backend
python -m venv .venv
.\\.venv\\Scripts\\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
alembic upgrade head
uvicorn app.main:app --reload
```

## 4. Render

Connect the GitHub repo to Render and use `render.yaml`.

Set these secret environment variables in Render:

- `DATABASE_URL`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SECRET_KEY`
- `SUPABASE_JWKS_URL`
- `SUPABASE_JWT_SECRET` when needed
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

## 5. Flutter

Flutter was not installed on this machine when the project was scaffolded. After installing Flutter, generate the Android platform folder:

Install steps for Windows:

1. Download Flutter SDK from `https://docs.flutter.dev/get-started/install/windows/mobile`.
2. Extract it somewhere stable, for example `C:\src\flutter`.
3. Add `C:\src\flutter\bin` to your user `Path`.
4. Install Android Studio from `https://developer.android.com/studio`.
5. In Android Studio, install Android SDK, Android SDK Platform Tools, Android SDK Build Tools, and an Android emulator.
6. Open a new PowerShell window and run `flutter doctor`.
7. Accept Android licenses with `flutter doctor --android-licenses`.

```powershell
cd mobile
flutter create --platforms android .
flutter pub get
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key `
  --dart-define=GOOGLE_WEB_CLIENT_ID=33551217855-eo6g9c37peqhimofdk6ulcoh6tqsfj89.apps.googleusercontent.com `
  --dart-define=API_BASE_URL=http://localhost:8000
```

For a device testing against local FastAPI, use your laptop LAN IP instead of `localhost`.

Dart ships with Flutter, so you normally do not install Dart separately for this mobile app. After Flutter is on `Path`, both `flutter --version` and `dart --version` should work.
