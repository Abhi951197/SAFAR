# Daily Diary Flutter App

This is the Android-first Flutter app for Daily Diary.

## Required defines

Run the app with:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-supabase-publishable-key `
  --dart-define=GOOGLE_WEB_CLIENT_ID=33551217855-eo6g9c37peqhimofdk6ulcoh6tqsfj89.apps.googleusercontent.com `
  --dart-define=API_BASE_URL=https://your-render-api.onrender.com
```

Google Sign-In uses the Google ID token, then creates the Supabase session with `signInWithIdToken`. The FastAPI backend syncs the user into PostgreSQL when `/auth/me` is called.

If Flutter was not available when this repo was scaffolded, run this once from `mobile` after installing Flutter to generate platform folders:

```powershell
flutter create --platforms android .
```
