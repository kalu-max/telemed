# Telemedicine Quick Start (Both Apps)

This guide is focused on production-style usage where users can install the apps and connect from anywhere.

## What You Get

- One public backend for both apps
- Patient app and doctor app using the same API and Socket.IO service
- Optional local mode for development

## Option A: Hosted Backend (Recommended)

Use this mode for real users across different networks/locations.

### 1. Ensure backend is deployed

Backend deployment config lives in:
- `render.yaml`
- `telemedicine_backend/server.js`

Health endpoint should respond:
```bash
curl https://telemed-backend.onrender.com/health
```

Expected JSON includes `status: "OK"`.

### 2. Run patient app

```bash
cd telemedicine_app
flutter pub get
flutter run
```

### 3. Run doctor app

```bash
cd telemedicine_app/doctor_app
flutter pub get
flutter run
```

Both apps default to:
- API: `https://telemed-backend.onrender.com`
- WebSocket: `wss://telemed-backend.onrender.com`

No localhost changes are required for production access.

## Option B: Local Development Backend (Optional)

Use this only when developing backend locally.

### 1. Start backend

```bash
cd telemedicine_backend
npm install
npm run dev
```

### 2. Run patient app with local override

```bash
cd telemedicine_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5000 --dart-define=WS_BASE_URL=ws://localhost:5000
```

### 3. Run doctor app with local override

```bash
cd telemedicine_app/doctor_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5000 --dart-define=WS_BASE_URL=ws://localhost:5000
```

## Release Build Commands

If you use a custom public domain, inject it at build time.

Patient app:
```bash
cd telemedicine_app
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-domain.com --dart-define=WS_BASE_URL=wss://your-api-domain.com
```

Doctor app:
```bash
cd telemedicine_app/doctor_app
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-domain.com --dart-define=WS_BASE_URL=wss://your-api-domain.com
```

## Deployment Automation (GitHub -> Render)

The CI workflow now contains a deploy stage for backend:
- File: `.github/workflows/ci.yml`
- Trigger: push to `main`

Required setup:
1. Connect Render service to this GitHub repository.
2. Keep `autoDeploy: true` in `render.yaml`.

After that, each push to `main` runs tests, Render deploys automatically, and CI verifies the public health endpoint.

## Common Problems

1. App still calling old/local server
- Doctor app may have an overridden URL saved in settings.
- Reset server URL in app settings to your public backend.

2. Browser CORS errors
- Set `ALLOWED_ORIGINS` correctly in backend environment.
- Use `*` only if you intentionally want open browser access.

3. Slow first response on free hosting
- Render free tier can cold start.
- Upgrade plan if you need always-on low-latency behavior.
