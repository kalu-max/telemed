# Public Backend Hosting Guide

Goal: make one backend reachable on the internet so any installed patient or doctor app can connect from anywhere.

## 1. Deploy Backend on Render

This repository already includes `render.yaml` configured for:
- Web service: `telemed-backend`
- Root directory: `telemedicine_backend`
- Health check: `/health`
- PostgreSQL database: `telemed-db`

Steps:
1. Push this repository to GitHub.
2. In Render, create a new Blueprint from your repo.
3. Render will create both backend service and PostgreSQL from `render.yaml`.

## 2. Configure Render Environment Variables

Set these in Render service environment:

Required:
- `NODE_ENV=production`
- `DB_DIALECT=postgres`
- `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` (auto-wired by `render.yaml`)
- `JWT_SECRET` (strong random string)
- `REFRESH_TOKEN_SECRET` (strong random string)

Recommended:
- `ALLOWED_ORIGINS=*` for broad browser-origin compatibility (or set explicit domains as comma-separated values)
- `FIREBASE_CONFIG` (single-line service account JSON)
- `FIREBASE_PROJECT_ID`
- `FIREBASE_DATABASE_URL`

## 3. Verify Public Backend

After deployment:

```bash
curl https://telemed-backend.onrender.com/health
```

Expected response contains:
- `status: "OK"`

## 4. Make GitHub Pushes Deploy Automatically

Workflow file: `.github/workflows/ci.yml`

Required:
1. Render service connected to your GitHub repository.
2. `autoDeploy: true` enabled in `render.yaml`.

Behavior:
- On push to `main`, CI runs backend + Flutter tests.
- Render deploys from Git push.
- Workflow polls `https://telemed-backend.onrender.com/health` until healthy.

Optional:
- If you prefer explicit deploy-hook triggering, you can add a separate workflow that uses a Render deploy hook secret.

## 5. Ensure Both Apps Use Hosted Backend

Current defaults already point to Render:
- Patient app config: `telemedicine_app/lib/config/app_config.dart`
- Doctor app config: `telemedicine_app/doctor_app/lib/config/app_config.dart`

Defaults:
- `API_BASE_URL=https://telemed-backend.onrender.com`
- `WS_BASE_URL=wss://telemed-backend.onrender.com`

## 6. Build Release Apps

Patient app:
```bash
cd telemedicine_app
flutter build apk --release
```

Doctor app:
```bash
cd telemedicine_app/doctor_app
flutter build apk --release
```

If you host backend on a different domain, pass runtime values:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-domain.com --dart-define=WS_BASE_URL=wss://your-api-domain.com
```

## 7. Production Notes

1. Free-tier cold starts can delay first request.
2. For lower latency and higher reliability, move Render service to a paid plan.
3. Keep `ALLOWED_ORIGINS` restricted to your domains if you host browser clients and want tighter security.
