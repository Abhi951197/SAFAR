# Supabase Server SDK

This folder contains an optional JavaScript server handler using `@supabase/server`.

The current MVP backend is still FastAPI in `backend/`. Use this folder if you later move selected endpoints to Supabase Edge Functions or another JavaScript runtime that supports standard `Request`/`Response`.

## Install

Already added at the repo root:

```powershell
npm install --prefix . @supabase/server
```

## Environment variables

Copy real values from Supabase Dashboard -> Connect:

```text
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=
SUPABASE_JWKS_URL=
```

Never commit the real `SUPABASE_SECRET_KEY`.

## Handler

`server/entries.handler.js` uses:

```js
withSupabase({ auth: 'user' }, async (_req, ctx) => {
  const { data } = await ctx.supabase.from('diary_entries').select('*')
  return Response.json(data)
})
```

`ctx.supabase` is scoped to the authenticated user and respects RLS. `ctx.supabaseAdmin` bypasses RLS and should only be used for trusted admin/server workflows.

For Supabase Edge Functions, keep platform JWT verification enabled for `auth: 'user'`. If you create a function using `auth: 'publishable'`, `auth: 'secret'`, or `auth: 'none'`, set `verify_jwt = false` for that function in `supabase/config.toml`.
